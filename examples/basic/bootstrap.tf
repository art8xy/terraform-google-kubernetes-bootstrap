module "bootstrap" {
  source = "../../"

  cluster = google_container_cluster.this
  charts = {
    grafana = {
      chart      = "grafana"
      repository = "https://grafana.github.io/helm-charts"
      namespace  = "monitoring"
      values = {
        resources = {
          limits   = { cpu = "100m", memory = "128Mi" }
          requests = { cpu = "100m", memory = "128Mi" }
        }
      }
    }
  }
}
