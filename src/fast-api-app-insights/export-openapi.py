#!/usr/bin/env python
"""Export OpenAPI specification to a JSON file.

This script generates the OpenAPI 3.0 specification from the FastAPI application
and saves it to a file for documentation, code generation, or API gateway configuration.

Usage:
    python export-openapi.py
    python export-openapi.py --output custom-spec.json
"""

import json
import argparse
from pathlib import Path


def export_openapi_spec(output_file: str = "openapi.json"):
    """Export the OpenAPI specification to a JSON file."""
    # Import here to avoid requiring the app to be running
    from main import app
    
    # Get the OpenAPI schema
    openapi_schema = app.openapi()
    
    # Write to file
    output_path = Path(output_file)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(openapi_schema, f, indent=2, ensure_ascii=False)
    
    print(f"✓ OpenAPI specification exported to: {output_path.absolute()}")
    print(f"  Version: {openapi_schema.get('info', {}).get('version', 'N/A')}")
    print(f"  Title: {openapi_schema.get('info', {}).get('title', 'N/A')}")
    print(f"  Endpoints: {len(openapi_schema.get('paths', {}))}")


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Export OpenAPI specification from FastAPI application"
    )
    parser.add_argument(
        "--output",
        "-o",
        default="openapi.json",
        help="Output file path (default: openapi.json)"
    )
    
    args = parser.parse_args()
    export_openapi_spec(args.output)


if __name__ == "__main__":
    main()
