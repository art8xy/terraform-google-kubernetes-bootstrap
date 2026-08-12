# GCP Kubernetes Bootstrap
The `terraform-google-kubernetes-bootstrap` module simplifies private bootstrapping of GKE clusters.  
The module uses a serverless Cloud Function to configure the Kubernetes cluster and install Helm charts.  
The Cloud Function is deployed inside the GKE VPC, allowing it to access the Kubernetes API without exposing it publicly. 

### Features
* Deploys a Cloud Function inside the GKE VPC
* Supports private access to the Kubernetes API
* Authenticates to GKE using Google Cloud IAM
* Installs and manages Helm charts
* Keeps Kubernetes bootstrap operations within GCP

### How it works
Terraform creates the Cloud Function, required IAM and VPC access configuration.  
After deployment, Terraform invokes the function with the configured Helm charts.

![Architecture](https://raw.githubusercontent.com/art8xy/terraform-google-kubernetes-bootstrap/main/assets/images/architecture.png)

The Cloud Function:
1. Retrieves the GKE cluster configuration.
2. Generates a GKE authentication token.
3. Configures a temporary kubeconfig.
4. Connects to the Kubernetes API.
5. Installs the configured Helm charts.

This makes it possible to provision and bootstrap private GKE clusters entirely through Terraform, without exposing the Kubernetes API publicly or requiring the Terraform execution environment to have network access to the cluster.

### Prerequisites
The following tools must be installed in the environment running Terraform.  
They are used to build and package the Cloud Function deployment artifact:
- `zip`
- `tar`
- `curl`
- `pip3`
- `python3`

### Example
Below is a basic example of how to use the module to install the `prometheus` Helm chart.
```hcl
module "bootstrap" {
  source = "art8xy/kubernetes-bootstrap/google"
  version = "1.0.0"

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
```
