# Update or upgrade a Wazuh Docker host

This guide separates two operations that should not be treated as equivalent:

- A **repository update** deploys newer tracked provisioning configuration for
  the same Wazuh release.
- A **Wazuh version upgrade** changes component versions and may require an
  upstream migration procedure.

For an actual version upgrade, review these upstream files for the target
release before changing image tags or starting containers:

- `upgrade.md`
- `backup-and-restore.md`
- `compatibility.md`

The commands below deploy this repository's tracked state; they do not replace
an upstream Wazuh data or configuration migration.

## Preserve local state

The deployment keeps credentials, host-specific overrides, generated
certificates, and exported security configuration in ignored files:

```text
single-node/.env*
single-node/compose.*.yml
single-node/config.yml
single-node/config/
single-node/config-local/
single-node/wazuh-certs-tool*.sh
```

Because Git ignores these paths, `git pull` neither updates them nor warns when
their structure becomes stale. They must be audited against the tracked
examples after every repository update and backed up before a version upgrade.

Before a version upgrade, refresh the live OpenSearch Security export using the
procedure in `setup.md`. Treat that export as a rollback reference only. Never
apply an older release's `internal_users.yml` to a newer Indexer; after an
upgrade, export the new live configuration first and change only the required
password hashes.

Create a permission-restricted backup of the local files. This example uses the
production filenames; substitute the names used by the host:

```bash
cd single-node
BACKUP_DIR="config-local/upgrade-backups/$(date +%Y%m%d-%H%M%S)"
install -d -m 0700 "$BACKUP_DIR"
install -m 0600 .env.production "$BACKUP_DIR/.env.production"
install -m 0600 compose.production.yml "$BACKUP_DIR/compose.production.yml"
[ ! -f config.yml ] || install -m 0600 config.yml "$BACKUP_DIR/config.yml"
[ ! -d config ] || cp -a config "$BACKUP_DIR/"
[ ! -d config-local/opensearch-security ] || \
  cp -a config-local/opensearch-security "$BACKUP_DIR/"
```

This local copy does not replace an off-host backup. Back up the persistent
Docker volumes as required by `backup-and-restore.md` before a Wazuh version
upgrade.

Do not use `docker compose down -v` during an update or upgrade unless deleting
the persistent deployment data is explicitly intended.

## Deploy a repository update

From the repository root, record the current revision, inspect tracked and
ignored state, and pull only a fast-forward update:

```bash
git status --short
git status --short --ignored=matching single-node/
OLD_COMMIT=$(git rev-parse HEAD)
git pull --ff-only
git diff --stat "$OLD_COMMIT"..HEAD
git diff "$OLD_COMMIT"..HEAD -- \
  .gitignore README.md single-node/docker-compose.yml \
  single-node/example.env single-node/example.compose.yml docs/
cd single-node
```

The second diff contains tracked templates and documentation only, so it does
not reveal the real values in ignored files. Reconcile every relevant template
change into the host-local files manually. Keep the local Compose override
minimal: it should not duplicate image tags, complete service definitions, or
port lists from the tracked base unless the host deliberately overrides them.

Check whether the tracked environment template added a variable without
printing any secret values. No output means the local file contains every
template key:

```bash
comm -23 \
  <(awk -F= '/^[A-Za-z_][A-Za-z0-9_]*=/{print $1}' example.env | sort -u) \
  <(awk -F= '/^[A-Za-z_][A-Za-z0-9_]*=/{print $1}' .env.production | sort -u)
```

Also list local-only keys. Review them against the release notes before
removing anything; local-only does not automatically mean obsolete:

```bash
comm -13 \
  <(awk -F= '/^[A-Za-z_][A-Za-z0-9_]*=/{print $1}' example.env | sort -u) \
  <(awk -F= '/^[A-Za-z_][A-Za-z0-9_]*=/{print $1}' .env.production | sort -u)
```

Validate the merged configuration, then inspect the proposed services and
images before pulling anything:

```bash
docker compose --env-file .env.production \
  -f docker-compose.yml -f compose.production.yml config --quiet
docker compose --env-file .env.production \
  -f docker-compose.yml -f compose.production.yml config --services
docker compose --env-file .env.production \
  -f docker-compose.yml -f compose.production.yml config --images
```

If an ignored override still supplies an older image tag, removed environment
variable, old volume source, or public `9200`/`55000` binding, correct it before
continuing. Use `docker compose ... config` for a full local inspection, but do
not paste or save that output in tickets or logs because it includes resolved
secret values.

Pull the configured images and converge the stack:

```bash
docker compose --env-file .env.production -f docker-compose.yml -f compose.production.yml pull
docker compose --env-file .env.production -f docker-compose.yml -f compose.production.yml up -d
```

If the update changes tracked Manager group configuration under
`tracked-config/wazuh-manager/shared/`, recreate the Manager so its bind-mounted
configuration is re-read:

```bash
docker compose --env-file .env.production -f docker-compose.yml -f compose.production.yml up -d --force-recreate wazuh.manager
```

## Verify the deployment

Check container health:

```bash
docker compose --env-file .env.production -f docker-compose.yml -f compose.production.yml ps
```

Inspect recent logs for components that were recreated:

```bash
docker compose --env-file .env.production -f docker-compose.yml -f compose.production.yml logs --since 10m wazuh.indexer wazuh.manager wazuh.dashboard
```

Then verify:

- The indexer, Manager, and dashboard are healthy.
- Dashboard login works with the host-local credentials.
- Existing agents reconnect.
- Expected enrollment groups remain available.
- Existing indexed data is visible.
- Ports `9200` and `55000` listen only on `127.0.0.1`.
- The event-retention policy remains attached and has no failed actions.

## Version-upgrade boundary

When a repository update changes the Wazuh version, stop after reviewing the
merged Compose configuration unless the target release's `upgrade.md` confirms
that an in-place upgrade from the installed version is supported. Beta and
pre-release builds can have additional migration constraints.

Record the currently running and proposed images before proceeding:

```bash
docker compose --env-file .env.production -f docker-compose.yml -f compose.production.yml images
docker compose --env-file .env.production -f docker-compose.yml -f compose.production.yml config --images
```

The ignored `wazuh-certs-tool.sh` is also version-specific. Download the target
release's tool when certificates must be generated, but do not overwrite
working certificates merely because the tool changed. Preserve existing
certificates when node identities are unchanged unless the target migration
guide requires regeneration or a key has been compromised.

Follow the target release's upstream migration procedure first, reconcile the
ignored files, and then use the repository convergence and verification steps
above. Do not restore an old ignored file wholesale after the upgrade: carry
forward only the settings that remain valid for the target release.
