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
upgrade. Include `wazuh-dashboard-config`: beta 5 stores the randomly generated
`wazuh_ai_assistant.encryptionKey` in that volume. Replacing the keystore with a
new one makes data encrypted with the previous key unreadable.

Do not use `docker compose down -v` during an update or upgrade unless deleting
the persistent deployment data is explicitly intended.

## Migrate an existing beta 4 Manager to beta 5

Do not start the beta 5 Manager against an unreviewed beta 4 `wazuh_etc`
volume. The volume preserves `wazuh-manager.conf`, so changing the image tag
does not install the beta 5 default configuration over it. In particular, beta
4 has a flat `<remote>` block, legacy `sslmanager.*` certificate paths, and an
`ssl_auto_negotiate` option that beta 5 no longer accepts.

While the beta 4 deployment is still healthy, export the live configuration
and enrollment state into the permission-restricted backup directory:

```bash
cd single-node
install -d -m 0700 config-local/beta4-to-beta5
docker cp single-node-wazuh.manager:/var/wazuh-manager/etc/wazuh-manager.conf \
  config-local/beta4-to-beta5/wazuh-manager.conf.beta4
docker cp single-node-wazuh.manager:/var/wazuh-manager/etc/client.keys \
  config-local/beta4-to-beta5/client.keys
docker cp single-node-wazuh.manager:/var/wazuh-manager/etc/authd.pass \
  config-local/beta4-to-beta5/authd.pass
cp -a config-local/beta4-to-beta5/wazuh-manager.conf.beta4 \
  config-local/beta4-to-beta5/wazuh-manager.conf.beta5
```

Edit only the necessary sections of
`config-local/beta4-to-beta5/wazuh-manager.conf.beta5`; retain unrelated local
settings. The beta 5 transport blocks must have this shape:

```xml
<remote>
  <https>
    <port>1517</port>
    <bind_addr>0.0.0.0</bind_addr>
    <global_prefix>/wazuh-manager/</global_prefix>
    <certificate>etc/certs/remoted.pem</certificate>
    <key>etc/certs/remoted-key.pem</key>
  </https>

  <legacy>
    <enabled>yes</enabled>
    <port>1514</port>
    <protocol>tcp</protocol>
    <local_ip>0.0.0.0</local_ip>
  </legacy>

  <agents>
    <allow_higher_versions>no</allow_higher_versions>
  </agents>
</remote>
```

In `<auth>`, remove `ssl_auto_negotiate` and set both certificate paths to the
same Manager identity:

```xml
<ssl_manager_cert>etc/certs/remoted.pem</ssl_manager_cert>
<ssl_manager_key>etc/certs/remoted-key.pem</ssl_manager_key>
```

Install the reviewed file into the persistent volume while the beta 4
container still exists. The running process does not reread it; stop the stack
immediately afterward so beta 4 is never restarted with the beta 5 file:

```bash
docker cp config-local/beta4-to-beta5/wazuh-manager.conf.beta5 \
  single-node-wazuh.manager:/tmp/wazuh-manager.conf.beta5
docker exec single-node-wazuh.manager \
  install -o root -g wazuh-manager -m 0640 \
  /tmp/wazuh-manager.conf.beta5 \
  /var/wazuh-manager/etc/wazuh-manager.conf
docker compose --env-file .env.production \
  -f docker-compose.yml -f compose.production.yml down
```

Do not delete `wazuh_etc`; it also holds `client.keys`, `authd.pass`, agent group
configuration, and other state required by existing agents. On the first beta
5 start, the Manager container generates `etc/certs/remoted.pem` and
`remoted-key.pem` when neither file exists.

Before starting, verify that the effective Compose configuration publishes
`1517/tcp` and mounts the Indexer connector certificate at
`etc/certs/indexer-connector.pem`, not the old `manager.pem` destination. Then
pull and start the beta 5 images using the commands below.

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
- Wazuh 5.x agents use HTTPS port `1517`; only agents awaiting migration use
  legacy ports `1514` and `1515`.
- Expected enrollment groups remain available.
- Existing indexed data is visible.
- Ports `9200` and `55000` listen only on `127.0.0.1`.
- The event-retention policy remains attached and has no failed actions.
- Custom-space CMSync completes without route-build errors.
- Every saved IPFire Netfilter and Suricata fixture passes Log test, the
  negative fixtures remain rejected, and one new live event from each source
  reaches its expected event stream.

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
