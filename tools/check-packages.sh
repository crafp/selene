#!/usr/bin/env bash
# check-packages.sh — vérifie que tous les paquets des listes existent dans les dépôts Arch.
# À lancer sur Arch Linux, en root :  sudo bash tools/check-packages.sh
# (Les paquets marqués « ? » sont optionnels : s'ils ont disparu, ils sont simplement ignorés.)
set -Eeuo pipefail

ROOT=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
# shellcheck source=/dev/null
. "$ROOT/installer/lib.sh"

[[ $EUID -eq 0 ]] || die "Lance ce script en root :  sudo bash tools/check-packages.sh"
command -v pacman >/dev/null || die "Ce script doit tourner sur Arch Linux (ou dans un conteneur archlinux)."

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/db"
ln -s /var/lib/pacman/local "$TMP/db/local"
pacman_conf_for_host "$ROOT/overlay/system/etc/pacman.conf" "$TMP/pacman.conf"

msg "Synchronisation des dépôts (core, extra, multilib)"
pacman --config "$TMP/pacman.conf" --dbpath "$TMP/db" -Sy >/dev/null
msg "Vérification des listes de paquets"
resolve_packages "$TMP/pacman.conf" "$TMP/db" "$ROOT"/packages/*.txt >/dev/null
msg "OK : tous les paquets requis existent."
