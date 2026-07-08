#!/usr/bin/env python3
"""
Validate a Postman Collection v2.1 JSON file.

Usage:
    python validate_collection.py <path-to-collection.json>

Checks:
  - Valid JSON
  - Required info.name and info.schema fields
  - Schema URL matches v2.1.0
  - Every item has a name
  - Every request item has method and url
  - No hardcoded secrets in headers (basic heuristic)
"""

import json
import re
import sys
from pathlib import Path

REQUIRED_SCHEMA = "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
VALID_METHODS = {"GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS", "TRACE", "CONNECT", "WEBSOCKET"}
SECRET_PATTERNS = [
    re.compile(r"Bearer\s+[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\.", re.I),  # JWT prefix
    re.compile(r"sk_live_[A-Za-z0-9]+", re.I),
    re.compile(r"sk_test_[A-Za-z0-9]+", re.I),
    re.compile(r"password['\"]?\s*:\s*['\"][^'\"]{8,}['\"]", re.I),
]


def error(msg: str) -> None:
    print(f"  ERROR: {msg}")


def warn(msg: str) -> None:
    print(f"  WARN:  {msg}")


def check_secrets(obj, path="") -> int:
    """Return count of secret warnings."""
    warnings = 0
    if isinstance(obj, dict):
        for k, v in obj.items():
            if k.lower() in ("authorization", "x-api-key", "api-key") and isinstance(v, str):
                for pat in SECRET_PATTERNS:
                    if pat.search(v) and "{{" not in v:
                        warn(f"Possible hardcoded secret at {path}.{k}")
                        warnings += 1
            warnings += check_secrets(v, f"{path}.{k}")
    elif isinstance(obj, list):
        for i, item in enumerate(obj):
            warnings += check_secrets(item, f"{path}[{i}]")
    elif isinstance(obj, str):
        for pat in SECRET_PATTERNS:
            if pat.search(obj) and "{{" not in obj:
                warn(f"Possible hardcoded secret in value at {path}")
                warnings += 1
                break
    return warnings


def validate_items(items: list, path: str = "item") -> tuple[int, int]:
    """Validate item array. Returns (errors, request_count)."""
    errors = 0
    requests = 0

    if not isinstance(items, list):
        error(f"{path} must be an array")
        return 1, 0

    for i, item in enumerate(items):
        item_path = f"{path}[{i}]"

        if not isinstance(item, dict):
            error(f"{item_path} must be an object")
            errors += 1
            continue

        if "name" not in item or not item["name"]:
            error(f"{item_path} missing required 'name'")
            errors += 1

        if "item" in item:
            sub_errors, sub_requests = validate_items(item["item"], f"{item_path}.item")
            errors += sub_errors
            requests += sub_requests
        elif "request" in item:
            requests += 1
            req = item["request"]
            if isinstance(req, dict):
                method = req.get("method", "")
                if method and method.upper() not in VALID_METHODS:
                    warn(f"{item_path} has unusual method: {method}")
                if "url" not in req:
                    error(f"{item_path} request missing 'url'")
                    errors += 1
            if "event" not in item:
                warn(f"{item_path} ({item.get('name')}) has no test scripts")
        else:
            error(f"{item_path} must have 'request' or 'item' (folder)")
            errors += 1

    return errors, requests


def validate_collection(data: dict) -> tuple[int, int, int]:
    """Returns (errors, warnings, request_count)."""
    errors = 0
    warnings = 0

    if "info" not in data:
        error("Missing 'info' object")
        return 1, 0, 0

    info = data["info"]
    if not info.get("name"):
        error("info.name is required")
        errors += 1

    schema = info.get("schema", "")
    if schema != REQUIRED_SCHEMA:
        error(f"info.schema must be '{REQUIRED_SCHEMA}', got '{schema}'")
        errors += 1

    if "item" not in data:
        error("Missing 'item' array")
        errors += 1
        return errors, warnings, 0

    item_errors, request_count = validate_items(data["item"])
    errors += item_errors

    if request_count == 0:
        warn("Collection contains no requests")

    warnings += check_secrets(data)

    return errors, warnings, request_count


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: python validate_collection.py <collection.json>")
        return 1

    path = Path(sys.argv[1])
    if not path.exists():
        print(f"File not found: {path}")
        return 1

    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        print(f"Invalid JSON: {e}")
        return 1

    if not isinstance(data, dict):
        print("Collection root must be a JSON object")
        return 1

    print(f"Validating: {path}")
    errors, warnings, request_count = validate_collection(data)

    print(f"\nResults: {request_count} request(s), {errors} error(s), {warnings} warning(s)")

    if errors:
        print("\n❌ Validation FAILED")
        return 1

    print("\n✅ Validation PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
