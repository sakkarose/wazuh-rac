# Collect remote syslog on the Docker host

Wazuh 5 removes raw syslog input from the Manager's `remoted` service. The
supported architecture uses an external syslog receiver and a separate Wazuh
agent on the collection host.

Refer to [syslog-input-4x-to-5x.md](https://github.com/wazuh/wazuh/blob/v5.0.0-beta3/docs/guide/migration/syslog-input-4x-to-5x.md) for the upstream migration architecture,
the choice between journald and log-file collection, agent installation, and
the agent `<localfile>` configuration. Refer to `rules-4x-to-5x.md` when custom
decoding or rules are required.

This document records the additional decisions and operating details for this
repository's Debian single-node Docker host. It uses the upstream log-file
approach:

```text
IPFire instances
    -> UDP or TCP 514 on host rsyslog
    -> /var/log/remote/<sender-ip>.log
    -> Wazuh agent installed on the Debian host
    -> TCP 1514 to the Wazuh Manager container
    -> Wazuh Indexer and dashboard
```

## Keep host port 514 outside the Manager container

The tracked Manager service does not publish host UDP port 514. Keep this line
disabled in `single-node/docker-compose.yml` and in host-local overrides:

```yaml
# - "514:514/udp"
```

After changing the merged Compose configuration, recreate the Manager. A bare
`514/udp` entry in `docker ps` is image `EXPOSE` metadata and does not occupy
the host port. A published port would look like
`0.0.0.0:514->514/udp`.

Verify that nothing owns the host listener before configuring rsyslog:

```bash
ss -ulnp | grep ':514'
```

## Install and identify rsyslog

On Debian:

```bash
apt update
apt install rsyslog logrotate
systemctl enable --now rsyslog
```

The daemon executable is `rsyslogd`, not `rsyslog`:

```bash
rsyslogd -v
systemctl status rsyslog --no-pager
```

Some Debian packages run rsyslog as root and do not create a `syslog` account.
Check the actual service account instead of assuming it exists:

```bash
ps -o user,group,cmd -C rsyslogd
```

For the root-running service used by this deployment, create the destination
with ownership that also permits the root-running Wazuh agent to read it:

```bash
install -d -o root -g adm -m 0750 /var/log/remote
```

## Separate senders into files

Create `/etc/rsyslog.d/99-wazuh-remote.conf`:

```rsyslog
module(load="imudp")

template(
    name="RemoteHostLogs"
    type="string"
    string="/var/log/remote/%FROMHOST-IP%.log"
)

ruleset(name="remote_to_wazuh_files") {
    action(
        type="omfile"
        dynaFile="RemoteHostLogs"
        createDirs="on"
        fileCreateMode="0640"
        fileOwner="root"
        fileGroup="adm"
    )
}

input(
    type="imudp"
    port="514"
    ruleset="remote_to_wazuh_files"
)
```

If every sender supports reliable TCP syslog, also load `imtcp` and add a TCP
input to the same ruleset. Expose only the protocols actually used.

Validate and restart:

```bash
rsyslogd -N1
systemctl restart rsyslog
ss -ulnp | grep ':514'
```

Restrict port 514 at the host or network firewall to the expected IPFire source
addresses. UDP syslog is neither authenticated nor encrypted and source
addresses can be spoofed on networks where an attacker can reach the listener.

## Connect the host agent

Follow the agent installation and log-file collection procedure in
`syslog-input-4x-to-5x.md`. For this same-host deployment:

- Install the agent on Debian, not in the Manager container.
- Use `127.0.0.1` as the Manager address.
- Agent traffic reaches the published Manager TCP port 1514.
- Enrollment reaches the published Manager TCP port 1515.
- Monitor `/var/log/remote/*.log` using syslog format as described by the
  upstream guide.

The Manager container and the host agent are separate Wazuh components even
though they run on the same physical or virtual host.

## Rotate raw logs

Rsyslog writes files but does not rotate them, and the Wazuh agent only reads
them. Create `/etc/logrotate.d/wazuh-remote-syslog`:

```logrotate
/var/log/remote/*.log {
    daily
    rotate 14
    maxage 14
    maxsize 100M
    missingok
    notifempty
    compress
    delaycompress
    dateext
    create 0640 root adm
    sharedscripts

    postrotate
        /usr/bin/systemctl kill -s HUP rsyslog.service >/dev/null 2>&1 || true
    endscript
}
```

Validate the rule without rotating files:

```bash
logrotate --debug /etc/logrotate.d/wazuh-remote-syslog
```

`rotate 14` is a count limit. If size-based rotations occur more than once per
day, it can retain less than fourteen days. Size and retention values should be
adjusted after measuring the real IPFire event rate.

Raw-file retention and Wazuh Indexer retention are independent. Deleting a raw
file does not delete an indexed event, and deleting an index does not remove the
raw file. Apply index retention only to the intended event and findings index
patterns, not broadly to every `wazuh-*` index.

## Keep multiple IPFire instances distinct

`%FROMHOST-IP%` creates a separate file for each directly connected sender:

```text
/var/log/remote/10.1.0.1.log
/var/log/remote/10.2.0.1.log
/var/log/remote/10.3.0.1.log
```

All events still share the identity of the Debian Wazuh agent. Do not use the
agent name to distinguish the firewalls. In Wazuh 5, use
`wazuh.protocol.location`, which contains the monitored file path, as the first
dashboard filter or aggregation field.

A custom IPFire integration should eventually map the device identity to:

```text
observer.ip
observer.name
observer.vendor
observer.product
observer.type
```

The repository's Wazuh 5 integration and manual installation procedure are in
[IPFire Netfilter integration](ipfire-netfilter-integration.md).
Its operational dashboard procedure is in
[IPFire Netfilter dashboard](ipfire-netfilter-dashboard.md).

Keep `source.ip` and `destination.ip` for the endpoints described by the
firewall event. Do not use `source.ip` as the identity of the firewall itself.

The per-source-IP layout requires each firewall to reach rsyslog with a unique
source address. Multiple devices behind the same NAT or an intermediate syslog
relay appear under one `%FROMHOST-IP%` file unless the receiver uses another
trusted device identifier.

## Verify the pipeline

Send a test from another host:

```bash
logger -n <WAZUH_HOST_IP> -P 514 --udp "IPFire syslog pipeline test"
```

On the collection host, verify each stage:

```bash
find /var/log/remote -maxdepth 1 -type f -ls
tail -f /var/log/remote/*.log
grep -i remote /var/ossec/logs/ossec.log
```

In the dashboard, inspect `wazuh-events-v5-*`. Events that contain only
`event.original` or land in an unclassified event index need additional
decoding before fields such as firewall action, source address, destination
address, port, and protocol can drive useful visualizations.
