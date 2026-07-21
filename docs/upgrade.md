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

The deployment keeps real credentials and host-specific overrides in ignored
files:

```text
single-node/.env*
single-node/compose.*.yml
single-node/config-local/
```

They are not overwritten by `git pull`, but they should still be included in
the host's secure backup procedure. Back up the persistent Docker volumes as
required by `backup-and-restore.md` before a Wazuh version upgrade.

Do not use `docker compose down -v` during an update or upgrade unless deleting
the persistent deployment data is explicitly intended.

## Deploy a repository update

From the repository root, inspect local changes and pull the tracked update:

```bash
git status --short
git pull
cd single-node
```

Preview the merged configuration before applying it:

```bash
docker compose --env-file .env.staging -f docker-compose.yml -f compose.staging.yml config
```

Replace `.env.staging` and `compose.staging.yml` with the local production file
names where necessary.

Pull the configured images and converge the stack:

```bash
docker compose --env-file .env.staging -f docker-compose.yml -f compose.staging.yml pull
docker compose --env-file .env.staging -f docker-compose.yml -f compose.staging.yml up -d
```

If the update changes tracked Manager group configuration under
`tracked-config/wazuh-manager/shared/`, recreate the Manager so its bind-mounted
configuration is re-read:

```bash
docker compose --env-file .env.staging -f docker-compose.yml -f compose.staging.yml up -d --force-recreate wazuh.manager
```

## Verify the deployment

Check container health:

```bash
docker compose --env-file .env.staging -f docker-compose.yml -f compose.staging.yml ps
```

Inspect recent logs for components that were recreated:

```bash
docker compose --env-file .env.staging -f docker-compose.yml -f compose.staging.yml logs --since 10m wazuh.indexer wazuh.manager wazuh.dashboard
```

Then verify:

- The indexer, Manager, and dashboard are healthy.
- Dashboard login works with the host-local credentials.
- Existing agents reconnect.
- Expected enrollment groups remain available.
- Existing indexed data is visible.

## Version-upgrade boundary

When a repository update changes the Wazuh version, stop after reviewing the
merged Compose configuration unless the target release's `upgrade.md` confirms
that an in-place upgrade from the installed version is supported. Beta and
pre-release builds can have additional migration constraints.

Record the currently running and proposed images before proceeding:

```bash
docker compose --env-file .env.staging -f docker-compose.yml -f compose.staging.yml images
docker compose --env-file .env.staging -f docker-compose.yml -f compose.staging.yml config --images
```

Follow the target release's upstream migration procedure first, then use the
repository convergence and verification steps above.
