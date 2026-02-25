#!/usr/bin/env bash
# 07-readonly.sh — Aktivera read-only SD-kort via overlayfs
set -euo pipefail

echo "[07] Aktiverar read-only läge (overlayfs)..."

raspi-config nonint enable_overlayfs

echo "[07] Read-only läge aktiverat — träder i kraft efter omstart."
