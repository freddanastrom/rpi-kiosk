#!/usr/bin/env bash
# 07-readonly.sh — Aktivera read-only rootfs via overlayroot-paketet
# /home hålls skrivbar och persistent via direktmontage på blockenheten —
# kringgår overlayroot (recurse=0) så att config.env och annat i hemkatalogen
# kan redigeras och överleva omstart.
set -euo pipefail

CMDLINE_TXT="/boot/firmware/cmdline.txt"
OVERLAYROOT_CONF="/etc/overlayroot.conf"

echo "[07] Konfigurerar read-only läge (overlayroot) med skrivbar hemkatalog..."

# ─── Installera overlayroot vid behov ─────────────────────────────────────────
if ! dpkg -s overlayroot >/dev/null 2>&1; then
    echo "[07] Installerar overlayroot..."
    apt-get update
    apt-get install -y overlayroot
fi

# ─── Persistent /home via direktmontage ──────────────────────────────────────
# När overlayroot är aktivt går alla skrivningar till tmpfs och försvinner vid
# omstart. Genom att montera /home direkt från den riktiga partitionen
# kringgås overlayroot (tack vare recurse=0 nedan) och hemkatalogen förblir
# skrivbar och beständig.

if ! grep -q "/mnt/rw-root" /etc/fstab; then
    # Hämta root-partitionens PARTUUID ur cmdline.txt — fungerar även när
    # overlayroot är aktivt (cmdline.txt är alltid läsbar via /boot/firmware)
    ROOT_PARTUUID=$(grep -oP '(?<=root=PARTUUID=)[^ ]+' "$CMDLINE_TXT")

    if [[ -z "$ROOT_PARTUUID" ]]; then
        echo "[07] ERROR: Kunde inte hitta root PARTUUID i $CMDLINE_TXT" >&2
        exit 1
    fi

    mkdir -p /mnt/rw-root

    cat >> /etc/fstab <<EOF

# Persistent hemkatalog — kringgår overlayroot så att ~/config.env m.m. är skrivbara
# nofail: ett monteringsfel får aldrig blockera boot (undviker emergency mode / bootloop)
PARTUUID=${ROOT_PARTUUID}  /mnt/rw-root  ext4  defaults,noatime,nofail  0  0
/mnt/rw-root/home          /home         none  bind,nofail              0  0
EOF
    echo "[07] fstab: lagt till persistent /home (PARTUUID=${ROOT_PARTUUID})"
else
    echo "[07] fstab: persistent /home finns redan konfigurerat"
fi

# ─── Aktivera overlayroot ─────────────────────────────────────────────────────
# recurse=0: overlayroot rör inte separat monterade filsystem, så /mnt/rw-root
# (och därmed den bind-monterade /home) förblir skrivbart och beständigt.
echo "[07] Aktiverar overlayroot (read-only rootfs)..."
echo 'overlayroot="tmpfs:recurse=0"' > "$OVERLAYROOT_CONF"

# overlayroot styrs via /etc/overlayroot.conf. En 'overlayroot='-token på kärnans
# cmdline skulle åsidosätta konfigfilen — ta bort den så att konfigfilen alltid
# gäller (annars går av-/påslag via deploy.sh inte att styra). cmdline.txt ligger
# på FAT-bootpartitionen och är alltid skrivbar, även när overlayroot är aktivt.
if grep -q 'overlayroot=' "$CMDLINE_TXT"; then
    sed -i 's/[[:space:]]*overlayroot=[^[:space:]]*//g' "$CMDLINE_TXT"
    echo "[07] Tog bort overlayroot= ur cmdline.txt (styrs nu via $OVERLAYROOT_CONF)"
fi

echo "[07] Klart — /home är skrivbar och beständig, resten av / är read-only."
echo "[07] Träder i kraft efter omstart."
