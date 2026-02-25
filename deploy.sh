#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.env"

# Sökväg till sentinel-fil som markerar att initial deploy är gjord
DEPLOYED_MARKER="/etc/rpi-kiosk.deployed"

# ─── Hjälptext ───────────────────────────────────────────────────────────────

usage() {
    cat <<EOF
Användning:
  sudo ./deploy.sh                    Fullständig deploy (första gången)
  sudo ./deploy.sh --update           Uppdatera alla inställningar från config.env
  sudo ./deploy.sh --update <modul>   Uppdatera en specifik del

Moduler:
  wifi      WiFi-anslutning (02-wifi.sh)
  display   Skärmrotation och blanking (03-display.sh)
  kiosk     labwc autostart (04-kiosk.sh)
  vnc       wayvnc-konfiguration (05-vnc.sh)
  watchdog  Chromium systemd-tjänst (06-watchdog.sh)

Exempel:
  sudo ./deploy.sh --update wifi
  sudo ./deploy.sh --update watchdog
  sudo ./deploy.sh --update wifi watchdog

OBS: Om read-only läge är aktivt inaktiveras det automatiskt, varefter
en omstart krävs. Kör samma kommando igen efter omstarten.
Read-only läge återaktiveras automatiskt efter varje uppdatering.
EOF
    exit 0
}

# ─── Checks ──────────────────────────────────────────────────────────────────

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "ERROR: Detta script måste köras som root (sudo ./deploy.sh)" >&2
        exit 1
    fi
}

check_architecture() {
    local arch
    arch=$(uname -m)
    if [[ "$arch" != "aarch64" ]]; then
        echo "WARNING: Förväntad arkitektur aarch64, hittade: $arch"
        read -rp "Fortsätt ändå? [y/N] " confirm
        [[ "$confirm" =~ ^[yY]$ ]] || exit 1
    fi
}

check_rpi_hardware() {
    if [[ ! -f /proc/device-tree/model ]]; then
        echo "WARNING: Kan inte verifiera Raspberry Pi-hårdvara"
        read -rp "Fortsätt ändå? [y/N] " confirm
        [[ "$confirm" =~ ^[yY]$ ]] || exit 1
    else
        local model
        model=$(tr -d '\0' < /proc/device-tree/model)
        if [[ "$model" != *"Raspberry Pi"* ]]; then
            echo "WARNING: Okänd hårdvara: $model"
            read -rp "Fortsätt ändå? [y/N] " confirm
            [[ "$confirm" =~ ^[yY]$ ]] || exit 1
        else
            echo "Hårdvara: $model"
        fi
    fi
}

check_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "ERROR: config.env saknas!" >&2
        echo "Kopiera mallen och fyll i dina värden:" >&2
        echo "  cp config.env.template config.env" >&2
        echo "  nano config.env" >&2
        exit 1
    fi
}

# ─── Overlayfs-hjälpfunktion ─────────────────────────────────────────────────

overlayfs_active() {
    findmnt -n -o FSTYPE / 2>/dev/null | grep -q "^overlay$"
}

# ─── Tjänstomstart efter uppdatering ─────────────────────────────────────────

