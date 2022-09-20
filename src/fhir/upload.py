import json
import os
import requests
from flask import abort, current_app

from carl.modules.factories import deserialize_resource


def load_files():
    """Feed FHIR_SERVER_URL all `.json` files found in `serialized` directory"""
    fhir_url = current_app.config["FHIR_SERVER_URL"]
    if not fhir_url:
        current_app.logger.warn(
            "No config set for FHIR_SERVER_URL, can't load serialized data"
        )
        return

    base_dir = os.path.join(current_app.root_path, "serialized")
    for fname in (
        fname for fname in os.scandir(base_dir) if fname.name.lower().endswith(".json")
    ):
        with open(fname.path) as fhir:
            try:
                data = json.loads(fhir.read())
            except json.decoder.JSONDecodeError as je:
                current_app.logger.error(f"{fname.path} contains invalid JSON")
                current_app.logger.exception(je)
                abort(400, f"Error in bootstrap, can't process {fname.path}")

            endpoint = fhir_url
            if data["resourceType"] != "Bundle":
                # For non bundles, PUT with search parameters to avoid
                # duplicate resource creation
                resource = deserialize_resource(data)
                endpoint += resource.search_url()

            current_app.logger.info(f"PUT {fname.name} to {endpoint}")
            response = requests.put(endpoint, json=data, timeout=30)
            current_app.logger.info(
                f"status {response.status_code}, text {response.text}"
            )
            response.raise_for_status()
