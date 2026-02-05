#!/bin/bash

# Configuration
WG_INTERFACE="wg0"
DDNS_HOST="change.me.ddns.net"
LOG_FILE="/var/log/wireguard-ddns-monitor.log"
LOCK_FILE="/var/run/wireguard-ddns-monitor.lock"

# Function to log with timestamp
log() {
    echo "$(date '+%d-%m-%Y %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Check for root privileges
if [ "$EUID" -ne 0 ]; then 
    echo "Error: This script must be run as root."
    exit 1
fi

# Check dependencies
for cmd in dig wg systemctl; do
    if ! command -v $cmd &> /dev/null; then
        log "ERROR: Required command '$cmd' not found."
        exit 1
    fi
done

# Prevent multiple instances
if [ -f "$LOCK_FILE" ]; then
    # Check if process is actually running
    if kill -0 $(cat "$LOCK_FILE" 2>/dev/null) 2>/dev/null; then
        exit 0
    else
        # Stale lock file
        rm -f "$LOCK_FILE"
    fi
fi

echo $$ > "$LOCK_FILE"
trap "rm -f $LOCK_FILE" EXIT

# Get current DNS resolution
current_ip=$(dig +short "$DDNS_HOST" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | tail -n1)

if [ -z "$current_ip" ]; then
    log "ERROR: Could not resolve $DDNS_HOST"
    exit 1
fi

# Check if any peer has this IP as endpoint
if ! wg show "$WG_INTERFACE" endpoints | grep -q "$current_ip"; then
    log "IP $current_ip not found in peer endpoints, restarting WireGuard..."
    systemctl restart wg-quick@"$WG_INTERFACE"
    if [ $? -eq 0 ]; then
        log "WireGuard restarted successfully"
    else
        log "ERROR: Failed to restart WireGuard"
    fi
else
    log "IP $current_ip matches current peer endpoint, no restart needed"
fi
