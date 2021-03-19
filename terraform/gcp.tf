provider "google" {
  region  = var.region
  project = var.project
}

provider "google-beta" {
  region      = var.region
  project     = var.project
}

resource "random_id" "project_random" {
  prefix      = "${var.project_prefix}-${var.environment}-"
  byte_length = "8"
}

output "project_id" {
  value = random_id.project_random.hex
}

resource "google_project" "walt" {
  count           = var.project != "" ? 0 : 1
  name            = random_id.project_random.hex
  project_id      = random_id.project_random.hex
  billing_account = var.billing_account
}

data "google_project" "walt" {
  project_id = var.project != "" ? var.project : google_project.walt[0].project_id
}

resource "google_service_account" "walt-gke" {
  account_id   = "walt-gke-cluster"
  display_name = "WALT Labs GKE Cluster"
  project      = data.google_project.walt.project_id
}

resource "google_project_iam_member" "service-account" {
  count   = length(var.service_account_iam_roles)
  project = data.google_project.walt.project_id
  role    = element(var.service_account_iam_roles, count.index)
  member  = "serviceAccount:${google_service_account.walt-gke.email}"
}

resource "google_project_service" "service" {
  count   = length(var.project_services)
  project = data.google_project.walt.project_id
  service = element(var.project_services, count.index)
  disable_on_destroy = false
}

resource "google_compute_address" "walt-nat" {
  count   = 2
  name    = "walt-nat-external-${count.index}"
  project = data.google_project.walt.project_id
  region  = var.region

  depends_on = [google_project_service.service]
}

resource "google_compute_network" "walt-network" {
  name                    = "walt-network"
  project                 = data.google_project.walt.project_id
  auto_create_subnetworks = false

  depends_on = [google_project_service.service]
}

resource "google_compute_subnetwork" "walt-subnetwork" {
  name          = "walt-subnetwork"
  project       = data.google_project.walt.project_id
  network       = google_compute_network.walt-network.self_link
  region        = var.region
  ip_cidr_range = var.kubernetes_network_ipv4_cidr
  private_ip_google_access = true
  secondary_ip_range {
    range_name    = "walt-pods"
    ip_cidr_range = var.kubernetes_pods_ipv4_cidr
  }

  secondary_ip_range {
    range_name    = "walt-svcs"
    ip_cidr_range = var.kubernetes_services_ipv4_cidr
  }
}

resource "google_compute_router" "walt-router" {
  name    = "walt-router"
  project = data.google_project.walt.project_id
  region  = var.region
  network = google_compute_network.walt-network.self_link

  bgp {
    asn = 64514
  }
}

resource "google_compute_router_nat" "walt-nat" {
  name    = "walt-nat-1"
  project = data.google_project.walt.project_id
  router  = google_compute_router.walt-router.name
  region  = var.region

  nat_ip_allocate_option = "MANUAL_ONLY"
  nat_ips                = google_compute_address.walt-nat.*.self_link

  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.walt-subnetwork.self_link
    source_ip_ranges_to_nat = ["PRIMARY_IP_RANGE", "LIST_OF_SECONDARY_IP_RANGES"]
    secondary_ip_range_names = [
      google_compute_subnetwork.walt-subnetwork.secondary_ip_range[0].range_name,
      google_compute_subnetwork.walt-subnetwork.secondary_ip_range[1].range_name,
    ]
  }
}

data "google_container_engine_versions" "versions" {
  project  = data.google_project.walt.project_id
  location = var.region
}

resource "google_container_cluster" "walt" {
  provider = google-beta

  name     = "walt-cluster"
  project  = data.google_project.walt.project_id
  location = var.region

  network    = google_compute_network.walt-network.self_link
  subnetwork = google_compute_subnetwork.walt-subnetwork.self_link

  initial_node_count = var.kubernetes_nodes_per_zone

  min_master_version = data.google_container_engine_versions.versions.latest_master_version
  node_version       = data.google_container_engine_versions.versions.latest_master_version

  logging_service    = var.kubernetes_logging_service
  monitoring_service = var.kubernetes_monitoring_service

  node_config {
    machine_type    = var.kubernetes_instance_type
    service_account = google_service_account.walt-gke.email

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    metadata = {
      google-compute-enable-virtio-rng = "true"
      disable-legacy-endpoints         = "false"
    }

    labels = {
      service = "walt"
    }

    tags = ["walt"]

    workload_metadata_config {
      node_metadata = "SECURE"
    }
  }

  addons_config {
    network_policy_config {
      disabled = false
    }
  }

  master_auth {
    username = ""
    password = ""

    client_certificate_config {
      issue_client_certificate = false
    }
  }

  network_policy {
    enabled = true
  }

  maintenance_policy {
    daily_maintenance_window {
      start_time = var.kubernetes_daily_maintenance_window
    }
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = google_compute_subnetwork.walt-subnetwork.secondary_ip_range[0].range_name
    services_secondary_range_name = google_compute_subnetwork.walt-subnetwork.secondary_ip_range[1].range_name
  }

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.kubernetes_master_authorized_networks
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }

  private_cluster_config {
    enable_private_endpoint = false
    enable_private_nodes   = true # true for private cluster, PRIV GCR doesn't work in PRIV mode
    master_ipv4_cidr_block = var.kubernetes_masters_ipv4_cidr
  }

  depends_on = [
    google_project_service.service,
    google_project_iam_member.service-account,
    google_compute_router_nat.walt-nat,
  ]
}

resource "google_compute_address" "walt" {
  name    = "walt-lb"
  region  = var.region
  project = data.google_project.walt.project_id

  depends_on = [google_project_service.service]
}

data "google_container_registry_repository" "waltlab" {
  project  = data.google_project.walt.project_id
}

resource "google_container_registry" "waltlab" {
  project  = data.google_project.walt.project_id
  location = "US"
}
