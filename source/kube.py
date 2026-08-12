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

    credentials, _ = google.auth.default()
    credentials.refresh(Request())

    client = container_v1.ClusterManagerClient()
    cluster_info = client.get_cluster(name=cluster)

    endpoint = cluster_info.control_plane_endpoints_config.dns_endpoint_config.endpoint
    if not endpoint:
        raise RuntimeError(f"Cluster '{cluster}' has no DNS endpoint")

    kubeconfig_content = {
        "apiVersion": "v1",
        "kind": "Config",
        "clusters": [{
            "name": cluster_info.name,
            "cluster": {
                "server": f"https://{endpoint}",
            },
        }],
        "contexts": [{
            "name": cluster_info.name,
            "context": {
                "cluster": cluster_info.name,
                "user": cluster_info.name,
            },
        }],
        "current-context": cluster_info.name,
        "users": [{
            "name": cluster_info.name,
            "user": {
                "token": credentials.token,
            },
        }],
    }

    kubeconfig_path.write_text(yaml.safe_dump(kubeconfig_content, sort_keys=False), encoding="utf-8")
    os.environ["KUBECONFIG"] = str(kubeconfig_path)
    logger.info(f"KUBECONFIG: {kubeconfig_path}")
