resource "google_project_service" "compute" {
  service = "compute.googleapis.com"
}

resource "google_compute_network" "this" {
  name = "example-network"

  auto_create_subnetworks = false
  depends_on              = [google_project_service.compute]
}

resource "google_compute_subnetwork" "this" {
  name          = "example-subnet"
  ip_cidr_range = "10.0.0.0/16"
  network       = google_compute_network.this.id

  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.1.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.2.0.0/16"
  }
}

resource "google_compute_router" "this" {
  name    = "example-router"
  network = google_compute_network.this.id
}

resource "google_compute_router_nat" "this" {
  name   = "example-nat"
  router = google_compute_router.this.name

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
