# Installationsguide

## Förutsättningar

- Raspberry Pi 4 eller 5
- microSD-kort (minst 16 GB rekommenderas)
- [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
- SSH-klient (t.ex. terminal på Linux/macOS, PuTTY på Windows)

---

## Steg 1 — Flasha operativsystemet

1. Öppna **Raspberry Pi Imager**
2. Välj enhet: Raspberry Pi 4 eller 5
3. Välj OS: **Raspberry Pi OS Lite (64-bit)** under "Raspberry Pi OS (other)"
4. Välj ditt microSD-kort
5. Klicka på kugghjulet (⚙) för **Advanced Options** och konfigurera:
   - Aktivera SSH (Use password authentication)
   - Sätt användarnamn (t.ex. `pi`) och lösenord
   - Ange WiFi-SSID och lösenord (för initial uppkoppling)
   - Sätt locale/tidszon
6. Klicka **Write** och vänta tills klart

---

## Steg 2 — Hitta Pi:ns IP-adress

Sätt i SD-kortet, anslut Pi och vänta ~60 sekunder tills den startat.

```bash
# Alternativ 1: Från din router (DHCP-lista)
# Alternativ 2: Skanna nätverket
nmap -sn 192.168.1.0/24 | grep -i raspberry

# Alternativ 3: Om du har mDNS
ping raspberrypi.local
```

---

## Steg 3 — Anslut via SSH

```bash
ssh pi@<PI_IP>
```

---

## Steg 4 — Klona detta repo

```bash
# Installera git om det saknas
sudo apt-get install -y git

# Klona repot
git clone https://github.com/<ditt-användarnamn>/rpi-kiosk.git
cd rpi-kiosk
```

---

## Steg 5 — Konfigurera

```bash
cp config.env.template config.env
nano config.env
```

Fyll i dina värden. Se [configuration.md](configuration.md) för förklaringar av alla variabler.

---

## Steg 6 — Kör deploy

```bash
sudo ./deploy.sh
```

Scriptet kommer att:
1. Visa din konfiguration för bekräftelse
2. Uppdatera systemet och installera paket
3. Konfigurera WiFi
4. Konfigurera skärmrotation och screen blanking
5. Sätta upp labwc autostart och kiosk-läge
6. Konfigurera wayvnc (om aktiverat)
7. Installera Chromium systemd watchdog-tjänst
8. Fråga om omstart

---

## Steg 7 — Starta om

```bash
sudo reboot
```

Efter omstarten loggar Pi automatiskt in och startar webbläsaren i kiosk-läge.

---

## Verifiera att allt fungerar

```bash
# Kontrollera att Chromium körs
ssh pi@<PI_IP> "systemctl --user status chromium-kiosk"

# Kontrollera WiFi-anslutning
ssh pi@<PI_IP> "nmcli connection show --active"

# Kontrollera VNC (om aktiverat)
ssh pi@<PI_IP> "pgrep wayvnc && echo 'wayvnc körs'"
```
