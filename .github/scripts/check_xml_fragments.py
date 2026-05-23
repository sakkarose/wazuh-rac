import sys
import xml.etree.ElementTree as ET
from pathlib import Path


PATHS = [
    Path("single-node/provisioning/wazuh_manager/etc/rules"),
    Path("single-node/provisioning/wazuh_manager/etc/decoders"),
]


def read_fragment(path: Path) -> str:
    lines = path.read_text(encoding="utf-8").splitlines()
    if lines and lines[0].lstrip().startswith("<?xml"):
        lines = lines[1:]
    return "<root>\n" + "\n".join(lines) + "\n</root>"


def main() -> int:
    errors = []
    files = []
    for base in PATHS:
        files.extend(sorted(base.glob("*.xml")))

    for path in files:
        try:
            ET.fromstring(read_fragment(path))
        except ET.ParseError as exc:
            errors.append(f"{path}: {exc}")

    if errors:
        print("XML fragment syntax errors:")
        for error in errors:
            print(f"  - {error}")
        return 1

    print(f"Checked {len(files)} XML fragment files.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
