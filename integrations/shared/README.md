# Shared custom-policy assets

These assets belong to the custom space policy rather than to a particular log
source. Create them only once per Wazuh content space.

For a clean installation, create an enabled integration named `custom-core`
with category **Other**, create
`decoders/core-wazuh-message.yml` under that integration, and select
`decoder/core-wazuh-message/0` as the Draft space policy root. Source-specific
integrations then reference this root but do not create their own copy.

The root initializes `@timestamp` with the Engine's current processing time. It
must not parse `event.original` as JSON because non-JSON children, including the
IPFire syslog decoders, would be rejected before their parsers can run.

The separate owner prevents deleting or replacing an IPFire, application, or
other source integration from also removing the policy entry decoder.

If an existing deployment already owns `decoder/core-wazuh-message/0` through
another integration, do not create a duplicate. The repository layout does not
require changing the live asset's ownership. Edit that live asset to match
`decoders/core-wazuh-message.yml`, then promote the change from Draft through
Test to Custom and confirm that CMSync applies the updated Custom policy.
