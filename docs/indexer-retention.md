# Retain Wazuh event data for 14 days

Wazuh 5 beta 5 writes decoded events to data streams named
`wazuh-events-v5-*`. Each data stream contains hidden backing indices. A delete
policy without rollover cannot remove the current write index, so this
repository's policy performs both operations:

- roll over at one day or when a primary shard reaches 20 GB, whichever occurs
  first;
- delete each non-write backing index when its index age reaches 14 days.

The tracked policy is
`single-node/indexer-policies/wazuh-events-14d.json`. It deliberately matches
only `wazuh-events-v5-*`. It does not manage findings, stateful inventory,
content, dashboard, security, metrics, or other internal indices.

Deletion is permanent. Take any required snapshot before enabling the policy.
Fourteen days is the initial value for this deployment, not a capacity
guarantee; measure the real event rate and disk use after the IPFire senders are
connected.

## Inspect the current data streams

Run the commands from `single-node`. They authenticate with the local admin
certificate, so no password is placed in the shell history:

```bash
curl --fail --silent --show-error \
  --cacert config/root-ca/certs/root-ca.pem \
  --cert config/wazuh_indexer/certs/admin.pem \
  --key config/wazuh_indexer/certs/admin-key.pem \
  'https://localhost:9200/_data_stream/wazuh-events-v5-*?pretty'
```

Record cluster disk capacity and the current event-stream size:

```bash
curl --fail --silent --show-error \
  --cacert config/root-ca/certs/root-ca.pem \
  --cert config/wazuh_indexer/certs/admin.pem \
  --key config/wazuh_indexer/certs/admin-key.pem \
  'https://localhost:9200/_cat/allocation?v&bytes=gb'

curl --fail --silent --show-error \
  --cacert config/root-ca/certs/root-ca.pem \
  --cert config/wazuh_indexer/certs/admin.pem \
  --key config/wazuh_indexer/certs/admin-key.pem \
  'https://localhost:9200/_data_stream/wazuh-events-v5-*/_stats?pretty'
```

An empty `data_streams` array means no decoded event stream exists yet. Create
the policy now; its ISM template will attach it when matching streams are
created later.

## Create the policy

```bash
curl --fail --silent --show-error \
  --cacert config/root-ca/certs/root-ca.pem \
  --cert config/wazuh_indexer/certs/admin.pem \
  --key config/wazuh_indexer/certs/admin-key.pem \
  -H 'Content-Type: application/json' \
  -X PUT \
  'https://localhost:9200/_plugins/_ism/policies/wazuh-events-14d' \
  --data-binary @indexer-policies/wazuh-events-14d.json
```

The `ism_template` applies automatically only when a new matching backing index
is created. It does not retroactively manage backing indices that existed
before the policy, so adopt them explicitly:

```bash
curl --fail --silent --show-error \
  --cacert config/root-ca/certs/root-ca.pem \
  --cert config/wazuh_indexer/certs/admin.pem \
  --key config/wazuh_indexer/certs/admin-key.pem \
  -H 'Content-Type: application/json' \
  -X POST \
  'https://localhost:9200/_plugins/_ism/add/.ds-wazuh-events-v5-*?expand_wildcards=all' \
  -d '{"policy_id":"wazuh-events-14d"}'
```

The response must report `"failures": false`. The prefixed pattern is
intentional. Never replace it with a bare `*`, because a delete policy applied
that broadly can destroy Wazuh security and system indices.

If an existing event backing index already has another policy, the add request
leaves that policy unchanged. Inspect it and decide deliberately whether to
replace it; do not force a policy change across all indices.

## Verify rollover and retention

Check every matching backing index:

```bash
curl --fail --silent --show-error \
  --cacert config/root-ca/certs/root-ca.pem \
  --cert config/wazuh_indexer/certs/admin.pem \
  --key config/wazuh_indexer/certs/admin-key.pem \
  'https://localhost:9200/_plugins/_ism/explain/.ds-wazuh-events-v5-*?expand_wildcards=all&show_policy=true&validate_action=true&pretty'
```

Each result should show `policy_id` as `wazuh-events-14d`, state `hot`, and no
rollover validation error. ISM runs periodically rather than immediately. Once
a write index is one day old or reaches 20 GB, the data stream should gain a
new generation and the old backing index becomes eligible for deletion at 14
days:

```bash
curl --fail --silent --show-error \
  --cacert config/root-ca/certs/root-ca.pem \
  --cert config/wazuh_indexer/certs/admin.pem \
  --key config/wazuh_indexer/certs/admin-key.pem \
  'https://localhost:9200/_data_stream/wazuh-events-v5-*?pretty'
```

Monitor this together with `_cat/allocation`. If 14 days approaches the
indexer's disk limit, reduce `min_index_age` in the transition to `7d` and
update the policy using its current sequence number and primary term. Do not
edit the live policy casually: OpenSearch requires concurrency parameters for
updates, and managed indices adopt policy changes asynchronously.

Raw files under `/var/log/remote` have a separate logrotate policy. Changing
this Indexer policy neither changes nor deletes those host files.
