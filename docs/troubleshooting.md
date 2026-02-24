# Felsökning

## Chromium startar inte

**Kontrollera loggar:**
```bash
journalctl --user -u chromium-kiosk --no-pager -n 50
systemctl --user status chromium-kiosk
```

**Vanliga orsaker:**
- `WAYLAND_DISPLAY` inte satt — labwc kanske inte startade. Kolla `loginctl user-status pi`.
- Felaktig URL — kontrollera `KIOSK_URL` i service-filen.
- Chromium kraschar direkt — prova att rensa profil: `rm -rf ~/.config/chromium`

**Starta om manuellt:**
```bash
systemctl --user restart chromium-kiosk
```

---

## Skärm är blank / screen blanking aktivt

**Kontrollera cmdline.txt:**
```bash
cat /boot/firmware/cmdline.txt | grep -o 'consoleblank=[0-9]*'
# Ska visa: consoleblank=0
```

**Kontrollera wayfire.ini:**
```bash
cat ~/.config/wayfire.ini | grep screensaver_timeout
# Ska visa: screensaver_timeout=-1
```

**Inaktivera DPMS via Chromium (alternativ):**
Lägg till i ExecStart: `--disable-features=DmaBufVideoFramePool`

---

## Skärm roterar fel

**Kontrollera config.txt:**
```bash
grep display_rotate /boot/firmware/config.txt
```

**Rotationsvärden:**
- `display_rotate=0` — normal
- `display_rotate=1` — 90° medurs
- `display_rotate=2` — 180°
- `display_rotate=3` — 270° medurs

Ändring kräver omstart: `sudo reboot`

---

## VNC ansluter inte

**Kontrollera att wayvnc körs:**
```bash
pgrep -a wayvnc
systemctl --user status wayvnc 2>/dev/null || echo "Inget systemd-unit för wayvnc"
```

**Kontrollera konfigurationsfil:**
```bash
cat ~/.config/wayvnc/config
```

**Kontrollera brandvägg:**
```bash
# Kontrollera om port är öppen
ss -tlnp | grep 5900

# Tillåt port i ufw (om aktiv)
sudo ufw allow 5900/tcp
```

**Kontrollera att Wayland-session är aktiv:**
```bash
echo $WAYLAND_DISPLAY   # Ska visa "wayland-1" eller liknande
```

---

## WiFi ansluter inte

**Kontrollera anslutningar:**
```bash
nmcli connection show
nmcli device status
```

**Kontrollera filrättigheter (måste vara 600):**
```bash
ls -la /etc/NetworkManager/system-connections/
# Om fel:
sudo chmod 600 /etc/NetworkManager/system-connections/*.nmconnection
sudo systemctl restart NetworkManager
```

**Kontrollera att SSID och lösenord stämmer:**
```bash
sudo cat /etc/NetworkManager/system-connections/<SSID>.nmconnection
```

**Återanslut manuellt:**
```bash
nmcli connection up "<SSID>"
```

**Kontrollera WiFi-land:**
```bash
iw reg get
# Om fel, sätt landet:
sudo raspi-config nonint do_wifi_country SE
```

---

## labwc startar inte

**Kontrollera .bash_profile:**
```bash
cat ~/.bash_profile
# Ska innehålla labwc-start-logik
```

**Kontrollera autologin:**
```bash
cat /etc/systemd/system/getty@tty1.service.d/autologin.conf
```

**Starta labwc manuellt (för test):**
```bash
labwc &
```

**Loggar:**
```bash
journalctl -b | grep -i labwc
```

---

## Watchdog fungerar inte (Chromium startas inte om)

**Verifiera `Restart=always` i service-filen:**
```bash
cat ~/.config/systemd/user/chromium-kiosk.service | grep Restart
```

**Verifiera lingering:**
```bash
loginctl user-status pi | grep Linger
# Ska visa: Linger: yes
```

**Testa watchdog:**
```bash
pkill chromium
# Vänta 5 sekunder
systemctl --user status chromium-kiosk
# Ska visa: Active: active (running)
```
