module "bootstrap" {
  source = "../../"

  cluster = google_container_cluster.this
  charts = {
    prometheus = {
      chart      = "prometheus"
      repository = "https://prometheus-community.github.io/helm-charts"
      namespace  = "monitoring"
      values = {
        server                   = { name = "server" }
        alertmanager             = { enabled = false }
        kube-state-metrics       = { enabled = false }
        prometheus-node-exporter = { enabled = false }
        prometheus-pushgateway   = { enabled = false }
      }
    }
  }
}
