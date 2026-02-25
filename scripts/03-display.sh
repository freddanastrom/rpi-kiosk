#!/usr/bin/env bash
# 03-display.sh — Skärmkonfiguration, rotation och screen blanking
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config.env"

CONFIG_TXT="/boot/firmware/config.txt"
CMDLINE_TXT="/boot/firmware/cmdline.txt"
KIOSK_HOME=$(getent passwd "${KIOSK_USER}" | cut -d: -f6)

echo "[03] Konfigurerar skärm (rotation: ${DISPLAY_ROTATION})..."

# ─── GPU-minne i config.txt ───────────────────────────────────────────────────
# Rotation hanteras av wlr-randr i Wayland-sessionen (se autostart).

if grep -q "^gpu_mem=" "$CONFIG_TXT"; then
    sed -i "s/^gpu_mem=.*/gpu_mem=128/" "$CONFIG_TXT"
else
    echo "gpu_mem=128" >> "$CONFIG_TXT"
fi

# Ta bort eventuell gammal display_rotate (kan ge dubbelrotation med wlr-randr)
sed -i '/^display_rotate=/d' "$CONFIG_TXT"

echo "[03] config.txt: gpu_mem=128"

# ─── kanshi output-konfiguration ─────────────────────────────────────────────
# kanshi är en wlr-output-management-klient som håller output-konfigurationen
# persistent — mer tillförlitligt än att köra wlr-randr direkt i autostart.

# Konvertera rotation: 0 → normal, övriga behålls som-är (90, 180, 270)
case "${DISPLAY_ROTATION}" in
    0) KANSHI_TRANSFORM="normal" ;;
    *) KANSHI_TRANSFORM="${DISPLAY_ROTATION}" ;;
esac

KANSHI_DIR="${KIOSK_HOME}/.config/kanshi"
mkdir -p "$KANSHI_DIR"

cat > "${KANSHI_DIR}/config" <<EOF
profile {
    output * transform ${KANSHI_TRANSFORM}
}
EOF

chown -R "${KIOSK_USER}:${KIOSK_USER}" "$KANSHI_DIR"
echo "[03] kanshi config: transform=${KANSHI_TRANSFORM}"

# ─── Inaktivera console blanking i cmdline.txt ───────────────────────────────

if ! grep -q "consoleblank=0" "$CMDLINE_TXT"; then
    sed -i 's/$/ consoleblank=0/' "$CMDLINE_TXT"
    echo "[03] cmdline.txt: lade till consoleblank=0"
fi

# ─── Wayfire screen saver (screen blanking) ──────────────────────────────────

WAYFIRE_INI="${KIOSK_HOME}/.config/wayfire.ini"
mkdir -p "$(dirname "$WAYFIRE_INI")"

if [[ ! -f "$WAYFIRE_INI" ]]; then
    touch "$WAYFIRE_INI"
fi

if grep -q "^\[idle\]" "$WAYFIRE_INI"; then
    # Uppdatera befintlig sektion
    sed -i '/^\[idle\]/,/^\[/ s/^screensaver_timeout=.*/screensaver_timeout=-1/' "$WAYFIRE_INI"
    if ! grep -q "screensaver_timeout" "$WAYFIRE_INI"; then
        sed -i '/^\[idle\]/a screensaver_timeout=-1' "$WAYFIRE_INI"
    fi
else
    printf '\n[idle]\nscreensaver_timeout=-1\n' >> "$WAYFIRE_INI"
fi

chown "${KIOSK_USER}:${KIOSK_USER}" "$WAYFIRE_INI"
echo "[03] wayfire.ini: screensaver inaktiverat"

echo "[03] Skärmkonfiguration klar."
