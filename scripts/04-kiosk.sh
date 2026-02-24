#!/usr/bin/env bash
# 04-kiosk.sh — labwc autostart och kiosk-konfiguration
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config.env"

KIOSK_HOME=$(getent passwd "${KIOSK_USER}" | cut -d: -f6)
LABWC_DIR="${KIOSK_HOME}/.config/labwc"
AUTOSTART="${LABWC_DIR}/autostart"

echo "[04] Konfigurerar kiosk-autostart..."

mkdir -p "$LABWC_DIR"

# Generera autostart från template
sed \
    -e "s|{{VNC_ENABLED}}|${VNC_ENABLED}|g" \
    "${SCRIPT_DIR}/templates/autostart.sh" \
    > "$AUTOSTART"

chmod +x "$AUTOSTART"
chown -R "${KIOSK_USER}:${KIOSK_USER}" "$LABWC_DIR"

echo "[04] Skapad: $AUTOSTART"

# ─── Aktivera autologin för KIOSK_USER ───────────────────────────────────────

# Raspberry Pi OS Lite: konfigurera getty autologin
GETTY_OVERRIDE="/etc/systemd/system/getty@tty1.service.d/autologin.conf"
mkdir -p "$(dirname "$GETTY_OVERRIDE")"

cat > "$GETTY_OVERRIDE" <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${KIOSK_USER} --noclear %I \$TERM
EOF

systemctl daemon-reload
echo "[04] Autologin aktiverat för ${KIOSK_USER} på tty1"

# ─── Starta labwc vid inloggning via .bash_profile ───────────────────────────

BASH_PROFILE="${KIOSK_HOME}/.bash_profile"

# Lägg till labwc-start om det inte redan finns
if ! grep -q "labwc" "$BASH_PROFILE" 2>/dev/null; then
    cat >> "$BASH_PROFILE" <<'EOF'

# Starta labwc om vi är på tty1 och inte redan i en grafisk session
if [[ -z "${WAYLAND_DISPLAY}" ]] && [[ "$(tty)" == "/dev/tty1" ]]; then
    exec labwc
fi
EOF
    chown "${KIOSK_USER}:${KIOSK_USER}" "$BASH_PROFILE"
    echo "[04] labwc-start lagt till i ${BASH_PROFILE}"
fi

echo "[04] Kiosk-konfiguration klar."
