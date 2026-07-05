# WireGuard DDNS Monitor

[Read in English](README.md)

Este script monitoriza un dominio DNS Dinámico (DDNS) y reinicia la interfaz de WireGuard si la dirección IP resuelta cambia y no coincide con el endpoint del peer actual. Esto permite mantener activos los túneles de WireGuard cuando un peer tiene una dirección IP dinámica.

## Requisitos previos

- Sistema basado en Linux (se recomienda Debian/Ubuntu).
- Se requieren privilegios de root para gestionar el servicio de WireGuard y escribir logs.
- `dnsutils` (específicamente `dig`) debe estar instalado.
- WireGuard debe estar instalado y configurado.

## Instalación

### Instalación rápida

**Instalar (interactivo):**

```bash
cd /tmp && git clone https://github.com/Torrenava/wg-ddns-monitor && \
  cd wg-ddns-monitor && sudo ./install.sh
```

**Desinstalar:**

```bash
cd /tmp && git clone https://github.com/Torrenava/wg-ddns-monitor && \
  cd wg-ddns-monitor && sudo ./install.sh --uninstall
```

**Instalar (automatizado):**

```bash
cd /tmp && git clone https://github.com/Torrenava/wg-ddns-monitor && \
  cd wg-ddns-monitor && sudo ./install.sh -i wg0 -h micasa.ddns.net -s systemd -t 5
```

---

### 1. Instalar dependencias

```bash
sudo apt install dnsutils wireguard-tools
```

### 2. Clonar y ejecutar el instalador

```bash
git clone https://github.com/Torrenava/wg-ddns-monitor
cd wg-ddns-monitor
sudo ./install.sh
```

El instalador te guiará por los siguientes pasos:
- Configurar la interfaz WireGuard y el host DDNS
- Elegir un resolver DNS y nivel de log
- Seleccionar el intervalo de comprobación (en minutos)
- Elegir entre **cron** y **systemd timer** como planificador

También puedes ejecutarlo de forma no interactiva con flags:

```bash
sudo ./install.sh \
    -i wg0 \
    -h micasa.ddns.net \
    -s systemd \
    -t 5
```

### Instalación manual (alternativa)

Si prefieres instalar manualmente:

```bash
sudo cp wg-ddns-monitor.sh /usr/local/bin/wg-ddns-monitor.sh
sudo chmod +x /usr/local/bin/wg-ddns-monitor.sh

# Crear archivo de configuración
sudo tee /etc/wg-ddns-monitor.conf > /dev/null <<EOF
WG_INTERFACE="wg0"
DDNS_HOST="micasa.ddns.net"
LOG_FILE="/var/log/wireguard-ddns-monitor.log"
LOCK_FILE="/var/run/wireguard-ddns-monitor.lock"
RESOLVER="1.1.1.1"
LOG_LEVEL="ALL"
EOF

# Opción A: Cron
sudo tee /etc/cron.d/wg-ddns-monitor > /dev/null <<EOF
*/2 * * * * root /usr/local/bin/wg-ddns-monitor.sh
EOF

# Opción B: Systemd timer
sudo cp wg-ddns-monitor.service /etc/systemd/system/
sudo cp wg-ddns-monitor.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now wg-ddns-monitor.timer
```

### Desinstalar

```bash
sudo ./install.sh --uninstall
```

## Uso

El script realiza los siguientes pasos:
1. Resuelve la dirección IP del host DDNS configurado (`DDNS_HOST`).
2. Comprueba si la IP resuelta coincide con el endpoint actual de la interfaz WireGuard (`WG_INTERFACE`).
3. Si la IP ha cambiado (no coincide), reinicia la interfaz WireGuard usando `systemctl`.
4. Registra todas las acciones y errores en `/var/log/wireguard-ddns-monitor.log`.

## Configuración

Edita `/etc/wg-ddns-monitor.conf` tras la instalación para cambiar los ajustes:

| Variable | Por defecto | Descripción |
|---|---|---|
| `WG_INTERFACE` | `wg0` | Interfaz WireGuard a monitorizar |
| `DDNS_HOST` | `change.me.ddns.net` | Host DDNS a resolver |
| `LOG_FILE` | `/var/log/wireguard-ddns-monitor.log` | Ruta del archivo de log |
| `LOCK_FILE` | `/var/run/wireguard-ddns-monitor.lock` | Ruta del archivo de lock |
| `RESOLVER` | `1.1.1.1` | Servidor DNS para resolución |
| `LOG_LEVEL` | `ALL` | `ALL` o `ERROR` |

## Logging

Los registros se escriben en `/var/log/wireguard-ddns-monitor.log` con marcas de tiempo.

Ejemplo de entrada de registro:
```
05-02-2026 21:48:58 [INFO] - Endpoint mismatch. Restarting WireGuard...
```
