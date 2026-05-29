# Single-node provisioning

This directory contains the v4 single-node custom configuration migrated for the
v5 Docker layout.

The v5 manager image persists data under `/var/wazuh-manager` and copies files
mounted at `/wazuh-config-mount` into that tree during startup. The
`wazuh_manager/` directory mirrors the target manager filesystem, so
`wazuh_manager/etc/wazuh-manager.conf` becomes
`/var/wazuh-manager/etc/wazuh-manager.conf`.

The migrated indexer users and dashboard files are mounted directly by
`docker-compose.yml`:

- `wazuh_indexer/internal_users.yml`
- `wazuh_dashboard/opensearch_dashboards.yml`
- `wazuh_dashboard/wazuh.yml`

`wazuh_indexer/opensearch.yml` is kept as a migration reference only. The v5
indexer entrypoint edits its own `opensearch.yml` at startup, so bind-mounting
that file can prevent the entrypoint from replacing it and can reintroduce
settings removed from OpenSearch 3.x.

Certificates are not migrated from the v4 repository. Generate fresh v5
certificates with the documented single-node certificate workflow before
starting Compose. The generated files live under `single-node/config/` and are
already mounted by `docker-compose.yml`.

`wazuh_endpoint/` preserves the remaining endpoint-side assets from the old
repository. They are not mounted into the v5 containers by default because the
old v4 compose file did not mount them into the Wazuh stack directly.

Wazuh central management applies the shared `agent.conf` files under
`wazuh_manager/etc/shared/<group>/agent.conf`. It does not install endpoint OS
dependencies or copy files into arbitrary agent paths. Assets such as Sysmon
configs, YARA binaries/rules, active-response scripts, wodle scripts, and custom
SCA policy files still need a separate endpoint rollout step, such as the
preserved Windows provisioning script or another host-management tool.

Some migrated files contain inherited credentials or password hashes. Review
them before committing this directory to source control.

For local Compose runs, `single-node/.env` contains the old v4 credential
defaults and is ignored by git.
