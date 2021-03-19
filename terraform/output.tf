output "address" {
  value = google_compute_address.walt.address
}

output "project" {
  value = data.google_project.walt.project_id
}

output "region" {
  value = var.region
}
output "gcr" {
  value = data.google_container_registry_repository.waltlab.repository_url
}

output "cluster" {
  value = google_container_cluster.walt.name
}
