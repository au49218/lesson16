variable "region" {
  type        = string
  default     = "us-central1"
}
variable "billing_account" {
  type        = string
}

variable "environment" {
  type        = string
  default     = "stg"
}

variable "project" {
  type        = string
  default     = ""
}

variable "project_prefix" {
  type        = string
  default     = "walt"
}

variable "kubernetes_instance_type" {
  type        = string
  default     = "n1-standard-2"
}

variable "service_account_iam_roles" {
  type = list(string)
  default = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/containerregistry.ServiceAgent"
  ]
}

variable "project_services" {
  type = list(string)
  default = [
    "cloudresourcemanager.googleapis.com",
    "container.googleapis.com",
    "containerregistry.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
  ]
}

variable "kubernetes_nodes_per_zone" {
  type        = number
  default     = 1
}

variable "kubernetes_daily_maintenance_window" {
  type        = string
  default     = "06:00"
}

variable "kubernetes_logging_service" {
  type        = string
  default     = "logging.googleapis.com/kubernetes"
}

variable "kubernetes_monitoring_service" {
  type        = string
  default     = "monitoring.googleapis.com/kubernetes"
}

variable "kubernetes_network_ipv4_cidr" {
  type        = string
  default     = "10.0.24.0/22"
}

variable "kubernetes_pods_ipv4_cidr" {
  type        = string
  default     = "10.0.20.0/22"
}

variable "kubernetes_secrets_crypto_key" {
  type        = string
  default     = "kubernetes-secrets"
}

variable "kubernetes_services_ipv4_cidr" {
  type        = string
  default     = "10.0.60.0/22"
}

variable "kubernetes_masters_ipv4_cidr" {
  type        = string
  default     = "10.0.32.0/28"
}

variable "kubernetes_master_authorized_networks" {
  type = list(object({
    display_name = string
    cidr_block   = string
  }))

  default = [
    {
      display_name = "Anyone"
      cidr_block   = "0.0.0.0/0"
    },
  ]
}