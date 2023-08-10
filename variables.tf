variable "folder_id" {
  type = string
}

variable "network_id" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "cluster_description" {
  type    = string
  default = ""
}

variable "allowed_ips" {
  type = list(string)
  default = []
}

variable "cluster_version" {
  type = string
}

variable "public_access" {
  type    = bool
  default = false
}

variable "master_zone" {
  type = string
}

variable "master_subnet_id" {
  type = string
}

variable "master_auto_upgrade" {
  type    = bool
  default = false
}

variable "master_maintenance_windows" {
  type    = any
  default = []
}

variable "master_logging" {
  type = map(string)
  default = {
    enabled                = true
    enabled_kube_apiserver = true
    enabled_autoscaler     = true
    enabled_events         = true
  }
}

variable "cluster_ipv4_range" {
  type    = string
  default = "172.16.0.0/16"
}

variable "cluster_ipv6_range" {
  type    = string
  default = null
}

variable "service_ipv4_range" {
  type    = string
  default = "192.168.0.0/16"
}

variable "service_ipv6_range" {
  type    = string
  default = null
}

variable "network_policy_provider" {
  type    = string
  default = "CALICO"
}

variable "release_channel" {
  type    = string
  default = "STABLE"
}

variable "labels" {
  type    = map(string)
  default = {}
}
