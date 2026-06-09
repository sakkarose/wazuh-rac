# Wazuh Docker Host Deployment

This repository is intended to be cloned directly on each deployed host. The
tracked files keep the Wazuh Docker 5.0.0-beta2 single-node deployment generic,
while real credentials and host-specific overrides stay in ignored local files.

## File Model

- `single-node/docker-compose.yml` is the tracked base Compose file.
- `single-node/example.env` is a tracked env template.
- `single-node/example.compose.yml` is a tracked Compose override template.
- `single-node/example.internal_users.yml` is a tracked OpenSearch Security
  internal users template for password changes.
- `single-node/tracked-config/` contains shared deployment configuration that
  should update on every host through `git pull`, such as agent group configs.
- `single-node/.env` and `single-node/.env.*` are ignored and should contain
  real host secrets.
- `single-node/compose.*.yml` files are ignored and should contain host-specific
  Compose overrides.
- `single-node/config-local/` is ignored and can hold local security files such
  as the edited `internal_users.yml` and host-specific manager config.

You do not need to commit staging or production env/Compose files. Create those
files only on the host where Docker Compose will run.

## Clone

```bash
git clone https://github.com/sakkarose/wazuh-rac.git
cd wazuh-rac/single-node
```

## Linux/Unix Host Requirements

On Linux/Unix Docker hosts, set `vm.max_map_count` before starting Wazuh. The
Wazuh indexer needs a higher virtual memory map limit than the Linux default.

```bash
sudo sysctl -w vm.max_map_count=262144
```

If this value is lower than `262144`, the Wazuh indexer may fail or behave
incorrectly.

To run Docker as a non-root user, add that user to the `docker` group:

```bash
sudo usermod -aG docker <USER>
```

Replace `<USER>` with your username, then log out and back in for the group
change to take effect.

## Create Local Files

Copy the example env file to an ignored host-local file:

```bash
cp example.env .env.staging
```

Use a different name on another host if helpful, such as `.env.production`.

For the first startup, leave these stock reserved indexer users unchanged:

```text
admin / admin
kibanaserver / kibanaserver
```

These users are reserved in OpenSearch Security. Start the stack once with the
stock values, then change the passwords after the containers are healthy.

Copy the example Compose override to an ignored host-local file:

```bash
cp example.compose.yml compose.staging.yml
```

Review the local files:

```bash
nano .env.staging
nano compose.staging.yml
```

Docker Compose merges files from left to right. The tracked
`docker-compose.yml` is the base file, and `compose.staging.yml` overrides only
the fields you define.

Preview the final merged configuration:

```bash
docker compose --env-file .env.staging -f docker-compose.yml -f compose.staging.yml config
```

## Prepare Certificates

Create the certificate config:

```bash
cat > config.yml <<'EOF'
nodes:
  indexer:
    - name: wazuh.indexer
      dns: "wazuh.indexer"

  manager:
    - name: wazuh.manager
      dns: "wazuh.manager"

  dashboard:
    - name: wazuh.dashboard
      dns: "wazuh.dashboard"
EOF
```

Download the Wazuh 5.0.0-beta2 certificate tool:

```bash
curl -o wazuh-certs-tool.sh https://packages-staging.xdrsiem.wazuh.info/pre-release/5.x/installation-assistant/wazuh-certs-tool-5.0.0-beta2.sh
```

The downloaded `wazuh-certs-tool.sh` file is ignored by git, so it will not
block future `git pull` operations.

Generate and place certificates:

```bash
bash ../tools/utils/deployment/certificates-conf.sh --cert --copy --priv
```

## Agent Group Directories

To make enrollment groups available at boot, bind-mount their shared
directories into the manager. This keeps the same model as older Wazuh
deployments: each group is a directory under the manager shared config path.

The tracked baseline currently provides these group configs:

```text
tracked-config/wazuh-manager/shared/windows/agent.conf
tracked-config/wazuh-manager/shared/linux/agent.conf
```

They can remain empty until you add group-specific agent configuration. Because
these files are tracked, future group config updates arrive on each host through
the normal `git pull` update flow. Wazuh validates enrollment groups by checking
that the corresponding shared group directory exists under
`/var/wazuh-manager/etc/shared/`; otherwise enrollment requests for that group
are rejected as `Invalid group`.

After startup, verify the groups:

```bash
docker exec single-node-wazuh.manager bash -lc '
/var/wazuh-manager/bin/agent_groups -l
'
```

To provision real group config later, edit the tracked group files and deploy
them with the normal repository update procedure.

## First Deployment

Start the stack with the stock reserved-user passwords:

```bash
docker compose --env-file .env.staging -f docker-compose.yml -f compose.staging.yml up -d
```

Keep the dashboard port restricted during this bootstrap phase because the
stock credentials are still active.

Wait until the containers are healthy:

