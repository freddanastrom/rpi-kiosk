# Konfigurationsreferens

Alla inställningar görs i `config.env` (kopiera från `config.env.template`).

---

## Kiosk-inställningar

### `KIOSK_URL`
URL:en som Chromium öppnar i kiosk-läge.

```bash
KIOSK_URL="https://dashboard.example.com"
```

**Ändra efter deploy:**
```bash
# Redigera service-filen
nano ~/.config/systemd/user/chromium-kiosk.service
systemctl --user daemon-reload
systemctl --user restart chromium-kiosk
```

### `KIOSK_USER`
Linux-användaren som kör kiosk-sessionen. Standardvärde: `pi`.

```bash
KIOSK_USER="pi"
```

---

## Display-inställningar

### `DISPLAY_ROTATION`
Skärmrotation. Värden:

| Värde | Beskrivning |
|-------|-------------|
| `0`   | Normal (liggande) |
| `1`   | 90° medurs (stående) |
| `2`   | 180° (upp-och-ned) |
| `3`   | 270° medurs / 90° moturs (stående, speglat) |

```bash
DISPLAY_ROTATION=0
```

Ändringen sparas i `/boot/firmware/config.txt` och kräver omstart.

---

## WiFi-inställningar

### `WIFI_SSID`
Namn på WiFi-nätverket (SSID).

```bash
WIFI_SSID="MittHemnätverk"
```

### `WIFI_PASSWORD`
Lösenord för WiFi-nätverket.

```bash
WIFI_PASSWORD="superHemligt123"
```

### `WIFI_COUNTRY`
Landskod för WiFi-regler (påverkar tillåtna frekvenser/kanaler).

```bash
WIFI_COUNTRY="SE"   # Sverige
# WIFI_COUNTRY="US"  # USA
# WIFI_COUNTRY="DE"  # Tyskland
```

**Byta WiFi-nätverk efter deploy:**
```bash
# Ta bort gammal anslutning
sudo nmcli connection delete "GammaltNätverk"

# Lägg till nytt
sudo nmcli device wifi connect "NyttNätverk" password "nytt_lösenord"
```

---

## VNC-inställningar

### `VNC_ENABLED`
Aktivera/inaktivera fjärranslutning via VNC.

```bash
VNC_ENABLED=true   # eller false
```

### `VNC_PASSWORD`
Lösenord för VNC-anslutning.

```bash
VNC_PASSWORD="säkertVncLösenord"
```

Minst 8 tecken rekommenderas. Lösenordet lagras i `~/.config/wayvnc/config` med rättigheterna 600.

### `VNC_PORT`
Port som VNC lyssnar på. Standard: `5900`.

```bash
VNC_PORT=5900
```

**Ansluta med VNC:**
```bash
# Med vncviewer (Linux)
vncviewer <PI_IP>:5900

# Med RealVNC Viewer (alla plattformar)
# Ange: <PI_IP>::5900
```
