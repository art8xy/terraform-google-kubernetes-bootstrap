# Basic Bootstrap Example
This example demonstrates how to use the `terraform-google-kubernetes-bootstrap` module to install Helm charts into a GKE cluster.

## Usage
```bash
terraform init
terraform plan
terraform apply
```

After the GKE cluster is created, the module invokes the Cloud Function to connect to the Kubernetes API and install the configured Helm charts.

## Verification
```bash
gcloud container clusters get-credentials example-cluster --location us-east1-b
kubectl get pods --namespace monitoring
```

You should see the `prometheus-server` pod running in the cluster.

## Cleanup
```bash
terraform destroy
```

Make sure to cleanup the Cloud Function and any other resources created by the module to avoid incurring unnecessary costs.
