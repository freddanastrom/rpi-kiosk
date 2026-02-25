#!/usr/bin/env bash
# 07-readonly.sh — Aktivera read-only SD-kort via overlayfs
# /home hålls skrivbar och persistent via direktmontage på blockenheten —
# kringgår overlayfs så att config.env och annat i hemkatalogen kan redigeras.
set -euo pipefail

CMDLINE_TXT="/boot/firmware/cmdline.txt"

echo "[07] Konfigurerar read-only läge med skrivbar hemkatalog..."

# ─── Persistent /home via direktmontage ──────────────────────────────────────
# När overlayfs är aktivt går alla skrivningar till tmpfs och försvinner vid
# omstart. Genom att montera /home direkt från den riktiga partitionen
# kringgås overlayfs och hemkatalogen förblir skrivbar och beständig.

if ! grep -q "/mnt/rw-root" /etc/fstab; then
    # Hämta root-partitionens PARTUUID ur cmdline.txt — fungerar även när
    # overlayfs är aktivt (cmdline.txt är alltid läsbar via /boot/firmware)
    ROOT_PARTUUID=$(grep -oP '(?<=root=PARTUUID=)[^ ]+' "$CMDLINE_TXT")

    if [[ -z "$ROOT_PARTUUID" ]]; then
        echo "[07] ERROR: Kunde inte hitta root PARTUUID i $CMDLINE_TXT" >&2
        exit 1
    fi

    mkdir -p /mnt/rw-root

    cat >> /etc/fstab <<EOF

# Persistent hemkatalog — kringgår overlayfs så att ~/config.env m.m. är skrivbara
PARTUUID=${ROOT_PARTUUID}  /mnt/rw-root  ext4  defaults,noatime  0  0
/mnt/rw-root/home          /home         none  bind               0  0
EOF
    echo "[07] fstab: lagt till persistent /home (PARTUUID=${ROOT_PARTUUID})"
else
    echo "[07] fstab: persistent /home finns redan konfigurerat"
fi

# ─── Aktivera overlayfs ───────────────────────────────────────────────────────
echo "[07] Aktiverar overlayfs (read-only rootfs)..."
raspi-config nonint enable_overlayfs

echo "[07] Klart — /home är skrivbar och beständig, resten av / är read-only."
echo "[07] Träder i kraft efter omstart."
