#!/usr/bin/env bash
# 06-watchdog.sh — systemd user service för Chromium watchdog
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config.env"

KIOSK_HOME=$(getent passwd "${KIOSK_USER}" | cut -d: -f6)
SYSTEMD_USER_DIR="${KIOSK_HOME}/.config/systemd/user"
SERVICE_FILE="${SYSTEMD_USER_DIR}/chromium-kiosk.service"

echo "[06] Konfigurerar Chromium watchdog (systemd user service)..."

mkdir -p "$SYSTEMD_USER_DIR"

# Generera service-fil från template med KIOSK_URL inbakad
sed \
    -e "s|{{KIOSK_URL}}|${KIOSK_URL}|g" \
    "${SCRIPT_DIR}/templates/chromium-kiosk.service" \
    > "$SERVICE_FILE"

chown -R "${KIOSK_USER}:${KIOSK_USER}" "${KIOSK_HOME}/.config/systemd"

echo "[06] Skapad: $SERVICE_FILE"

# Aktivera lingering så att user services startar utan aktiv inloggning
loginctl enable-linger "${KIOSK_USER}"
echo "[06] Lingering aktiverat för ${KIOSK_USER}"

# Aktivera tjänsten som kiosk-användaren
sudo -u "${KIOSK_USER}" \
    XDG_RUNTIME_DIR="/run/user/$(id -u "${KIOSK_USER}")" \
    systemctl --user daemon-reload 2>/dev/null || true

sudo -u "${KIOSK_USER}" \
    XDG_RUNTIME_DIR="/run/user/$(id -u "${KIOSK_USER}")" \
    systemctl --user enable chromium-kiosk.service 2>/dev/null || \
    echo "[06] OBS: Kunde inte aktivera tjänsten nu (görs automatiskt vid inloggning)"

# ─── Chromium policy: inaktivera translate permanent ─────────────────────────
# Managed policy tar precedens över flaggor och användarinställningar.
POLICY_DIR="/etc/chromium/policies/managed"
mkdir -p "$POLICY_DIR"
cat > "${POLICY_DIR}/kiosk.json" <<'EOF'
{
  "TranslateEnabled": false
}
EOF
echo "[06] Chromium-policy: TranslateEnabled=false"

# ─── Daglig omstart 05:00 via systemd timer ──────────────────────────────────
cat > /etc/systemd/system/kiosk-reboot.service <<'EOF'
[Unit]
Description=Daily kiosk reboot

[Service]
Type=oneshot
ExecStart=/sbin/reboot
EOF

cat > /etc/systemd/system/kiosk-reboot.timer <<'EOF'
[Unit]
Description=Daily kiosk reboot at 05:00

[Timer]
OnCalendar=*-*-* 05:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable kiosk-reboot.timer
echo "[06] Daglig omstart aktiverad: 05:00"

echo "[06] Watchdog-konfiguration klar."