```bash
docker compose --env-file .env.staging -f docker-compose.yml -f compose.staging.yml ps
```

The first startup can take a minute or two while the Wazuh indexer and dashboard
initialize. It is normal to see temporary dashboard logs saying it cannot
connect to the Wazuh indexer on port `9200` until the indexer is ready.

## Change Reserved Indexer Passwords

Reserved users such as `admin` and `kibanaserver` cannot be changed from the
dashboard UI. After the first deployment is healthy, apply a modified
`internal_users.yml` with OpenSearch Security's `securityadmin.sh`.

Create the ignored local users file:

```bash
mkdir -p config-local/opensearch-security
cp example.internal_users.yml config-local/opensearch-security/internal_users.yml
```

Generate bcrypt hashes for the new passwords:

```bash
docker run --rm -e OPENSEARCH_JAVA_HOME=/usr/share/wazuh-indexer/jdk \
  --entrypoint /usr/share/wazuh-indexer/plugins/opensearch-security/tools/hash.sh \
  wazuh/wazuh-indexer:5.0.0-beta2 -p 'NewAdminPass1?'

docker run --rm -e OPENSEARCH_JAVA_HOME=/usr/share/wazuh-indexer/jdk \
  --entrypoint /usr/share/wazuh-indexer/plugins/opensearch-security/tools/hash.sh \
  wazuh/wazuh-indexer:5.0.0-beta2 -p 'NewKibanaServerPass1?'
```

Edit the local internal users file and replace only the `hash:` values for the
users you are changing, usually `admin` and `kibanaserver`:

```bash
nano config-local/opensearch-security/internal_users.yml
```

Copy the edited file into the running indexer container:

```bash
docker cp config-local/opensearch-security/internal_users.yml \
  single-node-wazuh.indexer:/tmp/internal_users.yml
```

Apply the file to the indexer security index:

```bash
docker exec -e OPENSEARCH_JAVA_HOME=/usr/share/wazuh-indexer/jdk \
  single-node-wazuh.indexer \
  /usr/share/wazuh-indexer/plugins/opensearch-security/tools/securityadmin.sh \
  -f /tmp/internal_users.yml \
  -t internalusers \
  -icl \
  -nhnv \
  -cacert /usr/share/wazuh-indexer/config/certs/root-ca.pem \
  -cert /usr/share/wazuh-indexer/config/certs/admin.pem \
  -key /usr/share/wazuh-indexer/config/certs/admin-key.pem \
  -h localhost \
  -p 9200
```

Update `.env.staging` with the matching plaintext passwords:

```env
INDEXER_USERNAME=admin
INDEXER_PASSWORD='NewAdminPass1?'
DASHBOARD_USERNAME=kibanaserver
DASHBOARD_PASSWORD='NewKibanaServerPass1?'
```

Recreate the manager and dashboard so they reconnect with the new credentials:

```bash
docker compose --env-file .env.staging -f docker-compose.yml -f compose.staging.yml up -d --force-recreate wazuh.manager wazuh.dashboard
```

Check health again:

```bash
docker compose --env-file .env.staging -f docker-compose.yml -f compose.staging.yml ps
```

If the dashboard returns `500 Internal Server Error` after the password
change, clear the browser site data for the dashboard URL or test in a private
browser window. A stale dashboard session from the stock credentials can cause
the login flow to fail even when the new indexer passwords are correct.

## Access Dashboard

After the password change, access the dashboard:

```text
https://<DOCKER_HOST_IP>
```

If you use self-signed certificates, the browser will warn that it cannot verify
the certificate.

## Update This Host

When new tracked configuration is pushed to this repository:

```bash
git pull
cd single-node
docker compose --env-file .env.staging -f docker-compose.yml -f compose.staging.yml config
docker compose --env-file .env.staging -f docker-compose.yml -f compose.staging.yml pull
docker compose --env-file .env.staging -f docker-compose.yml -f compose.staging.yml up -d
```

If the update includes tracked manager group config changes under
`tracked-config/wazuh-manager/shared/`, recreate the manager container so the
bind-mounted files are re-read:

```bash
docker compose --env-file .env.staging -f docker-compose.yml -f compose.staging.yml up -d --force-recreate wazuh.manager
```

Your local `.env*`, `compose.*.yml`, and `config-local/` files are ignored by
git, so they will not be overwritten by repository updates.

## Notes

- Do not commit real credentials.
- Keep host-specific changes in ignored files.
- Keep the tracked `docker-compose.yml` generic so future config updates can be
  pulled cleanly.
- Docker does not dynamically reload component configuration. After changing a
  component configuration or override, recreate the affected containers with
  `docker compose up -d`.
- The env and override files keep host-specific values out of git. They do not
  replace Wazuh/OpenSearch password-rotation procedures. Always verify the
  effective credentials before exposing the dashboard.
