import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path
import sys
from collections import defaultdict, Counter

def run_git_command(args):
    result = subprocess.run(args, capture_output=True, text=True, check=True)
    return result.stdout

def get_changed_rule_files():
    try:
        # Get the last successful commit hash from the previous run
        last_run = run_git_command(["git", "rev-list", "-n", "1", "HEAD"])
        # Get changes between the last run and current state
        output = run_git_command(["git", "diff", "--name-status", f"{last_run.strip()}...HEAD"])
        
        changed_files = []
        rules_path = "single-node/config/wazuh_cluster/rules"
        
        for line in output.strip().splitlines():
            parts = line.strip().split(maxsplit=1)
            if len(parts) != 2:
                continue
            status, file_path = parts
            if file_path.startswith(f"{rules_path}/") and file_path.endswith(".xml"):
                changed_files.append((status, Path(file_path)))
        return changed_files
    except subprocess.CalledProcessError as e:
        print("❌ Failed to get changed files:", e)
        sys.exit(1)

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

    rules_path = Path("single-node/config/wazuh_cluster/rules")
    rule_id_to_files = defaultdict(set)
    for xml_file in rules_path.glob("*.xml"):
        try:
            rule_ids = extract_rule_ids_from_xml(xml_file)
            for rule_id in rule_ids:
                rule_id_to_files[rule_id].add(xml_file.name)
        except Exception as e:
            print(f"⚠️ Error processing {xml_file}: {e}")
            continue
    return rule_id_to_files

def get_all_rule_ids():
    rules_path = Path("single-node/config/wazuh_cluster/rules")
    rule_id_to_files = defaultdict(set)
    
    for xml_file in rules_path.glob("*.xml"):
        try:
            rule_ids = extract_rule_ids_from_xml(xml_file)
            for rule_id in rule_ids:
                rule_id_to_files[rule_id].add(xml_file.name)
        except Exception as e:
            print(f"⚠️ Error processing {xml_file}: {e}")
            continue
    
    return rule_id_to_files

def get_rule_ids_from_previous_version(file_path: Path):
    try:
        content = run_git_command(["git", "show", f"HEAD:{file_path.as_posix()}"])
        return extract_rule_ids_from_xml(content)
    except subprocess.CalledProcessError:
        return []

def print_conflicts(conflicting_ids, rule_id_to_files):
    print("❌ Conflicts detected:")
    for rule_id in sorted(conflicting_ids):
        files = rule_id_to_files.get(rule_id, [])
        print(f"  - Rule ID {rule_id} found in:")
        for f in sorted(files):
            print(f"    • {f}")

def main():
    changed_files = get_changed_rule_files()
    if not changed_files:
        print("✅ No rule files were changed since last run.")
        return

    print(f"� Checking rule ID conflicts for changed files: {[f.name for _, f in changed_files]}")
    
    # Get existing rule IDs from all files
    rule_id_to_files = get_all_rule_ids()
    
    for status, path in changed_files:
        print(f"\n🔎 Checking file: {path.name}")
        
        try:
            if status != "D":  # If file wasn't deleted
                current_content = path.read_text()
                current_ids = extract_rule_ids_from_xml(current_content)
                
                # Check for internal duplicates in the current file
                counter = Counter(current_ids)
                duplicates = [rule_id for rule_id, count in counter.items() if count > 1]
                if duplicates:
                    print(f"❌ Duplicate rule IDs within {path.name}: {sorted(duplicates)}")
                    sys.exit(1)
            
            if status == "A":  # Added file
                # Check if new rule IDs conflict with existing ones
                conflicting_ids = {
                    rule_id for rule_id in current_ids 
                    if rule_id in rule_id_to_files and path.name not in rule_id_to_files[rule_id]
                }
                if conflicting_ids:
                    print_conflicts(conflicting_ids, rule_id_to_files)
                    sys.exit(1)
                print(f"✅ No conflicts in new file {path.name}")
                
            elif status == "M":  # Modified file
                # Get previous version's rule IDs
                previous_ids = get_rule_ids_from_previous_version(path)
                
                if set(current_ids) == set(previous_ids):
                    print(f"ℹ️ {path.name} modified but rule IDs unchanged.")
                    continue
                
                # Check new or changed IDs against existing ones
                new_ids = set(current_ids) - set(previous_ids)
                conflicting_ids = {
                    rule_id for rule_id in new_ids 
                    if rule_id in rule_id_to_files and path.name not in rule_id_to_files[rule_id]
                }
                
                if conflicting_ids:
                    print_conflicts(conflicting_ids, rule_id_to_files)
                    sys.exit(1)
                print(f"✅ Modified file {path.name} has no conflicting rule IDs.")
                
            elif status == "D":  # Deleted file
                print(f"ℹ️ File {path.name} was deleted, skipping checks.")
        
        except Exception as e:
            print(f"⚠️ Error processing {path.name}: {e}")
            sys.exit(1)

    print("\n✅ All rule changes passed conflict checks.")

if __name__ == "__main__":
    main()
