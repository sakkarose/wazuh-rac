import json
import re
import sys
import xml.etree.ElementTree as ET
from collections import Counter
from pathlib import Path

import yaml


DECODER_ROOT = Path("integrations")
DECODER_NAME = re.compile(r"^decoder/[^/]+/[^/]+$")
REQUIRED_METADATA = {"title", "author", "description"}
SAMPLE_FILES = [
    Path("integrations/ipfire-netfilter/samples/netfilter.samples.txt"),
    Path("integrations/ipfire-suricata/samples/suricata-reporter.samples.txt"),
]
DASHBOARD = Path("integrations/ipfire/dashboard/ipfire-dashboard.ndjson")
POLICY = Path("single-node/indexer-policies/wazuh-events-14d.json")
AGENT_CONFIG_ROOT = Path("single-node/tracked-config/wazuh-manager/shared")


def validate_decoder(path: Path) -> list[str]:
    errors = []
    try:
        document = yaml.safe_load(path.read_text(encoding="utf-8"))
    except Exception as exc:
        return [f"{path}: invalid YAML: {exc}"]

    if not isinstance(document, dict):
        return [f"{path}: decoder must be a YAML object"]

    name = document.get("name")
    if not isinstance(name, str) or not DECODER_NAME.fullmatch(name):
        errors.append(f"{path}: invalid decoder name {name!r}")
    if not isinstance(document.get("enabled"), bool):
        errors.append(f"{path}: enabled must be a boolean")

    metadata = document.get("metadata")
    if not isinstance(metadata, dict):
        errors.append(f"{path}: metadata must be an object")
    else:
        missing = sorted(REQUIRED_METADATA - metadata.keys())
        if missing:
            errors.append(f"{path}: metadata is missing {', '.join(missing)}")

    normalize = document.get("normalize")
    if not isinstance(normalize, list) or not normalize:
        errors.append(f"{path}: normalize must be a non-empty list")

    # The Dashboard/Content Manager assigns the resource id. Repository YAML is
    # intentionally id-free so operators do not reuse one id across spaces.
    if "id" in document:
        errors.append(f"{path}: omit id; Content Manager assigns it on creation")

    return errors


def validate_dashboard() -> list[str]:
    errors = []
    counts = Counter()
    if not DASHBOARD.is_file():
        return [f"{DASHBOARD}: missing dashboard bundle"]

    for lineno, line in enumerate(DASHBOARD.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        try:
            item = json.loads(line)
        except json.JSONDecodeError as exc:
            errors.append(f"{DASHBOARD}:{lineno}: invalid JSON: {exc}")
            continue
        if not isinstance(item, dict):
            errors.append(f"{DASHBOARD}:{lineno}: object must be a JSON object")
            continue
        object_type = item.get("type")
        if object_type:
            counts[object_type] += 1

    expected = {"index-pattern": 1, "visualization": 16, "dashboard": 1}
    for object_type, count in expected.items():
        if counts[object_type] != count:
            errors.append(
                f"{DASHBOARD}: expected {count} {object_type} object(s), found {counts[object_type]}"
            )
    return errors


def validate_json_policy() -> list[str]:
    try:
        document = json.loads(POLICY.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"{POLICY}: invalid JSON: {exc}"]

    patterns = (
        document.get("policy", {})
        .get("ism_template", {})
        .get("index_patterns", [])
    )
    if patterns != ["wazuh-events-v5-*"]:
        return [f"{POLICY}: retention scope must be exactly wazuh-events-v5-*"]
    return []


def validate_agent_configs() -> list[str]:
    errors = []
    files = sorted(AGENT_CONFIG_ROOT.glob("*/agent.conf"))
    if not files:
        return [f"{AGENT_CONFIG_ROOT}: no tracked agent group configurations found"]
    for path in files:
        try:
            root = ET.fromstring(path.read_text(encoding="utf-8"))
        except ET.ParseError as exc:
            errors.append(f"{path}: invalid XML: {exc}")
            continue
        if root.tag != "agent_config":
            errors.append(f"{path}: root element must be agent_config")
    return errors


def main() -> int:
    errors = []
    decoder_files = sorted(DECODER_ROOT.glob("**/decoders/*.yml"))
    if not decoder_files:
        errors.append(f"{DECODER_ROOT}: no active decoder YAML files found")
    for path in decoder_files:
        errors.extend(validate_decoder(path))

    for path in SAMPLE_FILES:
        if not path.is_file() or not path.read_text(encoding="utf-8").strip():
            errors.append(f"{path}: sample fixture file is missing or empty")

    errors.extend(validate_dashboard())
    errors.extend(validate_json_policy())
    errors.extend(validate_agent_configs())

    if errors:
        print("Active integration asset errors:")
        for error in errors:
            print(f"  - {error}")
        return 1

    print(
        f"Checked {len(decoder_files)} decoders, {len(SAMPLE_FILES)} fixture files, "
        "the dashboard bundle, retention policy, and tracked agent group configurations."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
