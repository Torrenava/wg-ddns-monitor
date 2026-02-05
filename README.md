# WireGuard DDNS Monitor

[Leer en Español](README_ES.md)

This script monitors a Dynamic DNS (DDNS) domain and restarts the WireGuard interface if the resolved IP address changes and does not match the current peer endpoint. This allows keeping WireGuard tunnels active when one peer has a dynamic IP address.

## Prerequisites

-   Use a Linux-based system (Debian/Ubuntu recommended).
-   Root privileges are required to manage the WireGuard service and write logs.
-   `dnsutils` (specifically `dig`) must be installed.
-   WireGuard must be installed and configured.

## Installation

1.  **Install dependencies**:
    If `dig` is not already installed, install the `dnsutils` package:

    ```bash
    sudo apt install dnsutils
    ```

2.  **Clone the repository and configure the script**:
    ```bash
    git clone https://github.com/Torrenava/wg-ddns-monitor
    nano wg-ddns-monitor/wg-ddns-monitor.sh
    ```
    Make sure to configure the `WG_INTERFACE` and `DDNS_HOST` variables with the corresponding values.

3.  **Set executable permissions**:
    ```bash
    sudo cp wg-ddns-monitor/wg-ddns-monitor.sh /usr/local/bin/wg-ddns-monitor.sh
    sudo chmod +x /usr/local/bin/wg-ddns-monitor.sh
    ```

4.  **Configure Cron Job**:
    Set up a cron job to run the script every 2 minutes:

    ```bash
    echo "*/2 * * * * /usr/local/bin/wg-ddns-monitor.sh" | sudo crontab -
    ```

## Usage

The script performs the following steps:
1.  Resolves the IP address of the configured DDNS host (`DDNS_HOST`).
2.  Checks if the resolved IP matches the current endpoint of the WireGuard interface (`WG_INTERFACE`).
3.  If the IP has changed (does not match), it restarts the WireGuard interface using `systemctl`.
4.  Logs all actions and errors to `/var/log/wireguard-ddns-monitor.log`.

## Logging

Logs are written to `/var/log/wireguard-ddns-monitor.log` with timestamps.

Example log entry:
```
05-02-2026 21:48:58 - IP 203.0.113.1 not found in peer endpoints, restarting WireGuard...
```
