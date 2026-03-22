#!/usr/bin/env python3
"""Generate Azure architecture diagrams from ARM JSON files using the diagrams library."""

import json
import os
import sys

from diagrams import Cluster, Diagram
from diagrams.azure.compute import ContainerRegistries, FunctionApps
from diagrams.azure.devops import ApplicationInsights
from diagrams.azure.identity import ManagedIdentities
from diagrams.azure.integration import APIManagement
from diagrams.azure.network import DNSZones, VirtualNetworks
from diagrams.azure.security import KeyVaults
from diagrams.azure.storage import StorageAccounts
from diagrams.azure.web import AppServicePlans, AppServices

# Graceful fallback for PrivateEndpoint (may not exist in all diagrams versions)
try:
    from diagrams.azure.network import PrivateEndpoint
except ImportError:
    from diagrams.azure.network import Firewall as PrivateEndpoint

# Map ARM resource types to (display_label, diagrams_node_class)
RESOURCE_MAP = {
    "Microsoft.ApiManagement/service": ("APIM Service", APIManagement),
    "Microsoft.Web/serverfarms": ("App Service Plan", AppServicePlans),
    "Microsoft.Web/sites": ("App Service", AppServices),
    "Microsoft.Insights/components": ("App Insights", ApplicationInsights),
    "Microsoft.OperationalInsights/workspaces": ("Log Analytics", ApplicationInsights),
    "Microsoft.ContainerRegistry/registries": ("Container Registry", ContainerRegistries),
    "Microsoft.KeyVault/vaults": ("Key Vault", KeyVaults),
    "Microsoft.Storage/storageAccounts": ("Storage Account", StorageAccounts),
    "Microsoft.Network/virtualNetworks": ("Virtual Network", VirtualNetworks),
    "Microsoft.Network/privateDnsZones": ("Private DNS", DNSZones),
    "Microsoft.ManagedIdentity/userAssignedIdentities": ("Managed Identity", ManagedIdentities),
    "Microsoft.Network/privateEndpoints": ("Private Endpoint", PrivateEndpoint),
}

# Skip child/sub-resources and RBAC assignments for cleaner diagrams
SKIP_TYPES = {
    "Microsoft.Authorization/roleAssignments",
    "Microsoft.Web/sites/basicPublishingCredentialsPolicies",
    "Microsoft.KeyVault/vaults/secrets",
    "Microsoft.ApiManagement/service/namedValues",
    "Microsoft.ApiManagement/service/loggers",
    "Microsoft.ApiManagement/service/authorizationServers",
    "Microsoft.Storage/storageAccounts/blobServices",
    "Microsoft.Storage/storageAccounts/blobServices/containers",
    "Microsoft.Storage/storageAccounts/tableServices",
    "Microsoft.Storage/storageAccounts/tableServices/tables",
    "Microsoft.Network/privateDnsZones/virtualNetworkLinks",
    "Microsoft.Network/privateEndpoints/privateDnsZoneGroups",
}

# Diagram configurations: (ARM JSON path, app name)
DIAGRAMS = [
    ("/tmp/appservice.json", "weather-api"),
    ("/tmp/appservice.json", "star-wars-api"),
    ("/tmp/appservice.json", "soap-api"),
    ("/tmp/appservice.json", "odata-api"),
    ("/tmp/appservice.json", "movie-api"),
    ("/tmp/appservice.json", "web-app"),
    ("/tmp/fnapp.json", "appointments-api"),
    ("/tmp/apim.json", "apim-basicv2"),
    ("/tmp/fastapi.json", "fast-api"),
    ("/tmp/flask.json", "flask-app"),
]


def parse_arm_json(filepath):
    """Extract top-level resources from ARM JSON with Function App detection."""
    with open(filepath, "r") as f:
        arm = json.load(f)
    resources = []
    for r in arm.get("resources", []):
        rtype = r.get("type", "")
        kind = r.get("kind", "")
        if rtype in SKIP_TYPES:
            continue
        # Detect Function Apps via the kind field
        if rtype == "Microsoft.Web/sites" and "functionapp" in kind.lower():
            resources.append(
                {"type": rtype, "label": "Function App", "node_cls": FunctionApps}
            )
        elif rtype in RESOURCE_MAP:
            label, node_cls = RESOURCE_MAP[rtype]
            resources.append({"type": rtype, "label": label, "node_cls": node_cls})
    # Deduplicate by resource type (e.g., multiple Private DNS zones → single node)
    seen = set()
    unique = []
    for r in resources:
        if r["type"] not in seen:
            seen.add(r["type"])
            unique.append(r)
    return unique


def generate_diagram(arm_file, app_name, output_dir="diagrams"):
    """Generate a single architecture diagram from ARM JSON."""
    os.makedirs(output_dir, exist_ok=True)
    resources = parse_arm_json(arm_file)
    if not resources:
        print(f"No mappable resources found in {arm_file}")
        return None

    outpath = os.path.join(output_dir, f"architecture-{app_name}")
    with Diagram(
        f"{app_name} Architecture",
        filename=outpath,
        show=False,
        direction="LR",
        outformat="png",
    ):
        with Cluster(f"Resource Group: {app_name}"):
            nodes = []
            for r in resources:
                nodes.append(r["node_cls"](r["label"]))
            for i in range(len(nodes) - 1):
                nodes[i] >> nodes[i + 1]

    return f"{outpath}.png"


if __name__ == "__main__":
    output_dir = sys.argv[1] if len(sys.argv) > 1 else "diagrams"
    for arm_file, app_name in DIAGRAMS:
        if not os.path.exists(arm_file):
            print(f"Skipping {app_name}: ARM JSON not found at {arm_file}")
            continue
        result = generate_diagram(arm_file, app_name, output_dir)
        if result:
            print(f"Generated: {result}")