# Returnerar 0 om omstart krävs, 1 om tjänster hanterades direkt
restart_services() {
    local modules=("$@")
    local needs_reboot=false
    local KIOSK_HOME
    KIOSK_HOME=$(getent passwd "${KIOSK_USER}" | cut -d: -f6)
    local KIOSK_UID
    KIOSK_UID=$(id -u "${KIOSK_USER}")

    for module in "${modules[@]}"; do
        case "$module" in
            wifi)
                echo "  Laddar om NetworkManager..."
                systemctl reload-or-restart NetworkManager
                sleep 2
                nmcli connection up "${WIFI_SSID}" 2>/dev/null && \
                    echo "  WiFi återansluten: ${WIFI_SSID}" || \
                    echo "  INFO: WiFi-anslutning görs vid nästa start."
                ;;
            display)
                echo "  Skärmändringar kräver omstart."
                needs_reboot=true
                ;;
            kiosk)
                echo "  Startar om labwc-session..."
                sudo -u "${KIOSK_USER}" \
                    XDG_RUNTIME_DIR="/run/user/${KIOSK_UID}" \
                    WAYLAND_DISPLAY=wayland-1 \
                    pkill labwc 2>/dev/null && \
                    echo "  labwc startas om automatiskt via autologin." || \
                    echo "  INFO: labwc körs inte nu; ny autostart används vid nästa inloggning."
                ;;
            vnc)
                echo "  Startar om wayvnc..."
                sudo -u "${KIOSK_USER}" \
                    XDG_RUNTIME_DIR="/run/user/${KIOSK_UID}" \
                    pkill wayvnc 2>/dev/null || true
                sudo -u "${KIOSK_USER}" \
                    XDG_RUNTIME_DIR="/run/user/${KIOSK_UID}" \
                    WAYLAND_DISPLAY=wayland-1 \
                    nohup wayvnc >/dev/null 2>&1 &
                echo "  wayvnc omstartad."
                ;;
            watchdog)
                echo "  Laddar om och startar om chromium-kiosk..."
                sudo -u "${KIOSK_USER}" \
                    XDG_RUNTIME_DIR="/run/user/${KIOSK_UID}" \
                    systemctl --user daemon-reload
                sudo -u "${KIOSK_USER}" \
                    XDG_RUNTIME_DIR="/run/user/${KIOSK_UID}" \
                    systemctl --user restart chromium-kiosk.service
                echo "  chromium-kiosk omstartad."
                ;;
        esac
    done

    if [[ "$needs_reboot" == "true" ]]; then
        return 0
    fi
    return 1
}

# ─── Körlägen ────────────────────────────────────────────────────────────────

run_full_deploy() {
    echo ""
    echo "Konfiguration:"
    echo "  KIOSK_URL:        ${KIOSK_URL}"
    echo "  KIOSK_USER:       ${KIOSK_USER}"
    echo "  DISPLAY_ROTATION: ${DISPLAY_ROTATION}"
    echo "  WIFI_SSID:        ${WIFI_SSID}"
    echo "  VNC_ENABLED:      ${VNC_ENABLED}"
    echo ""

    read -rp "Starta deploy med dessa inställningar? [y/N] " confirm
    [[ "$confirm" =~ ^[yY]$ ]] || { echo "Avbröt."; exit 0; }
    echo ""

    local scripts=(
        "01-system.sh"
        "02-wifi.sh"
        "03-display.sh"
        "04-kiosk.sh"
        "05-vnc.sh"
        "06-watchdog.sh"
        "07-readonly.sh"
    )

    for script in "${scripts[@]}"; do
        local script_path="${SCRIPT_DIR}/scripts/${script}"
        if [[ ! -f "$script_path" ]]; then
            echo "ERROR: Script saknas: $script_path" >&2
            exit 1
        fi
        echo "━━━ Kör: $script ━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        bash "$script_path"
        echo ""
    done

    # Spara sentinel
    date -Iseconds > "$DEPLOYED_MARKER"

    echo "╔══════════════════════════════════════╗"
    echo "║         Deploy klar!                 ║"
    echo "╚══════════════════════════════════════╝"
    echo ""
    echo "  En omstart krävs för att alla ändringar ska träda i kraft."
    echo ""
    read -rp "Starta om nu? [y/N] " reboot_confirm
    if [[ "$reboot_confirm" =~ ^[yY]$ ]]; then
        echo "Startar om..."
        reboot
    else
        echo "Kom ihåg att starta om: sudo reboot"
    fi
}

