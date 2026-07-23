# IPFire Netfilter integration for Wazuh 5.0.0-beta3

This procedure creates a custom Wazuh 5 integration for IPFire Netfilter drop
messages collected from `/var/log/remote/*.log`. It uses the Wazuh Dashboard
Draft -> Test -> Custom workflow; it does not replace files in the manager
container or its persistent volumes.

The first version intentionally supports only the formats represented in
`integrations/ipfire-netfilter/samples/netfilter.samples.txt`:

- RFC 3339 rsyslog timestamps with a numeric or named sender hostname.
- The `kernel` program.
- `BLKLST_*` and `DROP_HOSTILE` prefixes.
- IPv4 TCP or UDP records containing `SRC`, `DST`, `PROTO`, `SPT`, and `DPT`.
- An empty `OUT=`, an optional `DF` flag, and trailing TCP/UDP fields.

It does not yet cover ICMP, IPv6, fragments without ports, other IPFire
Netfilter prefixes, or Suricata. Suricata belongs in a separate integration
with the `security` category.

## Files

- `integrations/shared/decoders/core-wazuh-message.yml`: the shared custom-space
  policy root. Create this decoder only once, preferably in a dedicated
  `custom-core` integration. Source integrations reuse it as a parent and must
  not create another copy.
  decoder required by the custom policy. Its check deliberately rejects every
  event that is not an IPFire `BLKLST_*` or `DROP_HOSTILE` record.
- `integrations/ipfire-netfilter/decoders/ipfire-netfilter.yml`: IPFire child
  decoder.
- `integrations/ipfire-netfilter/samples/netfilter.samples.txt`: sanitized logtest
  fixtures. Submit one line at a time.
- `integrations/ipfire-netfilter/dashboard/ipfire-netfilter-dashboard.ndjson`:
  premade Saved Objects bundle for manual import into Wazuh Dashboard.

## 1. Create the Draft integration

1. Open **Security Analytics** in the Wazuh Dashboard.
2. Select the **Draft** space in the top-right space selector.
3. Open **Overview > Integrations > Actions > Create**.
4. Enter:
   - **Title:** `ipfire-netfilter`
   - **Category:** `Network Activity`
   - **Author:** your team or organization
   - **Enabled:** on
5. Create the integration.

The category is important: production events from this integration are routed
to `wazuh-events-v5-network-activity`.

## 2. Create the two decoders

Remain in the **Draft** space.

1. Open **Normalization > Decoders > Actions > Create**.
2. If `decoder/core-wazuh-message/0` does not yet exist in Draft, first create
   an enabled `custom-core` integration with category **Other**, then create
   the root once under that integration using
   `integrations/shared/decoders/core-wazuh-message.yml`.
3. Select the `ipfire-netfilter` integration.
4. Create the integration decoder using the complete contents
   of `integrations/ipfire-netfilter/decoders/ipfire-netfilter.yml`.

The Dashboard/Content Manager assigns resource UUIDs. Do not add UUIDs by hand
unless the form explicitly requires them.

## 3. Confirm the space policy root decoder

1. Return to **Security Analytics > Overview** while still in **Draft**.
2. Open **Actions > Edit** for `ipfire-netfilter`.
3. Confirm the integration is enabled.
4. Select `decoder/core-wazuh-message/0` as the space policy root decoder.
5. Save the integration.

The root decoder is shared by the space policy. The IPFire decoder references
it as its parent; future integrations should reference the same root instead
of recreating it.

## 4. Promote Draft to Test

1. In **Security Analytics > Overview**, confirm the space is **Draft**.
2. Choose **Actions > Promote**.
3. Review the preview. It should add one integration and two decoders.
4. Enter the requested confirmation text and promote to **Test**.

Do not promote to Custom yet.

## 5. Validate every fixture with Log test

1. Change the space selector to **Test**.
2. Open **Security Analytics > Log test**.
3. Copy one complete line from
   `integrations/ipfire-netfilter/samples/netfilter.samples.txt` into **Log event**.
4. Run the test and repeat for all four lines.

Each line should show this decoder chain:

```text
decoder/core-wazuh-message/0
decoder/ipfire-netfilter/0
```

The Normalization result should contain at least:

```json
{
  "event": {
    "action": "packet-dropped",
    "category": ["network"],
    "dataset": "ipfire.netfilter",
    "kind": "event",
    "outcome": "success",
    "type": ["connection", "denied"]
  },
  "network": {
    "direction": "inbound",
    "transport": "tcp",
    "type": "ipv4"
  },
  "observer": {
    "product": "IPFire",
    "type": "firewall",
    "vendor": "IPFire Project"
  },
  "source": {
    "ip": "198.51.100.93",
    "port": 64321
  },
  "destination": {
    "ip": "203.0.113.11",
    "port": 22
  },
  "rule": {
    "name": "BLKLST_CIARMY"
  }
}
```

