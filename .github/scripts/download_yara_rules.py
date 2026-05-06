from valhallaAPI.valhalla import ValhallaAPI

import os

script_dir = os.path.dirname(os.path.abspath(__file__))
yara_dir = os.path.abspath(os.path.join(script_dir, '../../single-node/config/wazuh_endpoint/windows/yara'))
os.chdir(yara_dir)

# Initialize ValhallaAPI with the API key
v = ValhallaAPI(api_key="1111111111111111111111111111111111111111111111111111111111111111")

# Get the YARA rules text
response = v.get_rules_text()

# Save the YARA rules to yara_rules.yar
with open('yara_rules.yar', 'w') as fh:
    fh.write(response)

# Append yara_rules.yar with yara_rules_append.yar
with open('yara_rules_append.yar', 'r') as append_fh:
    append_content = append_fh.read()

with open('yara_rules.yar', 'a') as fh:
    fh.write(append_content)