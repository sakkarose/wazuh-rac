# IPFire Netfilter dashboard

> **Legacy dashboard:** For the combined IPFire view, including
> Suricata and geographic panels, use
> [IPFire dashboard](ipfire-dashboard.md). This document is
> retained for the earlier Netfilter-only bundle.

This repository includes a premade OpenSearch Dashboards saved-object bundle
for the normalized events created by the `ipfire-netfilter` integration. The
operator imports the bundle through the Wazuh Dashboard Saved Objects UI; the
operator does not need to build or export the dashboard first.

This repository does not automatically import dashboard saved objects during
Docker Compose startup. Mounting an NDJSON file into the Dashboard container
does not import it.

The dashboard visualizes indexed events, not findings. A zero count on the
Wazuh findings overview is therefore expected unless detection rules and a
detector are added separately.

## Import the premade dashboard

Import this artifact:

[ipfire-netfilter-dashboard.ndjson](../integrations/ipfire-netfilter/dashboard/ipfire-netfilter-dashboard.ndjson)

It contains fifteen saved objects with stable IDs:

- One dedicated `wazuh-events-v5-network-activity*` data view.
- Twelve visualizations.
- One saved Discover search.
- The **IPFire Netfilter Overview** dashboard.

The dedicated data view is included intentionally so the visualizations do not
depend on an environment-generated data-view ID. It can coexist with another
data view that uses the same index pattern.

To install it:

1. Open **Dashboard management > Saved Objects**.
2. Select **Import**.
3. Choose `ipfire-netfilter-dashboard.ndjson` from this repository.
4. Leave overwrite disabled for the first import. Enable overwrite when
   replacing an earlier version of this same bundle; its stable IDs update the
   existing dashboard and add the new Geo/ASN panels.
5. Complete the import. The result should report fifteen successfully imported
   saved objects and no missing references.
6. Open **Explore > Dashboards > IPFire Netfilter Overview**.
7. Confirm the restored time range is **Last 15 minutes**.
8. Confirm that the panels contain only IPFire Netfilter events. Each panel and
   the saved search carry this query:

   ```text
   wazuh.integration.name: "ipfire-netfilter"
   AND event.dataset: "ipfire.netfilter"
   ```

If the import itself fails, record the complete Saved Objects import error and
stop. Do not manually recreate the failed objects or write to the Dashboard
saved-object system index. The bundle may need a saved-object schema adjustment
for the installed beta build.

### Repair a partially imported bundle

Earlier revisions of this bundle included newer Discover attributes such as
`grid` and `hideChart` in the saved search. Wazuh Dashboard 5.0.0-beta3 uses a
strict saved-search mapping and rejects them with errors such as:

```text
mapping set to strict, dynamic introduction of [grid] within [search] is not allowed
mapping set to strict, dynamic introduction of [hideChart] within [search] is not allowed
```

The current artifact uses a minimal saved-search object and contains neither
attribute. If nine objects were created and only **IPFire - Netfilter events**
failed:

1. Download or copy the current `ipfire-netfilter-dashboard.ndjson` artifact.
2. Open **Dashboard management > Saved Objects > Import** again.
3. Select the corrected artifact and enable overwrite.
4. Complete the import. The existing nine stable object IDs are updated and the
   missing saved search is created.
5. Open **IPFire Netfilter Overview** and confirm that all thirteen panels load.

There is no need to delete the nine successfully imported objects first.

## Geo/ASN prerequisite

The country and source-organization panels require the **Geolocation**
enrichment in the active Custom policy. Selecting it only in Draft is not
enough: promote the policy through **Draft > Test > Custom**. Geo/ASN fields
are added only to events received after the Custom policy synchronizes; Wazuh
does not backfill older indexed events.

Confirm a recent event contains `source.geo` and `source.as` before diagnosing
an empty country or organization panel:

```json
GET wazuh-events-v5-network-activity*/_search
{
  "size": 1,
  "_source": [
    "@timestamp",
    "wazuh.space.name",
    "source.ip",
    "source.geo",
    "source.as"
  ],
  "sort": [
    { "@timestamp": "desc" }
  ],
  "query": {
    "bool": {
      "filter": [
        { "term": { "wazuh.integration.name": "ipfire-netfilter" } }
      ]
    }
  }
}
```

