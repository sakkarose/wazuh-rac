# Set up a Wazuh Docker host

This guide deploys this repository's Wazuh 5.0.0-rc1 single-node stack on a
Linux host. RC1 has no default deployment passwords and the Manager no longer
creates its agent-listener certificate at startup. Certificates and credential
files must therefore exist before the first `docker compose up`.

## Prepare the host

```bash
git clone https://github.com/sakkarose/wazuh-rac.git
cd wazuh-rac/single-node
sudo sysctl -w vm.max_map_count=262144
cp example.env .env.staging
cp example.compose.yml compose.staging.yml
```

Make `vm.max_map_count=262144` persistent using the host's normal sysctl
configuration. The environment example intentionally contains no passwords;
RC1 supplies credentials as Compose secrets.

## Create certificates

Download the RC1-compatible certificate tool and credentials library:

```bash
curl --fail --show-error --location -o wazuh-certs-tool.sh \
  https://packages.wazuh.com/5.0/wazuh-certs-tool-5.0.0-1.sh
curl --fail --show-error --location -o wazuh-credentials.sh \
  https://packages.wazuh.com/5.0/wazuh-credentials-5.0.0-1.sh
```

Create the ignored `config.yml`. Every address that an agent uses to reach
port 1517 must be a Subject Alternative Name of the Manager certificate:

```yaml
nodes:
  indexer:
    - name: wazuh.indexer
      dns: "wazuh.indexer"

  manager:
    - name: wazuh.manager
      ip:
        - "<DOCKER_HOST_ADDRESS>"
        - "127.0.0.1"
      dns:
        - "wazuh.manager"
        - "<DOCKER_HOST_DNS_NAME>"

  dashboard:
    - name: wazuh.dashboard
      dns: "wazuh.dashboard"
```

Generate and place all certificates:

```bash
sudo bash ../tools/utils/deployment/certificates-conf.sh --cert --copy --priv
```

This must produce both
`config/wazuh_manager/certs/wazuh.manager-remoted.pem` and its key. RC1 mounts
them as `etc/certs/remoted.pem` and `remoted-key.pem`; the Manager fails closed
if either is absent. Additional agent-facing names can be issued with repeated
`--agent-san <address>` options. The loopback SAN above is required by this
repository's same-host syslog collector procedure.

## Create deployment credentials

```bash
sudo bash ../tools/utils/deployment/credentials-conf.sh
```

The script creates permission-restricted, ignored files:

```text
config/credentials/indexer.env
config/credentials/manager.env
config/credentials/dashboard.env
```

Each container receives only its own file as the `wazuh-credentials` Compose
secret. Keep these files and back them up securely. Do not rerun the script
with `--force` after a deployment has started: changing the files does not
change credentials already stored in component volumes.

For an existing deployment, the values in these files must match the stored
passwords. The required keys and consumers are:

| Key | Credential files |
| --- | --- |
| `WAZUH_INDEXER_ADMIN_PASSWORD` | `indexer.env` |
| `WAZUH_INDEXER_KIBANASERVER_PASSWORD` | `indexer.env`, `dashboard.env` |
| `WAZUH_INDEXER_MANAGER_PASSWORD` | `indexer.env`, `manager.env` |
| `WAZUH_MANAGER_API_PASSWORD` | `manager.env` |
| `WAZUH_MANAGER_WUI_PASSWORD` | `manager.env`, `dashboard.env` |

## Start and verify

Validate the merged Compose model, then start it:

```bash
docker compose --env-file .env.staging \
  -f docker-compose.yml -f compose.staging.yml config --quiet
docker compose --env-file .env.staging \
  -f docker-compose.yml -f compose.staging.yml up -d
docker compose --env-file .env.staging \
  -f docker-compose.yml -f compose.staging.yml ps
```

Log in at `https://<DOCKER_HOST_ADDRESS>` as `admin`. Read the generated
password without copying it into a tracked file:

```bash
grep '^WAZUH_INDEXER_ADMIN_PASSWORD=' \
  config/credentials/indexer.env | cut -d= -f2-
```

Use the RC1 `/password-tool.sh` inside the Indexer or Manager to rotate a
password after first startup; follow the commands it prints to update every
consumer. Editing `config/credentials/*.env` alone has no effect after the
credential has been persisted.

## Provision agent groups

The host-local Compose override mounts the tracked group configuration into
the Manager. It currently provides `windows`, `linux`, and `syslog`; the latter
monitors `/var/log/remote/*.log`.

```bash
docker exec single-node-wazuh.manager \
  /var/wazuh-manager/bin/agent_groups -l
```

Enrollment into a group that is not listed is rejected. Recreate the Manager
after changing tracked group configuration.

## Network exposure

The repository deliberately differs from upstream RC1 here:

```text
127.0.0.1:9200  -> Indexer API
127.0.0.1:55000 -> Manager API
1517/tcp        -> Wazuh 5 agent traffic and token enrollment
1514/tcp        -> legacy agent traffic during migration
1515/tcp        -> legacy enrollment during migration
443/tcp         -> dashboard
514             -> host rsyslog, not the Manager container
```

Verify the effective bindings after every deployment. `9200` and `55000` must
not be exposed on `0.0.0.0` or `[::]`:

```bash
docker compose --env-file .env.staging \
  -f docker-compose.yml -f compose.staging.yml ps
ss -lntp | grep -E ':(443|1514|1515|1517|9200|55000)\b'
```

Do not use `docker compose down -v` during routine operations. It deletes the
volumes containing indexed data, API users, keystores, Manager state, and the
RC1 detection-content store.
