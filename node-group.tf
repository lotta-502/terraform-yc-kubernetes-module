resource "yandex_kubernetes_node_group" "this" {
  for_each = var.kubernetes_node_groups

  name        = each.key
  description = "Kubernetes cluster ${var.cluster_name} node group ${each.key}"

  cluster_id = yandex_kubernetes_cluster.this.id
  version    = var.cluster_version

  scale_policy {
    auto_scale {
      min     = each.value.scale_policy.auto_scale.min
      max     = each.value.scale_policy.auto_scale.max
      initial = each.value.scale_policy.auto_scale.initial
    }
  }

  instance_template {
    platform_id = each.value.platform_id
    nat         = try(each.value.nat, null)
    metadata    = try(each.value.metadata, null)

    resources {
      cores         = each.value.resources.cores
      core_fraction = each.value.resources.core_fraction
      memory        = each.value.resources.memory
      gpus          = try(each.value.resources.gpus, null)
    }

    boot_disk {
      type = each.value.boot_disk.type
      size = each.value.boot_disk.size
    }

    scheduling_policy {
      preemptible = try(each.value.scheduling_policy.preemptible, null)
    }

    network_interface {
      subnet_ids         = each.value.network_interface.subnet_ids
      security_group_ids = try(each.value.network_interface.security_group_ids, null)
    }

    container_runtime {
      type = "containerd"
    }

    labels = var.labels
  }

  location {
    zone      = each.value.location.zone
    subnet_id = each.value.location.subnet_id
  }

  maintenance_policy {
    auto_upgrade = false
    auto_repair  = false
  }

  node_labels = try(each.value.node_labels, null)
  node_taints = try(each.value.node_taints, null)

  labels = var.labels
}