## Manual construction fallback

Use the following construction procedure only if the premade bundle cannot be
made compatible with the installed Wazuh Dashboard beta build.

### 1. Select the data view and scope the data

Open **Explore > Discover** and select the narrowest available data view:

```text
wazuh-events-v5-network-activity*
```

If that data view has not been created, use `wazuh-events-v5*` temporarily or
create one with `@timestamp` as its time field.

Set the time range to **Last 15 minutes**, then apply this DQL filter:

```text
wazuh.integration.name: "ipfire-netfilter"
AND event.dataset: "ipfire.netfilter"
```

Both clauses are intentional. They exclude unrelated network events and any
historical documents created before the IPFire child decoder was narrowed.
Save the search as **IPFire - Netfilter events** with these columns:

- `observer.name`
- `rule.name`
- `source.ip`
- `source.geo.country_name`
- `source.as.organization.name`
- `source.port`
- `destination.ip`
- `destination.port`
- `network.transport`
- `network.bytes`
- `observer.ingress.interface.name`
- `observer.egress.interface.name`

Use `@timestamp` for dashboard time filtering. `event.start` is the timestamp
parsed from the original firewall message and is useful for investigating
forwarding delay.

### 2. Create the visualizations

Open **Explore > Visualize**, create each visualization against
`wazuh-events-v5-network-activity*`, and give every visualization the same two
filters used above. Use **Count** as the metric unless stated otherwise.

| Saved visualization | Type | Buckets |
| --- | --- | --- |
| `IPFire - Dropped packets` | Metric | Count |
| `IPFire - Logged dropped bytes` | Metric | Sum of `network.bytes` |
| `IPFire - Drops over time` | Line or area | Date histogram on `@timestamp`; automatic interval |
| `IPFire - Drop reasons` | Horizontal bar | Terms on `rule.name`; size 10; descending count |
| `IPFire - Top source IPs` | Horizontal bar | Terms on `source.ip`; size 20; descending count |
| `IPFire - Top source IPs by logged bytes` | Horizontal bar | Terms on `source.ip`; size 20; descending sum of `network.bytes` |
| `IPFire - Source countries` | Horizontal bar | Terms on `source.geo.country_name`; size 15; descending count |
| `IPFire - Source countries by logged bytes` | Horizontal bar | Terms on `source.geo.country_name`; size 15; descending sum of `network.bytes` |
| `IPFire - Source network organizations` | Horizontal bar | Terms on `source.as.organization.name`; size 15; descending count |
| `IPFire - Targeted ports` | Horizontal bar | Terms on `destination.port`; size 15; descending count |
| `IPFire - Transport protocols` | Donut | Terms on `network.transport` |
| `IPFire - Drops by firewall` | Horizontal bar | Terms on `observer.name`; size 20; descending count |

`network.bytes` comes from the Netfilter IP packet `LEN` value. Its sum is the
volume represented by logged dropped packets, not total firewall or customer
bandwidth. Firewall log-rate limiting and traffic that is not logged are not
represented, so retain the **logged dropped bytes** wording in titles and
reports.

For the current single-firewall test, **Drops by firewall** contains one bar.
It starts separating devices automatically when events from additional IPFire
senders arrive and their sender addresses populate `observer.name`.

Keep terms sizes bounded. The measured test rate is high enough that an
unbounded source-IP table would be noisy and expensive to render.

### 3. Assemble the dashboard

1. Open **Explore > Dashboards > Create dashboard**.
2. Add the twelve saved visualizations and the saved Discover search.
3. Pin the integration and dataset filters at dashboard level.
4. Place packet count, logged bytes, protocol, and firewall summaries at the
   top. Put the time series across the full width, followed by paired count and
   logged-byte rankings for sources and countries. Put the source organization
   panel above the event search.
5. Save it as **IPFire Netfilter Overview**.

Start with **Last 15 minutes** while validating ingestion. Change the saved
default to one or twenty-four hours only after checking index size and query
latency.

