resource "yandex_kubernetes_node_group" "this" {
  for_each = var.node_groups

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
    platform_id = each.value.instance_template.platform_id
    nat         = try(each.value.instance_template.nat, null)
    metadata    = try(each.value.instance_template.metadata, null)

    resources {
      cores         = each.value.instance_template.resources.cores
      core_fraction = each.value.instance_template.resources.core_fraction
      memory        = each.value.instance_template.resources.memory
      gpus          = try(each.value.instance_templateresources.gpus, null)
    }

    boot_disk {
      type = each.value.instance_template.boot_disk.type
      size = each.value.instance_template.boot_disk.size
    }

    scheduling_policy {
      preemptible = try(each.value.instance_template.scheduling_policy.preemptible, null)
    }

    network_interface {
      subnet_ids         = each.value.instance_template.network_interface.subnet_ids
      security_group_ids = concat(
        try(each.value.instance_template.network_interface.security_group_ids, []),
        [yandex_vpc_security_group.k8s_node.id]
      )
    }

    container_runtime {
      type = "containerd"
    }

    labels = var.labels
  }

  allocation_policy {
    location {
      zone      = each.value.allocation_policy.location.zone
    }
  }

  maintenance_policy {
    auto_upgrade = false
    auto_repair  = false
  }

  node_labels = try(each.value.node_labels, null)
  node_taints = try(each.value.node_taints, null)

  labels = var.labels
}