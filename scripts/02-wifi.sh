#!/usr/bin/env bash
# 02-wifi.sh — NetworkManager WiFi-konfiguration
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config.env"

echo "[02] Konfigurerar WiFi (SSID: ${WIFI_SSID})..."

# Hoppa över om Pi redan är ansluten till rätt SSID
current_ssid=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2 || true)
if [[ "$current_ssid" == "$WIFI_SSID" ]]; then
    echo "[02] Redan ansluten till ${WIFI_SSID}, hoppar över WiFi-konfiguration."
    exit 0
fi

NM_CONN_DIR="/etc/NetworkManager/system-connections"
CONN_FILE="${NM_CONN_DIR}/${WIFI_SSID}.nmconnection"

# Generera UUID för anslutningen
CONN_UUID=$(cat /proc/sys/kernel/random/uuid)

mkdir -p "$NM_CONN_DIR"

# Generera NetworkManager-anslutningsfil från template
sed \
    -e "s|{{WIFI_SSID}}|${WIFI_SSID}|g" \
    -e "s|{{WIFI_PASSWORD}}|${WIFI_PASSWORD}|g" \
    -e "s|{{WIFI_COUNTRY}}|${WIFI_COUNTRY}|g" \
    -e "s|{{CONN_UUID}}|${CONN_UUID}|g" \
    "${SCRIPT_DIR}/templates/wifi.nmconnection.tpl" \
    > "$CONN_FILE"

# NetworkManager kräver 600-rättigheter
chmod 600 "$CONN_FILE"

echo "[02] Skapad: $CONN_FILE"

# Konfigurera WiFi-land
if command -v raspi-config &>/dev/null; then
    raspi-config nonint do_wifi_country "${WIFI_COUNTRY}"
    echo "[02] WiFi-land satt till: ${WIFI_COUNTRY}"
fi

# Aktivera WiFi
if nmcli radio wifi | grep -q "disabled"; then
    nmcli radio wifi on
    echo "[02] WiFi aktiverat."
fi

# Ladda om NetworkManager-konfiguration
systemctl reload NetworkManager 2>/dev/null || systemctl restart NetworkManager

echo "[02] WiFi-konfiguration klar."
