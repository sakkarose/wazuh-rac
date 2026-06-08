# This repository docs

This repository is intended to be cloned directly on each deployed host. The
tracked files keep the stock Wazuh Docker deployment, while host-specific
credentials stay in ignored local files.

## File Model

- `single-node/docker-compose.yml` is the tracked base Compose file.
- `single-node/example.env` is a tracked template with placeholder values.
- `single-node/example.compose.yml` is a tracked Compose override template.
- `single-node/.env` and `single-node/.env.*` files are ignored and should
  contain real host secrets.
- `single-node/compose.*.yml` files are ignored and should contain host-specific
  Compose overrides.

You do not need to commit a staging or production Compose file. Create those
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

## Create Host Secrets

Copy the example env file to a local ignored file:

```bash
cp example.env .env.staging
```

Edit `.env.staging` and replace every placeholder value:

```bash
nano .env.staging
```

Use a different local file name on another host if helpful, such as
`.env.production`.

## Create a Local Compose Override

Copy the example Compose override to a local ignored file:

```bash
cp example.compose.yml compose.staging.yml
```

Review and adjust it for the host:

```bash
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

## Deploy

Start the stack in the background:

```bash
docker compose --env-file .env.staging -f docker-compose.yml -f compose.staging.yml up -d
```

Access the dashboard:

```text
https://<DOCKER_HOST_IP>
```

If you use self-signed certificates, the browser will warn that it cannot verify
the certificate.

The first startup can take a minute or two while the Wazuh indexer and dashboard
initialize. It is normal to see temporary dashboard logs saying it cannot connect
to the Wazuh indexer on port `9200` until the indexer is ready.

## Update This Host

When new tracked configuration is pushed to this repository:

```bash
git pull
cd single-node
docker compose --env-file .env.staging -f docker-compose.yml -f compose.staging.yml config
docker compose --env-file .env.staging -f docker-compose.yml -f compose.staging.yml pull
docker compose --env-file .env.staging -f docker-compose.yml -f compose.staging.yml up -d
```

Your local `.env*` and `compose.*.yml` files are ignored by git, so they will not be overwritten by repository updates.

## Notes

- Do not commit real credentials.
- Keep host-specific changes in ignored files.
- Keep the tracked `docker-compose.yml` generic so future config updates can be
  pulled cleanly.
- Docker does not dynamically reload component configuration. After changing a
  component configuration or override, recreate the stack with `docker compose
  up -d`.
- The env and override files keep host-specific values out of git. They do not
  replace Wazuh/OpenSearch password-rotation procedures. Some default users may
  require security index or internal user changes beyond Compose environment
  variables. Always verify the effective credentials before exposing the
  dashboard.
