# Basic Bootstrap Example
This example demonstrates how to use the `terraform-google-kubernetes-bootstrap` module to install Helm charts into a GKE cluster.

### Login
Login to your Google Cloud account using the cloud CLI before running the Terraform commands.
```bash
gcloud auth login
```

### Apply
Run the following commands to initialize the Terraform, create an execution plan, and apply the infrastructure.
```bash
terraform init
terraform plan
terraform apply
```

After the GKE cluster is created, the module invokes the Cloud Function to connect to the Kubernetes API and install Helm charts.

## Verification
```bash
gcloud container clusters get-credentials example-cluster --location us-east1-b
kubectl get pods --namespace monitoring
```

You should see the `grafana` pod running in the cluster.

## Cleanup
```bash
terraform destroy
```

Make sure to cleanup the Cloud Function and any other resources created by the module to avoid incurring unnecessary costs.
