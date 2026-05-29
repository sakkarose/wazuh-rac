import sys
from pathlib import Path


SEARCH_ROOTS = [
    Path(".github"),
    Path("single-node/provisioning/wazuh_endpoint"),
]

STALE_PATTERNS = [
    "single-node/config/wazuh_endpoint",
    "single-node/config/wazuh_cluster/rules",
    "single-node/config/wazuh_cluster",
]


def main() -> int:
    errors = []

    for root in SEARCH_ROOTS:
        for path in root.rglob("*"):
            if not path.is_file():
                continue
            if path.resolve() == Path(__file__).resolve():
                continue
            try:
                text = path.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                continue

            for pattern in STALE_PATTERNS:
                index = text.find(pattern)
                if index >= 0:
                    line = text.count("\n", 0, index) + 1
                    errors.append(f"{path}:{line}: stale path {pattern!r}")

    if errors:
        print("Stale path references found:")
        for error in errors:
            print(f"  - {error}")
        return 1

    print("No stale moved-path references found.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
