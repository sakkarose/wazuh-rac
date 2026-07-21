# Set up a Wazuh Docker host

This guide describes the repository-specific procedure for deploying the
tracked Wazuh 5.0.0-beta3 single-node stack on a Linux host.

For upstream prerequisites and the standard Docker deployment model, refer to:

- `requirements.md`
- `single-node.md`
- `configuration.md`
- `environment-variables.md`

## Clone the repository

```bash
git clone https://github.com/sakkarose/wazuh-rac.git
cd wazuh-rac/single-node
```

## Prepare the Linux host

Set `vm.max_map_count` before starting Wazuh. The Wazuh indexer needs a higher
virtual-memory map limit than the Linux default.

```bash
sudo sysctl -w vm.max_map_count=262144
```

If this value is lower than `262144`, the indexer may fail or behave
incorrectly. Make the setting persistent using the normal sysctl configuration
mechanism for the host operating system.

To run Docker as a non-root user, add that user to the `docker` group:

```bash
sudo usermod -aG docker <USER>
```

Replace `<USER>` with the account name, then log out and back in for the group
change to take effect.

## Create host-local files

Copy the example environment file to an ignored host-local file:

```bash
cp example.env .env.staging
```

Use another name where appropriate, such as `.env.production`.

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

Review both local files:

```bash
nano .env.staging
nano compose.staging.yml
```

Docker Compose merges files from left to right. The tracked
`docker-compose.yml` is the base file; the host-local file overrides only the
fields it defines.

Preview the effective configuration:

```bash
docker compose --env-file .env.staging -f docker-compose.yml -f compose.staging.yml config
```

## Prepare certificates

Create the certificate configuration:

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

Download the Wazuh 5.0.0-beta3 certificate tool:

```bash
curl -o wazuh-certs-tool.sh https://packages-staging.xdrsiem.wazuh.info/pre-release/5.x/installation-assistant/wazuh-certs-tool-5.0.0-beta3.sh
```

The downloaded tool is ignored by Git, so it does not block future pulls.

Generate and place the certificates:

```bash
bash ../tools/utils/deployment/certificates-conf.sh --cert --copy --priv
```

## Provision agent groups

Enrollment group directories are bind-mounted into the Manager at boot. The
tracked baseline currently contains:

```text
tracked-config/wazuh-manager/shared/windows/agent.conf
tracked-config/wazuh-manager/shared/linux/agent.conf
```

The files may remain empty until group-specific agent settings are required.
Because they are tracked, later changes reach every deployment through the
normal repository update procedure.

Wazuh validates an enrollment group by checking for its shared directory under
`/var/wazuh-manager/etc/shared/`. Enrollment is rejected as `Invalid group` if
that directory does not exist.

After startup, verify the available groups:

```bash
docker exec single-node-wazuh.manager \
  /var/wazuh-manager/bin/agent_groups -l
```

## Perform the first deployment

Start the stack with the stock reserved-user passwords:

```bash
docker compose --env-file .env.staging -f docker-compose.yml -f compose.staging.yml up -d
```

Keep the dashboard port restricted during bootstrap because the stock
credentials are still active.

Wait for the containers to become healthy:

```bash
docker compose --env-file .env.staging -f docker-compose.yml -f compose.staging.yml ps
```

The first startup can take a minute or two while the indexer and dashboard
initialize. Temporary dashboard connection errors for the indexer on port
`9200` are expected until the indexer is ready.

## Change reserved indexer passwords

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
  wazuh/wazuh-indexer:5.0.0-beta3 -p 'NewAdminPass1?'

docker run --rm -e OPENSEARCH_JAVA_HOME=/usr/share/wazuh-indexer/jdk \
  --entrypoint /usr/share/wazuh-indexer/plugins/opensearch-security/tools/hash.sh \
  wazuh/wazuh-indexer:5.0.0-beta3 -p 'NewKibanaServerPass1?'
```

Replace only the `hash:` values for the users being changed, normally `admin`
and `kibanaserver`:

```bash
nano config-local/opensearch-security/internal_users.yml
```

Copy the edited file into the running indexer:

```bash
docker cp config-local/opensearch-security/internal_users.yml \
  single-node-wazuh.indexer:/tmp/internal_users.yml
```

Apply it to the indexer security index:

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

Update the host-local environment file with the matching plaintext passwords:

```env
INDEXER_USERNAME=admin
INDEXER_PASSWORD='NewAdminPass1?'
DASHBOARD_USERNAME=kibanaserver
DASHBOARD_PASSWORD='NewKibanaServerPass1?'
```

Recreate the Manager and dashboard so they reconnect with the new credentials:

```bash
docker compose --env-file .env.staging -f docker-compose.yml -f compose.staging.yml up -d --force-recreate wazuh.manager wazuh.dashboard
```

Check health again:

```bash
docker compose --env-file .env.staging -f docker-compose.yml -f compose.staging.yml ps
```

If the dashboard returns `500 Internal Server Error`, clear the browser's site
data for the dashboard URL or test in a private window. A stale session from
the stock credentials can make login fail even when the new credentials are
correct.

## Access the dashboard

Open:

```text
https://<DOCKER_HOST_IP>
```

A browser warning is expected when self-signed certificates are used.

## Operational rules

- Do not commit real credentials.
- Keep host-specific changes in ignored files.
- Docker does not dynamically reload every component configuration. Recreate
  the affected container after changing its configuration or Compose override.
- Environment and override files keep secrets and host settings out of Git;
  they do not replace the Wazuh/OpenSearch password-rotation procedure.
- Verify the effective credentials before exposing the dashboard.
