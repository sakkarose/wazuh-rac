# Wazuh Docker Host Provisioning

This repository provisions a Wazuh Docker 5.0.0-beta5 single-node deployment.
It is intended to be cloned directly on each deployed host. Tracked files keep
the deployment consistent, while real credentials and host-specific overrides
remain in ignored local files.

## Documentation

- [Set up a host](docs/setup.md)
- [Update or upgrade a host](docs/upgrade.md)
- [Collect remote syslog on the Docker host](docs/remote-syslog.md)
- [Retain indexed Wazuh events for 14 days](docs/indexer-retention.md)

These guides document only the choices and procedures specific to this
repository. Where the upstream Wazuh or Wazuh Docker documentation already
covers a subject, the guide names the relevant upstream Markdown file rather
than copying it. Links can therefore be added for the Wazuh release being
deployed.

## File model

- `single-node/docker-compose.yml` is the tracked base Compose file.
- `single-node/example.env` is the tracked environment template.
- `single-node/example.compose.yml` is the tracked Compose override template.
- `single-node/indexer-policies/` contains tracked policies that an
  administrator applies to the Indexer API after deployment.
- `single-node/tracked-config/` contains shared deployment configuration that
  should update on every host through `git pull`, such as agent group configs.
- `single-node/.env` and `single-node/.env.*` are ignored and contain real host
  secrets.
- `single-node/compose.*.yml` files are ignored and contain host-specific
  Compose overrides.
- `single-node/config-local/` is ignored and can contain local security files,
  such as an exported and edited beta 5 `internal_users.yml`.
- `provisioning-archive/` is retained as migration reference material and is
  not part of the active deployment.

Do not commit real credentials or host-specific files. Keep the tracked base
Compose file generic so configuration updates can be pulled cleanly on every
host.
