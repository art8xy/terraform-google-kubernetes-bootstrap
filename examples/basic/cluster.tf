data "google_client_config" "current" {}

data "http" "myip" {
  url = "https://checkip.amazonaws.com"
}

resource "google_project_service" "container" {
  service = "container.googleapis.com"
}

resource "google_container_cluster" "this" {
  name = "example-cluster"

  network    = google_compute_network.this.id
  subnetwork = google_compute_subnetwork.this.id
  location   = "${data.google_client_config.current.region}-b"

  deletion_protection = false

  remove_default_node_pool = true
  initial_node_count       = 1

  ip_allocation_policy {
    cluster_secondary_range_name  = google_compute_subnetwork.this.secondary_ip_range[0].range_name
    services_secondary_range_name = google_compute_subnetwork.this.secondary_ip_range[1].range_name
  }

  control_plane_endpoints_config {
    dns_endpoint_config {
      allow_external_traffic = true
    }
  }

  private_cluster_config {
    enable_private_nodes        = true
    private_endpoint_subnetwork = google_compute_subnetwork.this.id
  }

  master_authorized_networks_config {
    cidr_blocks {
      display_name = "My IP"
      cidr_block   = "${trimspace(data.http.myip.response_body)}/32"
    }
  }

  depends_on = [google_project_service.container]
}

resource "google_container_node_pool" "this" {
  name     = "example-node-pool"
  cluster  = google_container_cluster.this.name
  location = google_container_cluster.this.location

  node_count = 1
  node_config {
    machine_type = "e2-medium"
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}
