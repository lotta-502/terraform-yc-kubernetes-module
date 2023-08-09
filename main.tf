resource "random_string" "unique_id" {
  length  = 8
  upper   = false
  lower   = true
  numeric = true
  special = false
}

resource "yandex_iam_service_account" "master" {
  folder_id = var.folder_id
  name      = "k8s-master-sa-${random_string.unique_id.result}"

  labels = var.labels
}

resource "yandex_iam_service_account" "node" {
  folder_id = var.folder_id
  name      = "k8s-node-sa-${random_string.unique_id.result}"

  labels = var.labels
}

resource "yandex_resourcemanager_folder_iam_member" "sa_calico_network_policy_role" {
  folder_id = var.folder_id
  role      = "k8s.clusters.agent"
  member    = "serviceAccount:${yandex_iam_service_account.master.id}"

  labels = var.labels
}

resource "yandex_resourcemanager_folder_iam_member" "sa_vpc_public_role_admin" {
  folder_id = var.folder_id
  role      = "vpc.publicAdmin"
  member    = "serviceAccount:${yandex_iam_service_account.master.id}"

  labels = var.labels
}

resource "yandex_resourcemanager_folder_iam_member" "sa_loadbalancer_role_admin" {
  folder_id = var.folder_id
  role      = "load-balancer.admin"
  member    = "serviceAccount:${yandex_iam_service_account.master.id}"

  labels = var.labels
}

resource "yandex_resourcemanager_folder_iam_member" "sa_logging_writer_role" {
  folder_id = var.folder_id
  role      = "logging.writer"
  member    = "serviceAccount:${yandex_iam_service_account.master.id}"

  labels = var.labels
}

resource "yandex_resourcemanager_folder_iam_member" "node" {
  folder_id = var.folder_id
  role      = "container-registry.images.puller"
  member    = "serviceAccount:${yandex_iam_service_account.node.id}"

  labels = var.labels
}

resource "time_sleep" "wait_for_iam" {
  create_duration = "5s"
  depends_on = [
    yandex_resourcemanager_folder_iam_member.node_account,
    yandex_resourcemanager_folder_iam_member.sa_calico_network_policy_role,
    yandex_resourcemanager_folder_iam_member.sa_vpc_public_role_admin,
    yandex_resourcemanager_folder_iam_member.sa_loadbalancer_role_admin,
    yandex_resourcemanager_folder_iam_member.sa_logging_writer_role,
  ]
}

resource "yandex_kms_symmetric_key" "this" {
  folder_id         = var.folder_id
  name              = "k8s-kms-key-${random_string.unique_id.result}"
  description       = "Kubernetes KMS symetric key"
  default_algorithm = "AES_256"
  rotation_period   = "8760h"

  labels = var.labels
}

resource "yandex_kms_symmetric_key_iam_binding" "encrypter_decrypter" {
  symmetric_key_id = yandex_kms_symmetric_key.this.id
  role             = "kms.keys.encrypterDecrypter"
  members = [
    "serviceAccount:${yandex_iam_service_account.master.id}",
  ]

  labels = var.labels
}

resource "yandex_vpc_security_group" "k8s_node" {
  folder_id   = var.folder_id
  name        = "k8s-node-${random_string.unique_id.result}"
  description = "Kubernetes security group for worker nodes"
  network_id  = var.network_id

  ingress {
    protocol          = "TCP"
    description       = "Rule allows availability checks from load balancer's address range. It is required for the operation of a fault-tolerant cluster and load balancer services."
    predefined_target = "loadbalancer_healthchecks"
    from_port         = 0
    to_port           = 65535
  }

  ingress {
    protocol          = "ANY"
    description       = "Rule allows master-node and node-node communication inside a security group."
    predefined_target = "self_security_group"
    from_port         = 0
    to_port           = 65535
  }

  ingress {
    protocol       = "ANY"
    description    = "Rule allows pod-pod and service-service communication inside a security group. Indicate your IP ranges."
    v4_cidr_blocks = [var.cluster_ipv4_range, var.service_ipv4_range]
    from_port      = 0
    to_port        = 65535
  }

  ingress {
    protocol       = "ICMP"
    description    = "Rule allows debugging ICMP packets from internal subnets."
    v4_cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }

  ingress {
    protocol       = "TCP"
    description    = "Rule allows incomming traffic from the Internet to the NodePort port range. Add ports or change existing ones to the required ports."
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 30000
    to_port        = 32767
  }

  egress {
    protocol       = "ANY"
    description    = "Rule allows all outgoing traffic. Nodes can connect to Yandex Container Registry, Yandex Object Storage, Docker Hub, and so on."
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }

  labels = var.labels
}

resource "yandex_vpc_security_group" "k8s_master" {
  folder_id   = var.folder_id
  name        = "k8s-master-${random_string.unique_id.result}"
  description = "Allow access to Kubernetes API from internet."
  network_id  = var.network_id

  ingress {
    protocol       = "TCP"
    description    = "Allow access to Kubernetes API via port 443 from subnet."
    v4_cidr_blocks = var.allowed_ips
    port           = 443
  }

  labels = var.labels
}

resource "yandex_kubernetes_cluster" "this" {
  depends_on = [
    time_sleep.wait_for_iam
  ]

  folder_id               = var.folder_id
  name                    = "${var.cluster_name}-${random_string.unique_id.result}"
  description             = var.description
  network_id              = var.network_id
  cluster_ipv4_range      = var.cluster_ipv4_range
  cluster_ipv6_range      = var.cluster_ipv6_range
  service_ipv4_range      = var.service_ipv4_range
  service_ipv6_range      = var.service_ipv6_range
  service_account_id      = yandex_iam_service_account.master.id
  node_service_account_id = yandex_iam_service_account.node.id
  network_policy_provider = var.network_policy_provider
  release_channel         = var.release_channel

  kms_provider {
    key_id = yandex_kms_symmetric_key.this.id
  }

  master {
    version            = var.cluster_version
    public_ip          = var.public_access
    security_group_ids = [
      yandex_vpc_security_group.k8s_master.id,
      yandex_vpc_security_group.k8s_node.id,
    ]

    zonal {
      zone      = var.master_zone
      subnet_id = var.master_subnet_id
    }

    maintenance_policy {
      auto_upgrade = var.master_auto_upgrade

      dynamic "maintenance_window" {
        for_each = var.master_maintenance_windows
        content {
          day        = maintenance_window.value.day
          start_time = maintenance_window.value.start_time
          duration   = maintenance_window.value.duration
        }
      }
    }

    master_logging {
      enabled                    = var.master_logging.enabled
      folder_id                  = var.folder_id
      kube_apiserver_enabled     = var.master_logging.enabled_kube_apiserver
      cluster_autoscaler_enabled = var.master_logging.enabled_autoscaler
      events_enabled             = var.master_logging.enabled_events
    }
  }

  labels = var.labels
}
