#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_SRC="$SCRIPT_DIR/wg-ddns-monitor.sh"
SERVICE_SRC="$SCRIPT_DIR/wg-ddns-monitor.service"
TIMER_SRC="$SCRIPT_DIR/wg-ddns-monitor.timer"

SCRIPT_DEST="/usr/local/bin/wg-ddns-monitor.sh"
CONFIG_DEST="/etc/wg-ddns-monitor.conf"
CRON_DEST="/etc/cron.d/wg-ddns-monitor"
SERVICE_DEST="/etc/systemd/system/wg-ddns-monitor.service"
TIMER_DEST="/etc/systemd/system/wg-ddns-monitor.timer"

WG_INTERFACE="wg0"
DDNS_HOST="change.me.ddns.net"
RESOLVER="1.1.1.1"
LOG_LEVEL="ALL"
SCHEDULER="cron"
CHECK_INTERVAL=2
UNINSTALL=0

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Install or uninstall WireGuard DDNS Monitor.

Options:
  -i, --interface NAME   WireGuard interface (default: wg0)
  -h, --host HOST        DDNS hostname to monitor (default: change.me.ddns.net)
  -r, --resolver IP      DNS resolver (default: 1.1.1.1)
  -l, --log-level LVL    Log level: ALL or ERROR (default: ALL)
  -s, --scheduler TYPE   Scheduler: cron or systemd (default: cron)
  -t, --interval MIN     Check interval in minutes (default: 2)
  -u, --uninstall        Remove all installed files
  --help                 Show this help

Examples:
  sudo $0                                          # interactive
  sudo $0 -i wg1 -h home.ddns.net -s systemd -t 5 # automated
  sudo $0 -u                                        # uninstall
EOF
    exit 0
}

INTERACTIVE=true
while [[ $# -gt 0 ]]; do
    case "$1" in
        --interface|-i)
            [ -z "$2" ] && { error "Missing value for $1"; exit 1; }
            WG_INTERFACE="$2"; INTERACTIVE=false; shift 2 ;;
        --host|-h)
            [ -z "$2" ] && { error "Missing value for $1"; exit 1; }
            DDNS_HOST="$2"; INTERACTIVE=false; shift 2 ;;
        --resolver|-r)
            [ -z "$2" ] && { error "Missing value for $1"; exit 1; }
            RESOLVER="$2"; INTERACTIVE=false; shift 2 ;;
        --log-level|-l)
            [ -z "$2" ] && { error "Missing value for $1"; exit 1; }
            LOG_LEVEL="$2"; INTERACTIVE=false; shift 2 ;;
        --scheduler|-s)
            [ -z "$2" ] && { error "Missing value for $1"; exit 1; }
            SCHEDULER="$2"; INTERACTIVE=false; shift 2 ;;
        --interval|-t)
            [ -z "$2" ] && { error "Missing value for $1"; exit 1; }
            CHECK_INTERVAL="$2"; INTERACTIVE=false; shift 2 ;;
        --uninstall|-u) UNINSTALL=1; INTERACTIVE=false; shift ;;
        --help) usage ;;
        *) error "Unknown option: $1"; usage ;;
    esac
done

if [ "$EUID" -ne 0 ]; then
    error "Must run as root."
    exit 1
fi

if ! [[ "$CHECK_INTERVAL" =~ ^[1-9][0-9]*$ ]]; then
    error "Interval must be a positive integer (minutes)."
    exit 1
fi

case "$SCHEDULER" in cron|systemd) ;; *) error "Scheduler must be 'cron' or 'systemd'."; exit 1 ;; esac
case "$LOG_LEVEL" in ALL|ERROR) ;; *) error "Log level must be 'ALL' or 'ERROR'."; exit 1 ;; esac

# ---- Uninstall ----
if [ "$UNINSTALL" -eq 1 ]; then
    echo "=== Uninstalling WireGuard DDNS Monitor ==="

    if command -v systemctl &>/dev/null; then
        systemctl stop wg-ddns-monitor.timer 2>/dev/null && info "Stopped systemd timer." || true
        systemctl disable wg-ddns-monitor.timer 2>/dev/null && info "Disabled systemd timer." || true
    fi

    rm -f "$SCRIPT_DEST"  && info "Removed $SCRIPT_DEST"
    rm -f "$CONFIG_DEST"  && info "Removed $CONFIG_DEST"
    rm -f "$CRON_DEST"    && info "Removed $CRON_DEST"
    rm -f "$SERVICE_DEST" && info "Removed $SERVICE_DEST"
    rm -f "$TIMER_DEST"   && info "Removed $TIMER_DEST"

    systemctl daemon-reload 2>/dev/null || true

    echo ""
    info "Uninstall complete."
    exit 0
fi

