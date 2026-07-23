# IPFire dashboard

This is the recommended operational dashboard for combined IPFire Netfilter
and `suricata-reporter` events. It replaces the earlier Netfilter-only overview
and deliberately contains no Discover event table.

Import this Saved Objects bundle manually:

`integrations/ipfire/dashboard/ipfire-dashboard.ndjson`

## Prerequisites

- `ipfire-netfilter` is promoted to Custom if Netfilter panels are required.
- `ipfire-suricata` is promoted to Custom if Suricata panels are required.
- The Custom space has successfully synchronized in CMSync.
- Geolocation enrichment is enabled in the Custom policy. Maps display only
  events received after enrichment became active; older events are not
  backfilled.

Either IPFire integration can operate independently. Panels for an integration
that is not installed remain empty without affecting the other panels.

## Import

1. Open **Dashboard management > Saved Objects**.
2. Select **Import** and choose `ipfire-dashboard.ndjson`.
3. Leave overwrite disabled for the first import. Enable it when updating this
   same bundle later; the object IDs are stable.
4. Confirm that eighteen saved objects import successfully: one data view,
   sixteen visualizations, and one dashboard.
5. Open **Explore > Dashboards > IPFire Dashboard**.

The dashboard restores a one-hour time range and refreshes every sixty seconds.
Change either setting in the Dashboard UI when investigating a longer period.

## Operational panels

The dashboard provides:

- Netfilter logged-drop event count.
- Suricata alert count and Suricata DoS classification count.
- Unique affected destination IPs.
- Combined security-pressure and Suricata DoS timelines.
- Protected destinations and source IPs ranked by event count.
- Separate Netfilter and Suricata source-location maps.
- Suricata signatures and classifications.
- Sources ranked by logged Netfilter packet lengths.
- Source ASN organizations, targeted destination ports, and per-firewall event
  volume.

`network.bytes` is the IP `LEN` value for each logged Netfilter drop. Its sum is
**logged dropped bytes**, not interface utilization or customer bandwidth.
Suricata reporter alerts contain no byte or flow counter. Use IPFire Net-Traffic
or an external SNMP/flow monitoring system for authoritative bandwidth.

Likewise, event counts are counts of received log records or alerts. They are
useful pressure indicators but can differ from actual packet counts because of
firewall logging limits and Suricata alert thresholding.

## Validate indexed data

After both integrations are active, use Dev Tools:

```json
GET wazuh-events-v5-*/_search?ignore_unavailable=true
{
  "size": 0,
  "query": {
    "bool": {
      "filter": [
        {
          "terms": {
            "wazuh.integration.name": [
              "ipfire-netfilter",
              "ipfire-suricata"
            ]
          }
        },
        { "range": { "@timestamp": { "gte": "now-1h" } } }
      ]
    }
  },
  "aggs": {
    "datasets": { "terms": { "field": "event.dataset", "size": 10 } },
    "firewalls": { "terms": { "field": "observer.name", "size": 20 } },
    "affected_destinations": { "cardinality": { "field": "destination.ip" } },
    "source_locations": { "filter": { "exists": { "field": "source.geo.location" } } }
  }
}
```

If maps are empty while other panels have current events, confirm recent
documents contain `source.geo.location`. If the import rejects `tile_map`, save
the full error message; map saved-object schemas can differ between Dashboard
beta builds and the remaining dashboard objects may still import successfully.
