import re
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path


RULES_DIR = Path("single-node/provisioning/wazuh_manager/etc/rules")
LISTS_DIR = Path("single-node/provisioning/wazuh_manager/etc/lists")
SHA256_RE = re.compile(r"^[A-Fa-f0-9]{64}$")


def parse_rule_fragment(path: Path) -> ET.Element:
    content = path.read_text(encoding="utf-8")
    return ET.fromstring(f"<root>\n{content}\n</root>")


def iter_list_references():
    for rule_file in sorted(RULES_DIR.glob("*.xml")):
        root = parse_rule_fragment(rule_file)
        for node in root.iter("list"):
            list_path = (node.text or "").strip()
            field = node.attrib.get("field", "")
            if list_path:
                yield rule_file, field, list_path


def validate_list_file(path: Path, expect_sha256: bool):
    warnings = []
    errors = []
    keys = defaultdict(int)

    for lineno, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue

        key = line.split(":", 1)[0] if ":" in line else line
        keys[key] += 1

        if expect_sha256 and not SHA256_RE.fullmatch(key):
            warnings.append(f"{path}:{lineno}: SHA256 lookup references non-SHA256 key {key!r}")

    duplicates = sorted(key for key, count in keys.items() if count > 1)
    for key in duplicates:
        warnings.append(f"{path}: duplicate list key {key!r}")

    return errors, warnings


def main() -> int:
    errors = []
    warnings = []
    referenced = list(iter_list_references())

    for rule_file, field, list_path in referenced:
        if not list_path.startswith("etc/lists/"):
            errors.append(f"{rule_file}: list path should start with etc/lists/: {list_path}")
            continue

        local_path = LISTS_DIR / list_path.removeprefix("etc/lists/")
        if not local_path.is_file():
            errors.append(f"{rule_file}: referenced list does not exist: {list_path}")
            continue

        list_errors, list_warnings = validate_list_file(local_path, field == "sha256")
        errors.extend(list_errors)
        warnings.extend(list_warnings)

    for warning in warnings:
        print(f"WARNING: {warning}")

    if errors:
        print("List validation errors:")
        for error in errors:
            print(f"  - {error}")
        return 1

    print(f"Checked {len(referenced)} rule list references.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
