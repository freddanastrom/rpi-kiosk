#!/usr/bin/env bash
# 05-vnc.sh — wayvnc fjärranslutning
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config.env"

KIOSK_HOME=$(getent passwd "${KIOSK_USER}" | cut -d: -f6)
WAYVNC_DIR="${KIOSK_HOME}/.config/wayvnc"

if [[ "${VNC_ENABLED}" != "true" ]]; then
    echo "[05] VNC är inaktiverat, hoppar över."
    exit 0
fi

echo "[05] Konfigurerar wayvnc (port: ${VNC_PORT})..."

mkdir -p "$WAYVNC_DIR"

sed \
    -e "s|{{VNC_PASSWORD}}|${VNC_PASSWORD}|g" \
    -e "s|{{VNC_PORT}}|${VNC_PORT}|g" \
    "${SCRIPT_DIR}/templates/wayvnc.ini" \
    > "${WAYVNC_DIR}/config"

chmod 600 "${WAYVNC_DIR}/config"
chown -R "${KIOSK_USER}:${KIOSK_USER}" "$WAYVNC_DIR"

echo "[05] Skapad: ${WAYVNC_DIR}/config"
echo "[05] Anslut med: vncviewer <PI_IP>:${VNC_PORT}"
echo "[05] wayvnc-konfiguration klar."
