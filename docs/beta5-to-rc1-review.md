# Wazuh 5.0.0 beta 5 to RC1 review

This review compares the local `wazuh-5.0.0-beta5` and
`wazuh-5.0.0-rc1` source snapshots, plus their matching `wazuh-docker`
snapshots. The core diff contains 657 added, 143 removed, and 1,470 changed
files; the Docker diff contains 14 added, one removed, and 45 changed files.

## Changes that affect this deployment

| RC1 change | Impact here | Repository response |
| --- | --- | --- |
| No default component credentials | Existing username/password Compose environment variables are obsolete | Added per-component Compose secrets and the upstream credential generation/install/rotation tooling |
| Manager agent-listener certificate is no longer generated at boot | Manager refuses to start without a CA-signed listener pair | Added explicit `remoted.pem`/key mounts and certificate/SAN instructions |
| Enrollment tokens replace the fleet-wide password | `authd.pass` and `WAZUH_REGISTRATION_PASSWORD` no longer enroll new agents | Agent Compose and host-syslog runbook now use `WAZUH_ENROLLMENT_TOKEN` |
| Full Manager XML validation | A persisted beta configuration can stop the whole Manager | Migration removes `agents_disconnection_alert_time`, requires `cluster`/`indexer`, and adds the remote CA path |
| `wazuh-manager-monitord` removed | Manager-side `monitord.*` overrides are silently ignored | Migration calls out the `wazuh_modules.manager_task_*` namespace and removed monitor API |
| Detection content moved under persistent Manager data | Container recreation could otherwise lose runtime content | Added the `wazuh_data` named volume and RC1 refresh/exclusion scripts |
| Health checks fixed | Beta checks could report healthy while a component was broken | Adopted RC1 Manager and Dashboard checks |
| Upstream stopped publishing Indexer port 9200 | Local retention tooling uses `https://localhost:9200` | Intentionally retain `127.0.0.1:9200:9200`; never expose it publicly |
| Indexer and Dashboard bootstrap hardened | Images now resolve, store, and erase bootstrap credentials before dropping privileges | Synced RC1 entrypoints, Dockerfiles, password tools, and credential checks |
| Agent state persisted in Docker | Recreating an agent no longer creates an orphan identity | Added `wazuh_agent_etc` and retained token-based first enrollment |
| Manager supervision and host parsing corrected | Dead critical daemons, URL schemes, IPv6, and special-character passwords behaved incorrectly in beta | Synced the RC1 entrypoint fixes |

RC1 also changes agent deletion to a durable Task Manager operation. Automation
must not assume Indexer documents disappear immediately after `DELETE /agents`.
An overloaded deletion backlog can reject the request with error `1766`, leaving
the agent untouched for a later retry. The old active-configuration `monitor`
endpoint now returns HTTP 400.

Other reviewed core changes:

- an explicitly empty internal option now prevents its daemon from starting;
- new enrollment and reenrollment use scoped tokens and a per-agent secret,
  rather than one fleet-wide password;
- Engine output index names are restricted to the `wazuh-events-v5-` prefix,
  an approved character set/placeholders, and 255 characters;
- several large WCS fields, including `message`, changed their Indexer mapping
  from `keyword` to `text`, so new aggregations on those fields would fail;
- TLS trust and certificate hostname verification are now part of the agent
  bootstrap path instead of relying on a Manager-generated self-signed pair.

## Custom integration compatibility

The IPFire Netfilter, IPFire Suricata, and shared root YAML decoders do not need
a semantic rewrite for RC1:

- all WCS fields used by the decoders remain present with compatible types;
- helper functions used here (`array_append`, `array_append_any`, `contains`,
  `downcase`, `exists`, `get_date`, `is_ipv4`, and `is_ipv6`) still exist;
- the Engine decoder shape and parent relationship used by these assets remain
  valid;
- `wazuh-events-v5-*`, used by the retention policy and dashboard index
  pattern, satisfies RC1's stricter output-index naming rules;
- the dashboard does not aggregate on the large fields changed from `keyword`
  to `text` in RC1, including `message`.

The decoder reference URLs were moved away from the beta documentation path.
Runtime samples and dashboard objects remain unchanged because the relevant
event fields did not change.

## Migration risks

1. Do not run RC1 first against the only copy of beta volumes. Back up and test
   a clone.
2. A beta 5 `global.db` lacks RC1's `reenroll_secret` column. RC1 has no schema
   upgrade script from that beta layout, so be prepared to rebuild Manager
   state and re-enroll agents if the database fails to open.
3. Credential files for an existing deployment must agree with credentials
   already stored in the Indexer, Manager, and Dashboard. Randomly generating
   a new set does not rotate a running deployment.
4. The listener certificate SAN must include every IP or DNS name carried in an
   enrollment token. `wazuh.manager` alone only works inside Compose.
5. A beta `wazuh_etc` volume keeps its old XML. Image replacement does not
   install the RC1 default file over it.
6. Keep the deliberate local exposure policy: API and Indexer loopback-only,
   and UDP 514 owned by host rsyslog.

## Files deliberately not changed

The custom decoder logic, sample fixtures, exported IPFire dashboard, 14-day
retention policy, and centrally managed `syslog` agent group remain as-is.
Their dependencies were checked against the RC1 source schema and helpers, and
no RC1 incompatibility was found.
