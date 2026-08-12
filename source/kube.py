import os
import yaml
import logging
from pathlib import Path

import google.auth
from google.auth.transport.requests import Request
from google.cloud import container_v1

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def config(tmp: Path, cluster: str) -> None:
    workdir = tmp / ".kube"
    workdir.mkdir(parents=True, exist_ok=True)
    kubeconfig_path = workdir / "config"

    credentials, project = google.auth.default()
    credentials.refresh(Request())

    client = container_v1.ClusterManagerClient()
    parent = f"projects/{project}/locations/-"
    clusters = client.list_clusters(parent=parent)
    matches = [c for c in clusters.clusters if c.name == cluster]

    if not matches:
        raise RuntimeError(f"Cluster '{cluster}' not found in project '{project}'")

    if len(matches) > 1:
        raise RuntimeError(f"Multiple clusters named '{cluster}' found in project '{project}'")

    location = matches[0].location
    cluster_path = f"projects/{project}/locations/{location}/clusters/{cluster}"
    cluster_info = client.get_cluster(name=cluster_path)

    endpoint = cluster_info.control_plane_endpoints_config.dns_endpoint_config.endpoint

    if not endpoint:
        raise RuntimeError(f"Cluster '{cluster}' does not have a private endpoint")

    kubeconfig_content = {
        "apiVersion": "v1",
        "kind": "Config",
        "clusters": [{
            "name": cluster,
            "cluster": {
                "server": f"https://{endpoint}",
            }
        }],
        "contexts": [{
            "name": cluster,
            "context": {
                "cluster": cluster,
                "user": cluster,
            }
        }],
        "current-context": cluster,
        "users": [{
            "name": cluster,
            "user": {
                "token": credentials.token,
            }
        }],
    }

    kubeconfig_path.write_text(yaml.safe_dump(kubeconfig_content, sort_keys=False), encoding="utf-8")
    os.environ["KUBECONFIG"] = str(kubeconfig_path)
    logger.info(f"KUBECONFIG: {kubeconfig_path}")