# ---- Interactive mode ----
if [ "$INTERACTIVE" = true ]; then
    echo "=== WireGuard DDNS Monitor Installer ==="
    echo ""

    read -r -p "WireGuard interface [$WG_INTERFACE]: " input
    WG_INTERFACE="${input:-$WG_INTERFACE}"

    read -r -p "DDNS hostname to monitor [$DDNS_HOST]: " input
    DDNS_HOST="${input:-$DDNS_HOST}"

    read -r -p "DNS resolver [$RESOLVER]: " input
    RESOLVER="${input:-$RESOLVER}"

    while true; do
        read -r -p "Log level (ALL or ERROR) [$LOG_LEVEL]: " input
        LOG_LEVEL="${input:-$LOG_LEVEL}"
        [[ "$LOG_LEVEL" == "ALL" || "$LOG_LEVEL" == "ERROR" ]] && break
    done

    while true; do
        read -r -p "Check interval in minutes [$CHECK_INTERVAL]: " input
        CHECK_INTERVAL="${input:-$CHECK_INTERVAL}"
        [[ "$CHECK_INTERVAL" =~ ^[1-9][0-9]*$ ]] && break
    done

    echo ""
    echo "Select scheduler:"
    echo "  1) Cron        (simpler, always active)"
    echo "  2) Systemd     (standard service, better integration)"
    read -r -p "Choice [1]: " sched_choice
    [ "$sched_choice" = "2" ] && SCHEDULER="systemd"

    echo ""
    echo "=== Configuration summary ==="
    echo "  Interface:     $WG_INTERFACE"
    echo "  DDNS host:     $DDNS_HOST"
    echo "  DNS resolver:  $RESOLVER"
    echo "  Log level:     $LOG_LEVEL"
    echo "  Check every:   $CHECK_INTERVAL min(s)"
    echo "  Scheduler:     $SCHEDULER"
    echo ""
    read -r -p "Proceed with installation? [Y/n]: " confirm
    confirm="${confirm:-Y}"
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi
fi

# ---- Pre-flight checks ----
if [ ! -f "$SCRIPT_SRC" ]; then
    error "Required file not found: $SCRIPT_SRC"
    exit 1
fi

MISSING_PKGS=()
command -v dig &>/dev/null      || MISSING_PKGS+=("dnsutils")
command -v wg &>/dev/null       || MISSING_PKGS+=("wireguard-tools")
command -v systemctl &>/dev/null || warn "systemd (systemctl) is required but must be part of the OS."

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    echo ""
    warn "Missing packages: ${MISSING_PKGS[*]}"
    echo ""
    echo "Please install them and re-run this installer:"
    echo ""
    echo "  sudo apt-get update && sudo apt-get install -y ${MISSING_PKGS[*]}"
    echo ""
    exit 1
fi

# ---- Install ----
echo ""
echo "=== Installing WireGuard DDNS Monitor ==="

cp "$SCRIPT_SRC" "$SCRIPT_DEST" || { error "Failed to copy script to $SCRIPT_DEST"; exit 1; }
chmod +x "$SCRIPT_DEST" || { error "Failed to make script executable"; exit 1; }
info "Installed $SCRIPT_DEST"

cat > "$CONFIG_DEST" <<EOF
# WireGuard DDNS Monitor configuration
# This file is sourced by the monitoring script.
# Values set here override the defaults in the script.

WG_INTERFACE="$WG_INTERFACE"
DDNS_HOST="$DDNS_HOST"
LOG_FILE="/var/log/wireguard-ddns-monitor.log"
LOCK_FILE="/var/run/wireguard-ddns-monitor.lock"
RESOLVER="$RESOLVER"
LOG_LEVEL="$LOG_LEVEL"
EOF
info "Created $CONFIG_DEST"

if [ "$SCHEDULER" = "cron" ]; then
    cat > "$CRON_DEST" <<EOF
# WireGuard DDNS Monitor - checks every ${CHECK_INTERVAL} minute(s)
*/${CHECK_INTERVAL} * * * * root ${SCRIPT_DEST}
EOF
    info "Created $CRON_DEST (every ${CHECK_INTERVAL} minute(s))"

elif [ "$SCHEDULER" = "systemd" ]; then
    if [ ! -f "$SERVICE_SRC" ] || [ ! -f "$TIMER_SRC" ]; then
        error "Required systemd unit files not found in $SCRIPT_DIR"
        exit 1
    fi

    cp "$SERVICE_SRC" "$SERVICE_DEST"
    info "Installed $SERVICE_DEST"

    cat > "$TIMER_DEST" <<EOF
[Unit]
Description=WireGuard DDNS Monitor Timer
Requires=wg-ddns-monitor.service

[Timer]
OnBootSec=1min
OnUnitActiveSec=${CHECK_INTERVAL}min

[Install]
WantedBy=timers.target
EOF
    info "Created $TIMER_DEST (every ${CHECK_INTERVAL} minute(s))"

    if ! systemctl daemon-reload; then
        error "systemctl daemon-reload failed"
        exit 1
    fi
    systemctl enable wg-ddns-monitor.timer || { error "Failed to enable timer"; exit 1; }
    systemctl start wg-ddns-monitor.timer || { error "Failed to start timer"; exit 1; }
    info "Systemd timer enabled and started."
fi

# ---- Done ----
echo ""
info "Installation complete!"
echo ""
echo "The script will check if $DDNS_HOST resolves to a new IP every $CHECK_INTERVAL minute(s)"
echo "and restart $WG_INTERFACE if needed."
echo ""
echo "Logs: /var/log/wireguard-ddns-monitor.log"

if [ "$SCHEDULER" = "cron" ]; then
    echo "To verify: ls -la $CRON_DEST"
else
    echo "To verify: systemctl status wg-ddns-monitor.timer"
    echo "           systemctl list-timers --all | grep wg-ddns"
fi
