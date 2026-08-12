import os
import logging
import tempfile
import kube
import helm

from pathlib import Path

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(request):
    logger.info(f"Received request: {request}")

    try:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)

            cluster = os.environ["CLUSTER"]
            kube.config(tmp, cluster)

            data = request.get_json(silent=True) or {}
            charts = data["charts"]
            for name, chart in charts.items():
                logger.info(f"Installing {name} chart")
                helm.install(tmp, helm.Chart(
                    release=name,
                    chart=chart["chart"],
                    repository=chart["repository"],
                    version=chart["version"],
                    namespace=chart["namespace"],
                    values=chart.get("values", {}),
                    wait=chart["wait"],
                    timeout=chart["timeout"],
                    create_namespace=chart["create_namespace"],
                ))
                logger.info(f"Chart {name} installed successfully")

    except Exception as e:
        logger.error(f"Provisioning failed: {e}")
        raise

    return {"status": "Provisioning successful"}