## Validate the dashboard data

If a panel is empty, run this aggregation in **Dev Tools** with the same time
range. It proves the fields used by all twelve visualization panels without depending on the
visualization configuration:

```json
GET wazuh-events-v5-network-activity*/_search?ignore_unavailable=true
{
  "size": 0,
  "query": {
    "bool": {
      "filter": [
        { "term": { "wazuh.integration.name": "ipfire-netfilter" } },
        { "term": { "event.dataset": "ipfire.netfilter" } },
        { "range": { "@timestamp": { "gte": "now-15m" } } }
      ]
    }
  },
  "aggs": {
    "logged_dropped_bytes": { "sum": { "field": "network.bytes" } },
    "drop_reasons": { "terms": { "field": "rule.name", "size": 10 } },
    "source_ips": { "terms": { "field": "source.ip", "size": 20 } },
    "source_ips_by_bytes": {
      "terms": {
        "field": "source.ip",
        "size": 20,
        "order": { "logged_bytes": "desc" }
      },
      "aggs": {
        "logged_bytes": { "sum": { "field": "network.bytes" } }
      }
    },
    "source_countries": {
      "terms": { "field": "source.geo.country_name", "size": 15 }
    },
    "source_organizations": {
      "terms": { "field": "source.as.organization.name", "size": 15 }
    },
    "destination_ports": { "terms": { "field": "destination.port", "size": 15 } },
    "protocols": { "terms": { "field": "network.transport", "size": 10 } },
    "firewalls": { "terms": { "field": "observer.name", "size": 20 } }
  }
}
```

If the query has hits but a panel is blank, confirm the panel uses the same
data view, time field, and filters. Country and organization panels also need
new events created after Geo enrichment reached Custom. If `observer.name` is unexpectedly shared
between firewalls, check whether they reach rsyslog through the same NAT or
intermediate relay.

## Export local dashboard changes

Export only after deliberately changing the imported dashboard or after using
the manual fallback procedure:

1. Open **Dashboard management > Saved Objects**.
2. Find and select **IPFire Netfilter Overview**.
3. Select **Export**.
4. Include related objects when prompted. The export must contain the dashboard,
   its visualizations, the saved Discover search, and required data-view
   references.
5. Save the resulting `.ndjson` file as an installation artifact, for example:

   ```text
   ipfire-netfilter-dashboard.ndjson
   ```

Review the export before committing it to the repository. Saved dashboard
objects should not normally contain credentials, but the file can contain
environment-specific URLs, object names, filters, or identifiers.

Do not edit the saved-object NDJSON by hand. Make dashboard changes in the
Wazuh Dashboard UI, validate them against actual indexed events, and export the
dashboard with all related objects. The exported object IDs and references
connect the dashboard to its visualizations, saved search, and data view.

Before adding a panel or aggregation, confirm that its fields are present and
correctly typed in representative IPFire events. A proposed visualization that
depends on fields absent from the sample and production logs should not be
added until the integration normalizes those fields.

Import an updated export through **Dashboard management > Saved Objects** with
overwrite enabled. Do not copy it into the Dashboard container, overwrite
Dashboard application files, or write directly to the Dashboard saved-object
system index.

## Suricata is a separate data source

Do not extend this Netfilter integration to accept Suricata messages. The
Netfilter integration routes packet-drop telemetry to `network-activity`, while
Suricata alerts should use a separate security integration and dashboard
panels. Once the Suricata events are normalized, a higher-level IPFire
dashboard may contain panels from both event categories.

## References

- [Wazuh 5 Dashboard configuration and custom dashboards](https://documentation.wazuh.com/5.0-beta/user-manual/wazuh-dashboard/wazuh-dashboard-configurations.html)
- [Wazuh 5 Dashboard management and Saved Objects](https://documentation.wazuh.com/5.0-beta/user-manual/wazuh-dashboard/navigating-the-wazuh-dashboard.html)
- [Wazuh custom dashboard procedure](https://documentation.wazuh.com/current/user-manual/wazuh-dashboard/creating-custom-dashboards.html)
