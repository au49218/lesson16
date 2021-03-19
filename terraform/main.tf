terraform {
  backend "gcs" {
    bucket      = "terraform-state-lab-gke"
    prefix      = "terraform/state"
  }
}