For the UDP fixture, `network.transport` must be `udp`. For the fixture with
`OUT=`, `observer.egress.interface.name` may be absent; that is expected.

Before continuing, confirm that the Log test result reports no Wazuh Common
Schema validation errors. If the root decoder matches but the child decoder
does not, leave the integration in Test and record the complete Log test result.

### Required negative test

The integration-specific child decoder must reject unrelated events. Submit
this line to Log test while the `ipfire-netfilter` Test integration is selected:

```text
Jul 22 08:52:29 example-host systemd[1]: Started Example Service.
```

It must not produce an `ipfire-netfilter` normalized event or include
`decoder/ipfire-netfilter/0` in the successful decoder chain. The shared
`decoder/core-wazuh-message/0` may still appear because it is the policy entry
point. Do not promote if the event is routed to
`wazuh.integration.name: ipfire-netfilter` with the IPFire dataset.

## 6. Test one current, unsanitized event

On the rsyslog/Wazuh-agent host, obtain a recent line:

```bash
sudo grep -aE 'kernel: (BLKLST_|DROP_HOSTILE )' \
  /var/log/remote/*.log | tail -n 1
```

Paste that complete line into Log test. It must produce the same decoder chain
and no schema errors. This catches format changes not represented by the saved
fixtures.

## 7. Promote Test to Custom

Only after all fixtures and one current event pass:

1. Select the **Test** space.
2. Open **Security Analytics > Overview > Actions > Promote**.
3. Review the preview and promote to **Custom**.

The custom policy becomes active after CMSync applies the change. A manager or
container restart is not required.

Verify synchronization on the Docker host:

```bash
docker exec single-node-wazuh.manager \
  sh -c 'grep -E "CM::Sync|CMSync" /var/wazuh-manager/logs/wazuh-manager.log | tail -n 30'
```

Do not proceed if the output reports a failed Custom-space route build.

## 8. Verify production events

Wait for a new matching IPFire event, then use **Discover** with the
`wazuh-events-v5*` data view and this DQL query:

```text
wazuh.integration.name: "ipfire-netfilter"
AND event.dataset: "ipfire.netfilter"
```

Alternatively, use **Dev Tools**:

```json
GET wazuh-events-v5-network-activity*/_search?ignore_unavailable=true
{
  "size": 20,
  "sort": [
    { "@timestamp": { "order": "desc" } }
  ],
  "query": {
    "bool": {
      "filter": [
        { "term": { "wazuh.integration.name": "ipfire-netfilter" } },
        { "term": { "event.dataset": "ipfire.netfilter" } }
      ]
    }
  }
}
```

The existing Standard integration may still index other messages from the same
file. Filter by `wazuh.integration.name`, not only by
`wazuh.protocol.location`, when checking this custom integration.

As a contamination check, wait one minute after Custom synchronization and run
this query. It must return zero documents from that post-change minute. A hit
means the integration root is accepting unrelated events:

```json
GET wazuh-events-v5-network-activity*/_count?ignore_unavailable=true
{
  "query": {
    "bool": {
      "filter": [
        { "term": { "wazuh.integration.name": "ipfire-netfilter" } },
        { "range": { "@timestamp": { "gte": "now-1m" } } }
      ],
      "must_not": [
        { "term": { "event.dataset": "ipfire.netfilter" } }
      ]
    }
  }
}
```

## Findings and dashboards

This initial integration normalizes and indexes events. It deliberately does
not include a detection rule or detector because creating a finding for every
blocked packet would be noisy. The Wazuh Overview severity counters can remain
at zero even while `ipfire.netfilter` events are visible in Discover.

Build operational visualizations from `wazuh-events-v5-network-activity*`, for
example:

- Dropped packets over time.
- Top `source.ip` and `destination.port` values.
- Counts by `rule.name` and `network.transport`.
- Counts by `observer.name` when multiple IPFire instances are connected.

The complete panel definitions and UI procedure are in
[IPFire Netfilter dashboard](ipfire-netfilter-dashboard.md).

Add narrowly scoped rules and a detector later for high-signal conditions that
should create findings.

## Rollback

If production processing causes errors, disable the integration in Draft and
promote that change through Test to Custom. Verify the promotion preview before
applying it. Do not delete the manager's synchronized Engine files and do not
edit the Standard space.

## References

- [Wazuh 5 security analytics detection workflow](https://documentation.wazuh.com/5.0-beta/user-manual/data-analysis/detection-workflow.html)
- [Wazuh Dashboard security analytics configuration](https://documentation.wazuh.com/5.0-beta/user-manual/wazuh-dashboard/wazuh-dashboard-configurations.html)
- [Wazuh Content Manager](https://wazuh.github.io/wazuh-indexer-plugins/ref/modules/content-manager/index.html)
