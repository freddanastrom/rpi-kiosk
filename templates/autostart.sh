#!/usr/bin/env bash
# labwc autostart — körs vid start av Wayland-sessionen

# Dölj muspekaren efter 1 sekund
unclutter --timeout 1 &

# Starta Chromium via systemd user service (med watchdog)
systemctl --user start chromium-kiosk.service

# Starta VNC om aktiverat
if [[ "{{VNC_ENABLED}}" == "true" ]]; then
    wayvnc &
fi
