#!/bin/bash

# Configuration
WG_INTERFACE="wg0"
DDNS_HOST="change.me.ddns.net"
LOG_FILE="/var/log/wireguard-ddns-monitor.log"
LOCK_FILE="/var/run/wireguard-ddns-monitor.lock"
RESOLVER="1.1.1.1" # DNS server used to resolve DDNS_HOST.
LOG_LEVEL="ALL"    # "ALL" (info + errors) or "ERROR" (errors only)

# Log function
log() {
    local level=$1
    local message=$2
    
    if [ "$LOG_LEVEL" = "ERROR" ] && [ "$level" = "INFO" ]; then
        return
    fi
    
    echo "$(date '+%d-%m-%Y %H:%M:%S') [$level] - $message" >> "$LOG_FILE"
}

# Require root
if [ "$EUID" -ne 0 ]; then 
    echo "Error: Must run as root."
    exit 1
fi

# Check dependencies
for cmd in dig wg systemctl; do
    if ! command -v $cmd &> /dev/null; then
        log "ERROR" "Missing command: $cmd"
        exit 1
    fi
done

# Prevent multiple instances
if [ -f "$LOCK_FILE" ]; then
    if kill -0 $(cat "$LOCK_FILE" 2>/dev/null) 2>/dev/null; then
        exit 0
    else
        rm -f "$LOCK_FILE"
    fi
fi

echo $$ > "$LOCK_FILE"
trap "rm -f $LOCK_FILE" EXIT

# Resolve IP using external DNS
current_ip=$(dig @"$RESOLVER" +short "$DDNS_HOST" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | tail -n1)

if [ -z "$current_ip" ]; then
    log "ERROR" "Could not resolve $DDNS_HOST via $RESOLVER"
    exit 1
fi

# Verify endpoint and restart if needed
if ! wg show "$WG_INTERFACE" endpoints | grep -q "$current_ip"; then
    log "INFO" "Endpoint mismatch. Restarting WireGuard..."
    if systemctl restart wg-quick@"$WG_INTERFACE"; then
        log "INFO" "WireGuard restarted successfully."
    else
        log "ERROR" "Failed to restart WireGuard."
    fi
else
    log "INFO" "Endpoint matches $current_ip. No action needed."
fi
