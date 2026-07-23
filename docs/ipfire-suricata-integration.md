# IPFire Suricata reporter integration

This integration normalizes the single-line IDS/IPS alerts that IPFire's
`suricata-reporter` already sends through remote syslog. It does not read or
replace `/var/run/suricata/reporter.socket`, change IPFire's Suricata YAML, or
require another service on the firewall.

The initial decoder supports the observed IPv4 UDP format with source and
destination ports. Its parser is expected to accept TCP when IPFire uses the
same layout, but TCP is not considered verified until a real sample passes Log
test. Do not assume it supports ICMP, IPv6, portless alerts, or a different
reporter layout until representative events pass Log test.

## Create and test

Use the Wazuh 5 **Draft -> Test -> Custom** workflow. Netfilter is not a
prerequisite:

1. Check whether `decoder/core-wazuh-message/0` already exists in Draft.
2. If it does not exist, create an enabled integration named `custom-core` with
   category **Other**, create the decoder from
   `integrations/shared/decoders/core-wazuh-message.yml` under it, and select
   that decoder as the Draft space policy root. Create this shared root only
   once.
3. In Draft, create an enabled integration named `ipfire-suricata` with the
   **Security** category.
4. Under `ipfire-suricata`, create only the decoder from
   `integrations/ipfire-suricata/decoders/ipfire-suricata.yml`. Do not create
   another copy of `decoder/core-wazuh-message/0` for this integration.
5. In the Draft space policy, retain
   `decoder/core-wazuh-message/0` selection as the root decoder. The root is
   shared by the entire space policy, not owned separately by every
   integration.
6. Enable **Geolocation** enrichment so public `source.ip` values receive Geo
   and ASN fields.
7. Promote Draft to Test.
8. Submit each line in
   `integrations/ipfire-suricata/samples/suricata-reporter.samples.txt` to Log
   test individually.

The expected decoder chain is:

```text
decoder/core-wazuh-message/0
decoder/ipfire-suricata/0
```

Expected normalized fields include:

```text
event.action: drop
event.dataset: ipfire.suricata
event.kind: alert
event.severity: 2
rule.id: 2019102
rule.version: 1
rule.name: ET DOS Possible SSDP Amplification Scan in Progress
rule.category: Attempted Denial of Service
source.ip: 45.194.67.120
source.port: 4886
destination.ip: 125.212.242.11
destination.port: 1900
network.transport: udp
observer.name: 169.254.254.9
```

Confirm Log test reports no Wazuh Common Schema validation errors. Also submit
an unrelated systemd line and a Netfilter `kernel:` line; neither may produce
the `ipfire-suricata` decoder chain.

After successful tests, promote Test to Custom and verify CMSync. New events
should be routed to the Security event stream. Locate them with:

```text
wazuh.integration.name: "ipfire-suricata"
AND event.dataset: "ipfire.suricata"
```

## Dashboard scope

This syslog format supports high-value security panels for alert volume, action,
priority, classification, signature, source geography/ASN, targeted public IP,
targeted port, transport, and firewall. It does not contain packet or flow byte
counters, so it cannot provide bandwidth usage or authoritative DDoS volume.

Keep bandwidth/capacity monitoring in IPFire's maintained Net-Traffic graphs or
an external monitoring system using IPFire's packaged Net-SNMP add-on.
