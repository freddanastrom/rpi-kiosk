# rpi-kiosk

Deploy-system för Raspberry Pi 4/5 i kiosk-läge.

Visar en webbsida i fullskärm med automatisk omstart vid krasch, WiFi-konfiguration och valfri VNC-fjärranslutning.

## Stack

| Komponent | Val |
|-----------|-----|
| OS | Raspberry Pi OS Lite 64-bit (Bookworm) |
| Display | Wayland + labwc |
| Webbläsare | Chromium (`--kiosk --ozone-platform=wayland`) |
| WiFi | NetworkManager |
| Fjärranslutning | wayvnc |
| Watchdog | systemd user service (`Restart=always`) |

## Snabbstart

```bash
# 1. Flasha RPi OS Lite 64-bit, aktivera SSH via Raspberry Pi Imager
# 2. SSH in och klona repot
git clone https://github.com/<användare>/rpi-kiosk.git
cd rpi-kiosk

# 3. Konfigurera
cp config.env.template config.env
nano config.env

# 4. Kör deploy
sudo ./deploy.sh

# 5. Starta om
sudo reboot
```

## Dokumentation

- [Installationsguide](docs/install.md) — Steg-för-steg från noll till kiosk
- [Konfigurationsreferens](docs/configuration.md) — Alla variabler förklarade
- [Felsökning](docs/troubleshooting.md) — Vanliga problem och lösningar

## Projektstruktur

```
rpi-kiosk/
├── deploy.sh                     # Huvud-deploy-script
├── config.env.template           # Mall för konfiguration
├── config.env                    # Faktisk config (gitignoreras)
├── scripts/
│   ├── 01-system.sh              # Systemuppdatering + paket
│   ├── 02-wifi.sh                # NetworkManager WiFi
│   ├── 03-display.sh             # Rotation, screen blanking
│   ├── 04-kiosk.sh               # labwc autostart, autologin
│   ├── 05-vnc.sh                 # wayvnc fjärranslutning
│   └── 06-watchdog.sh            # systemd chromium watchdog
├── templates/
│   ├── autostart.sh              # labwc autostart-script
│   ├── chromium-kiosk.service    # systemd user service
│   ├── wifi.nmconnection.tpl     # NetworkManager template
│   └── wayvnc.ini                # wayvnc konfiguration
└── docs/
    ├── install.md
    ├── configuration.md
    └── troubleshooting.md
```

## Snabbreferens

```bash
# Ändra URL efter deploy
nano ~/.config/systemd/user/chromium-kiosk.service
systemctl --user daemon-reload && systemctl --user restart chromium-kiosk

# Kontrollera kiosk-status
systemctl --user status chromium-kiosk

# Visa loggar
journalctl --user -u chromium-kiosk -f

# Testa watchdog
pkill chromium   # Chromium startas om automatiskt efter 5s

# Anslut via VNC
vncviewer <PI_IP>:5900
```
