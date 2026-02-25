#!/usr/bin/env bash
# labwc autostart — körs när Wayland-sessionen startar

# XDG_RUNTIME_DIR krävs för systemctl --user och wayvnc
export XDG_RUNTIME_DIR="/run/user/$(id -u)"

# Importera display-miljön till systemd user manager så att
# chromium-kiosk.service ärver WAYLAND_DISPLAY automatiskt
systemctl --user import-environment WAYLAND_DISPLAY XDG_RUNTIME_DIR 2>/dev/null || true

# ─── Svart bakgrund (täcker vit labwc-standardbakgrund) ───────────────────────
swaybg -c '#000000' -m solid_color &

# ─── Förhindra autentiseringsdialog för WiFi ──────────────────────────────────
# nm-applet och polkit-agenter visar onödiga dialogs i kiosk-läge
pkill -f nm-applet 2>/dev/null || true
pkill -f polkit-gnome-authentication-agent 2>/dev/null || true

# ─── Skärmrotation via kanshi ─────────────────────────────────────────────────
# kanshi läser ~/.config/kanshi/config och håller output-konfigurationen
# persistent via wlr-output-management-protokollet
kanshi &

# ─── Starta Chromium via systemd watchdog-tjänst ──────────────────────────────
systemctl --user start chromium-kiosk.service

# ─── VNC (om aktiverat) ───────────────────────────────────────────────────────
if [[ "{{VNC_ENABLED}}" == "true" ]]; then
    wayvnc &
fi
