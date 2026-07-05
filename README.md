# WireGuard DDNS Monitor

[Leer en Español](README_ES.md)

This script monitors a Dynamic DNS (DDNS) domain and restarts the WireGuard interface if the resolved IP address changes and does not match the current peer endpoint. This allows keeping WireGuard tunnels active when one peer has a dynamic IP address.

## Prerequisites

- Linux-based system (Debian/Ubuntu recommended).
- Root privileges are required to manage the WireGuard service and write logs.
- `dnsutils` (specifically `dig`) must be installed.
- WireGuard must be installed and configured.

## Installation

### Quick Install

**Install (interactive):**

```bash
cd /tmp && git clone https://github.com/Torrenava/wg-ddns-monitor && \
  cd wg-ddns-monitor && sudo ./install.sh
```

**Uninstall:**

```bash
cd /tmp && git clone https://github.com/Torrenava/wg-ddns-monitor && \
  cd wg-ddns-monitor && sudo ./install.sh --uninstall
```

**Install (automated):**

```bash
cd /tmp && git clone https://github.com/Torrenava/wg-ddns-monitor && \
  cd wg-ddns-monitor && sudo ./install.sh -i wg0 -h myhome.ddns.net -s systemd -t 5
```

---

### 1. Install dependencies

```bash
sudo apt install dnsutils wireguard-tools
```

### 2. Clone and run the installer

```bash
git clone https://github.com/Torrenava/wg-ddns-monitor
cd wg-ddns-monitor
sudo ./install.sh
```

The installer will guide you through:
- Setting the WireGuard interface name and DDNS hostname
- Choosing a DNS resolver and log level
- Selecting the check interval (in minutes)
- Choosing between **cron** and **systemd timer** as the scheduler

You can also run it non-interactively with flags:

```bash
sudo ./install.sh \
    -i wg0 \
    -h myhome.ddns.net \
    -s systemd \
    -t 5
```

### Manual installation (alternative)

If you prefer to install manually:

```bash
sudo cp wg-ddns-monitor.sh /usr/local/bin/wg-ddns-monitor.sh
sudo chmod +x /usr/local/bin/wg-ddns-monitor.sh

# Create config file
sudo tee /etc/wg-ddns-monitor.conf > /dev/null <<EOF
WG_INTERFACE="wg0"
DDNS_HOST="myhome.ddns.net"
LOG_FILE="/var/log/wireguard-ddns-monitor.log"
LOCK_FILE="/var/run/wireguard-ddns-monitor.lock"
RESOLVER="1.1.1.1"
LOG_LEVEL="ALL"
EOF

# Option A: Cron
sudo tee /etc/cron.d/wg-ddns-monitor > /dev/null <<EOF
*/2 * * * * root /usr/local/bin/wg-ddns-monitor.sh
EOF

# Option B: Systemd timer
sudo cp wg-ddns-monitor.service /etc/systemd/system/
sudo cp wg-ddns-monitor.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now wg-ddns-monitor.timer
```

### Uninstall

```bash
sudo ./install.sh --uninstall
```

## Usage

The script performs the following steps:
1. Resolves the IP address of the configured DDNS host (`DDNS_HOST`).
2. Checks if the resolved IP matches the current endpoint of the WireGuard interface (`WG_INTERFACE`).
3. If the IP has changed (does not match), it restarts the WireGuard interface using `systemctl`.
4. Logs all actions and errors to `/var/log/wireguard-ddns-monitor.log`.

## Configuration

Edit `/etc/wg-ddns-monitor.conf` after installation to change settings:

| Variable | Default | Description |
|---|---|---|
| `WG_INTERFACE` | `wg0` | WireGuard interface to monitor |
| `DDNS_HOST` | `change.me.ddns.net` | DDNS hostname to resolve |
| `LOG_FILE` | `/var/log/wireguard-ddns-monitor.log` | Log file path |
| `LOCK_FILE` | `/var/run/wireguard-ddns-monitor.lock` | Lock file path |
| `RESOLVER` | `1.1.1.1` | DNS server for resolution |
| `LOG_LEVEL` | `ALL` | `ALL` or `ERROR` |

## Logging

Logs are written to `/var/log/wireguard-ddns-monitor.log` with timestamps.

Example log entry:
```
05-02-2026 21:48:58 [INFO] - Endpoint mismatch. Restarting WireGuard...
```
