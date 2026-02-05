# WireGuard DDNS Monitor

[Read in English](README.md)

Este script monitoriza un dominio DNS Dinámico (DDNS) y reinicia la interfaz de WireGuard si la dirección IP resuelta cambia y no coincide con el endpoint del peer actual. Esto permite mantener activos los túneles de WireGuard cuando un peer tiene una dirección IP dinámica.

## Requisitos previos

-   Utilizar un sistema basado en Linux (se recomienda Debian/Ubuntu).
-   Se requieren privilegios de root para gestionar el servicio de WireGuard y escribir logs.
-   `dnsutils` (específicamente `dig`) debe estar instalado.
-   WireGuard debe estar instalado y configurado.

## Instalación

1.  **Instalar dependencias**:
    Si `dig` no está instalado, instala el paquete `dnsutils`:

    ```bash
    sudo apt install dnsutils
    ```

2.  **Clonar el repositorio y configurar el script**:
    ```bash
    git clone https://github.com/Torrenava/wg-ddns-monitor
    nano wg-ddns-monitor/wg-ddns-monitor.sh
    ```
    Asegúrate de configurar las variables `WG_INTERFACE` y `DDNS_HOST` con los valores correspondientes.

3.  **Configurar permisos de ejecución**:
    ```bash
    sudo cp wg-ddns-monitor/wg-ddns-monitor.sh /usr/local/bin/wg-ddns-monitor.sh
    sudo chmod +x /usr/local/bin/wg-ddns-monitor.sh
    ```

4.  **Configurar tarea Cron**:
    Configura una tarea cron para ejecutar el script cada 2 minutos:

    ```bash
    echo "*/2 * * * * /usr/local/bin/wg-ddns-monitor.sh" | sudo crontab -
    ```

## Uso

El script realiza los siguientes pasos:
1.  Resuelve la dirección IP del host DDNS configurado (`DDNS_HOST`).
2.  Comprueba si la IP resuelta coincide con el endpoint actual de la interfaz WireGuard (`WG_INTERFACE`).
3.  Si la IP ha cambiado (no coincide), reinicia la interfaz WireGuard usando `systemctl`.
4.  Registra todas las acciones y errores en `/var/log/wireguard-ddns-monitor.log`.

## Logging

Los registros se escriben en `/var/log/wireguard-ddns-monitor.log` con marcas de tiempo.

Ejemplo de entrada de registro:
```
05-02-2026 21:48:58 - IP 203.0.113.1 not found in peer endpoints, restarting WireGuard...
```
