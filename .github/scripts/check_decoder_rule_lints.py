import re
import sys
from pathlib import Path


DECODERS_DIR = Path("provisioning-archive/wazuh_manager/etc/decoders")
RULES_DIR = Path("provisioning-archive/wazuh_manager/etc/rules")

SUSPICIOUS_REGEX_PATTERNS = [
    re.compile(r"\(\\\.\+\)"),
    re.compile(r"process_kprobe\\\.\*"),
]

NON_WINDOWS_UPPER_EVENTDATA = re.compile(r"(?<!win\.)eventdata\.[A-Z][A-Za-z]+")


def main() -> int:
    errors = []
    decoder_files = sorted(DECODERS_DIR.glob("*.xml"))
    rule_files = sorted(RULES_DIR.glob("*.xml"))

    if not decoder_files or not rule_files:
        print("Archived decoder/rule inputs are missing; refusing to pass an empty check.")
        return 1

    for path in decoder_files:
        text = path.read_text(encoding="utf-8")
        for pattern in SUSPICIOUS_REGEX_PATTERNS:
            for match in pattern.finditer(text):
                line = text.count("\n", 0, match.start()) + 1
                errors.append(f"{path}:{line}: suspicious decoder regex {match.group(0)!r}")

    for path in rule_files:
        text = path.read_text(encoding="utf-8")
        for match in NON_WINDOWS_UPPER_EVENTDATA.finditer(text):
            line = text.count("\n", 0, match.start()) + 1
            errors.append(f"{path}:{line}: use lowercase Linux field name {match.group(0)!r}")

    if errors:
        print("Decoder/rule lint errors:")
        for error in errors:
            print(f"  - {error}")
        return 1

    print("Decoder/rule lint checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
