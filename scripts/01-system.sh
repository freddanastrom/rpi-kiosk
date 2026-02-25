#!/usr/bin/env bash
# 01-system.sh — Systemuppdatering och paketinstallation
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config.env"

echo "[01] Uppdaterar system och installerar paket..."

apt-get update -qq
apt-get full-upgrade -y

apt-get install -y \
    chromium \
    wayvnc \
    wlr-randr \
    kanshi \
    swaybg \
    foot \
    network-manager \
    raspi-config \
    curl \
    --no-install-recommends

echo "[01] Systemuppdatering klar."
