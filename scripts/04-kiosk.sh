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
    -e "s|{{DISPLAY_ROTATION}}|${DISPLAY_ROTATION}|g" \
    "${SCRIPT_DIR}/templates/autostart.sh" \
    > "$AUTOSTART"

chmod +x "$AUTOSTART"

# Kopiera labwc-konfiguration (tangentbordskortkommandon)
cp "${SCRIPT_DIR}/templates/rc.xml" "${LABWC_DIR}/rc.xml"

# labwc environment: sätt osynlig markörtema för kompositorn och alla klienter
cat > "${LABWC_DIR}/environment" <<'EOF'
XCURSOR_THEME=invisible
XCURSOR_SIZE=1
EOF

chown -R "${KIOSK_USER}:${KIOSK_USER}" "$LABWC_DIR"

# ─── Osynlig markörtema ───────────────────────────────────────────────────────
# Skapar en minimal XCursor-fil (1x1 transparent) som fungerar på ren Wayland.
# unclutter fungerar ej på Wayland — composer + XCURSOR_THEME hanterar detta.
ICON_DIR="${KIOSK_HOME}/.local/share/icons/invisible"
CURSOR_DIR="${ICON_DIR}/cursors"
mkdir -p "$CURSOR_DIR"

XCURSOR_TARGET="$CURSOR_DIR" python3 <<'PYEOF'
import struct, os

cursor_dir = os.environ['XCURSOR_TARGET']

# XCursor-format: filhuvud + TOC + bildchunk (1x1 transparent ARGB)
file_header = b'Xcur' + struct.pack('<III', 16, 0x10000, 1)
toc          = struct.pack('<III', 0xFFFD0002, 1, 28)
chunk        = struct.pack('<IIIIIIIII', 36, 0xFFFD0002, 1, 1, 1, 1, 0, 0, 50)
pixels       = b'\x00\x00\x00\x00'

with open(os.path.join(cursor_dir, 'default'), 'wb') as f:
    f.write(file_header + toc + chunk + pixels)

names = [
    'left_ptr', 'right_ptr', 'top_left_arrow', 'cross', 'crosshair',
    'hand1', 'hand2', 'pointer', 'watch', 'wait', 'progress',
    'xterm', 'text', 'vertical-text', 'sb_h_double_arrow',
    'sb_v_double_arrow', 'fleur', 'move', 'all-scroll', 'not-allowed',
    'no-drop', 'help', 'n-resize', 's-resize', 'e-resize', 'w-resize',
    'ne-resize', 'sw-resize', 'nw-resize', 'se-resize', 'nesw-resize',
    'nwse-resize', 'ew-resize', 'ns-resize', 'col-resize', 'row-resize',
    'copy', 'alias', 'cell', 'grab', 'grabbing', 'zoom-in', 'zoom-out',
    'context-menu', 'up-arrow', 'size_all',
]
for name in names:
    path = os.path.join(cursor_dir, name)
    if not os.path.exists(path):
        os.symlink('default', path)
PYEOF

cat > "${ICON_DIR}/index.theme" <<'EOF'
[Icon Theme]
Name=invisible
EOF

chown -R "${KIOSK_USER}:${KIOSK_USER}" "${KIOSK_HOME}/.local"

echo "[04] Skapad: $AUTOSTART"
echo "[04] Skapad: ${LABWC_DIR}/rc.xml (Ctrl+Alt+T öppnar terminal)"
echo "[04] Skapad: osynlig markörtema (~/.local/share/icons/invisible)"

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

# ─── Inaktivera nm-applet XDG-autostart ──────────────────────────────────────
# nm-applet visar WiFi-autentiseringsdialog i kiosk-läge
KIOSK_AUTOSTART_DIR="${KIOSK_HOME}/.config/autostart"
mkdir -p "$KIOSK_AUTOSTART_DIR"
cat > "${KIOSK_AUTOSTART_DIR}/nm-applet.desktop" <<EOF
[Desktop Entry]
Hidden=true
EOF
chown -R "${KIOSK_USER}:${KIOSK_USER}" "$KIOSK_AUTOSTART_DIR"
echo "[04] nm-applet XDG-autostart inaktiverad"

echo "[04] Kiosk-konfiguration klar."