run_update() {
    local requested_modules=("$@")

    # ─── Overlayfs-kontroll ───────────────────────────────────────────────────
    if overlayfs_active; then
        echo ""
        echo "Read-only läge (overlayfs) är aktivt."
        echo "Inaktiverar för att tillåta skrivning till SD-kortet..."
        raspi-config nonint disable_overlayfs
        echo ""
        echo "Read-only inaktiverat. Starta om och kör sedan samma kommando igen:"
        echo "  sudo ./deploy.sh --update ${requested_modules[*]}"
        echo ""
        read -rp "Starta om nu? [Y/n] " confirm
        [[ "$confirm" =~ ^[nN]$ ]] || reboot
        exit 0
    fi

    # Mappa modulnamn → scriptnummer
    declare -A MODULE_SCRIPT=(
        [wifi]="02-wifi.sh"
        [display]="03-display.sh"
        [kiosk]="04-kiosk.sh"
        [vnc]="05-vnc.sh"
        [watchdog]="06-watchdog.sh"
    )

    # Validera modulnamn
    for m in "${requested_modules[@]}"; do
        if [[ -z "${MODULE_SCRIPT[$m]+_}" ]]; then
            echo "ERROR: Okänd modul: '$m'" >&2
            echo "Giltiga moduler: ${!MODULE_SCRIPT[*]}" >&2
            exit 1
        fi
    done

    echo ""
    echo "Konfiguration:"
    echo "  KIOSK_URL:        ${KIOSK_URL}"
    echo "  KIOSK_USER:       ${KIOSK_USER}"
    echo "  DISPLAY_ROTATION: ${DISPLAY_ROTATION}"
    echo "  WIFI_SSID:        ${WIFI_SSID}"
    echo "  VNC_ENABLED:      ${VNC_ENABLED}"
    echo ""
    echo "Uppdaterar moduler: ${requested_modules[*]}"
    echo ""
    read -rp "Fortsätt? [y/N] " confirm
    [[ "$confirm" =~ ^[yY]$ ]] || { echo "Avbröt."; exit 0; }
    echo ""

    for module in "${requested_modules[@]}"; do
        local script="${MODULE_SCRIPT[$module]}"
        local script_path="${SCRIPT_DIR}/scripts/${script}"
        echo "━━━ Kör: $script ━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        bash "$script_path"
        echo ""
    done

    echo "━━━ Startar om berörda tjänster ━━━━━━━━━━━━━━"
    restart_services "${requested_modules[@]}" || true
    echo ""

    echo "━━━ Aktiverar read-only läge ━━━━━━━━━━━━━━━━"
    bash "${SCRIPT_DIR}/scripts/07-readonly.sh"
    echo ""

    echo "Uppdatering klar. Starta om för att aktivera read-only läge."
    read -rp "Starta om nu? [Y/n] " reboot_confirm
    [[ "$reboot_confirm" =~ ^[nN]$ ]] || reboot
    echo "Kom ihåg att starta om: sudo reboot"
}

# ─── Main ────────────────────────────────────────────────────────────────────

main() {
    echo "╔══════════════════════════════════════╗"
    echo "║   Raspberry Pi Kiosk Deploy System   ║"
    echo "╚══════════════════════════════════════╝"

    check_root
    check_config

    # shellcheck source=config.env
    source "$CONFIG_FILE"

    # Parsea argument
    local mode="full"
    local modules=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --update)
                mode="update"
                shift
                while [[ $# -gt 0 ]] && [[ "$1" != --* ]]; do
                    modules+=("$1")
                    shift
                done
                ;;
            --help|-h)
                usage
                ;;
            *)
                echo "ERROR: Okänt argument: $1" >&2
                usage
                ;;
        esac
    done

    # Standardmoduler för --update utan specificerade moduler
    if [[ "$mode" == "update" ]] && [[ ${#modules[@]} -eq 0 ]]; then
        modules=(wifi display kiosk vnc watchdog)
    fi

    case "$mode" in
        full)
            check_architecture
            check_rpi_hardware
            run_full_deploy
            ;;
        update)
            run_update "${modules[@]}"
            ;;
    esac
}

main "$@"
