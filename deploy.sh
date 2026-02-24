#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.env"

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

# ─── Main ────────────────────────────────────────────────────────────────────

main() {
    echo "╔══════════════════════════════════════╗"
    echo "║   Raspberry Pi Kiosk Deploy System   ║"
    echo "╚══════════════════════════════════════╝"
    echo ""

    check_root
    check_architecture
    check_rpi_hardware
    check_config

    # Läs in konfiguration
    # shellcheck source=config.env
    source "$CONFIG_FILE"

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

    # Kör varje script i ordning
    local scripts=(
        "01-system.sh"
        "02-wifi.sh"
        "03-display.sh"
        "04-kiosk.sh"
        "05-vnc.sh"
        "06-watchdog.sh"
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

    echo "╔══════════════════════════════════════╗"
    echo "║         Deploy klar!                 ║"
    echo "╚══════════════════════════════════════╝"
    echo ""
    echo "Nästa steg:"
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

main "$@"
