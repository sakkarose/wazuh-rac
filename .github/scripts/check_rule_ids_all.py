import xml.etree.ElementTree as ET
from pathlib import Path
import sys
from collections import defaultdict

RULES_PATH = Path("single-node/provisioning/wazuh_manager/etc/rules")

def extract_rule_ids_from_xml(content):
    ids = []
    try:
            # Read file content if a Path or file object is passed
            if not isinstance(content, str):
                with open(content, 'r', encoding='utf-8') as f:
                    content = f.read()
            # Wrap in dummy root to allow multiple <group> elements
            wrapped = f'<rules>\n{content}\n</rules>'
            root = ET.fromstring(wrapped)
            for rule in root.findall(".//rule"):
                rule_id = rule.get("id")
                if rule_id and rule_id.isdigit():
                    ids.append(int(rule_id))
    except ET.ParseError as e:
        print(f"⚠️ XML Parse Error: {e}")
    return ids

def get_all_rule_ids():
    rule_id_to_files = defaultdict(set)
    for xml_file in RULES_PATH.glob("*.xml"):
        try:
            rule_ids = extract_rule_ids_from_xml(xml_file)
            for rule_id in rule_ids:
                rule_id_to_files[rule_id].add(xml_file.name)
        except Exception as e:
            print(f"⚠️ Error processing {xml_file}: {e}")
            continue
    return rule_id_to_files

def main():
    print("🔍 Checking all rule files for duplicate/conflicting rule IDs...")
    all_files = list(RULES_PATH.glob("*.xml"))
    print(f"Found {len(all_files)} rule files:")
    for file in all_files:
        print(f"  • {file.name}")

    rule_id_to_files = get_all_rule_ids()
    print("\n🔢 Rule IDs found:")
    for rule_id, files in rule_id_to_files.items():
        print(f"  Rule ID {rule_id} in files: {', '.join(files)}")

    duplicate_ids = {rule_id: files for rule_id, files in rule_id_to_files.items() if len(files) > 1}
    if duplicate_ids:
        print("\n⚠️ WARNING: Duplicate rule IDs found across files:")
        for rule_id, files in duplicate_ids.items():
            print(f"  Rule ID {rule_id} is used in multiple files: {', '.join(files)}")
        sys.exit(1)
    else:
        print("\n✅ No duplicate rule IDs found!")
        sys.exit(0)

if __name__ == "__main__":
    main()
    print("\n📝 Use ID numbers between 100000 and 120000 for custom rules.")
