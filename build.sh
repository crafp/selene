#!/usr/bin/env bash
# build.sh — construit l'ISO live + installateur de SeleneOS.
#
# À lancer sur Arch Linux (ou dans un conteneur « archlinux » lancé avec --privileged), en root :
#     sudo bash build.sh
#
# Variables utiles :
#   WORK=/chemin      dossier de travail (prévois ~15 Go libres)       [/var/tmp/selene-build]
#   OUT=/chemin       dossier où l'ISO est écrite                      [./out]
#   RELENG_DIR=...    profil archiso de base                           [/usr/share/archiso/configs/releng]
#   DRY_RUN=1         prépare le profil et s'arrête avant mkarchiso (pour tester)
#   SKIP_PKG_CHECK=1  ne vérifie pas les paquets dans les dépôts (hors Arch, avec DRY_RUN)
set -Eeuo pipefail

ROOT=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
# shellcheck source=/dev/null
. "$ROOT/distro.conf"
# shellcheck source=/dev/null
. "$ROOT/installer/lib.sh"

WORK=${WORK:-/var/tmp/selene-build}
OUT=${OUT:-$ROOT/out}
RELENG_DIR=${RELENG_DIR:-/usr/share/archiso/configs/releng}
DRY_RUN=${DRY_RUN:-0}
SKIP_PKG_CHECK=${SKIP_PKG_CHECK:-0}
PROFILE=$WORK/profile
A=$PROFILE/airootfs

trap 'warn "Échec à la ligne $LINENO."' ERR

[[ -n $WORK && $WORK != / ]] || die "WORK invalide."
if [[ $DRY_RUN != 1 ]]; then
  [[ $EUID -eq 0 ]] || die "Lance ce script en root :  sudo bash build.sh"
  command -v mkarchiso >/dev/null || die "mkarchiso introuvable. Installe archiso :  pacman -S archiso"
fi
[[ -d $RELENG_DIR ]] || die "Profil archiso introuvable ($RELENG_DIR). Installe archiso :  pacman -S archiso"

rm -rf "$WORK"
mkdir -p "$PROFILE" "$OUT" "$WORK/db"

# ── 1. Base : le profil officiel « releng » ──────────────────────────────────
msg "1/6  Base : profil officiel archiso « releng »"
cp -a "$RELENG_DIR"/. "$PROFILE"/

# ── 2. Paquets ───────────────────────────────────────────────────────────────
msg "2/6  Paquets (liste officielle + bureau KDE + $OS_NAME)"
if [[ $SKIP_PKG_CHECK == 1 ]]; then
  PKG_OUT=$(read_list "$ROOT/packages/desktop.txt" "$ROOT/packages/iso.txt" | sed 's/^?//')
else
  pacman_conf_for_host "$PROFILE/pacman.conf" "$WORK/pacman.conf"
  cp "$WORK/pacman.conf" "$PROFILE/pacman.conf"            # mkarchiso utilisera la même configuration
  ln -s /var/lib/pacman/local "$WORK/db/local"
  pacman --config "$PROFILE/pacman.conf" --dbpath "$WORK/db" -Sy >/dev/null
  PKG_OUT=$(resolve_packages "$PROFILE/pacman.conf" "$WORK/db" \
            "$ROOT/packages/desktop.txt" "$ROOT/packages/iso.txt") \
    || die "Liste de paquets invalide (voir ci-dessus)."
fi
{ echo; echo "# --- $OS_NAME ---"; echo "$PKG_OUT"; } >> "$PROFILE/packages.x86_64"

# ── 3. Personnalisation ──────────────────────────────────────────────────────
msg "3/6  Personnalisation du profil"

# 3a. Réseau : NetworkManager remplace iwd / systemd-networkd / ModemManager du profil releng
rm -f "$A"/etc/systemd/system/multi-user.target.wants/{iwd,systemd-networkd,ModemManager,sshd,livecd-talk}.service \
      "$A"/etc/systemd/system/dbus-org.freedesktop.network1.service \
      "$A"/etc/systemd/system/dbus-org.freedesktop.ModemManager1.service \
      "$A"/etc/systemd/system/sockets.target.wants/systemd-networkd.socket \
      "$A"/etc/systemd/system/network-online.target.wants/systemd-networkd-wait-online.service
rm -rf "$A"/etc/systemd/system/cloud-init.target.wants \
       "$A"/etc/systemd/network "$A"/etc/systemd/networkd.conf.d \
       "$A"/etc/systemd/system/systemd-networkd-wait-online.service.d

# 3b. Réglages communs (système installé) + couche live
render_tree "$ROOT/overlay/system" "$A"
render_tree "$ROOT/overlay/live" "$A"

# 3c. Le projet complet est embarqué dans l'ISO : c'est lui que l'installateur utilise
S=$A/usr/share/selene
mkdir -p "$S/overlay"
cp -a "$ROOT/distro.conf" "$ROOT/packages" "$ROOT/installer" "$S"/
cp -a "$ROOT/overlay/system" "$S/overlay/"
grep -rIlZ '' "$S" | xargs -0 sed -i 's/\r$//'

# 3d. Service de préparation de la session live
ln -sf ../selene-live-setup.service "$A/etc/systemd/system/multi-user.target.wants/selene-live-setup.service"

# 3e. Menu de démarrage (UEFI) : nom de la distribution, délai court, sans l'entrée « synthèse vocale »
rm -f "$PROFILE/efiboot/loader/entries/02-archiso-speech-linux.conf"
sed -i "s|Arch Linux install medium (%ARCH%, UEFI)|$OS_NAME Live (UEFI)|" "$PROFILE/efiboot/loader/entries/01-archiso-linux.conf"
sed -i 's/^timeout .*/timeout 5/' "$PROFILE/efiboot/loader/loader.conf"
grep -q "$OS_NAME Live" "$PROFILE/efiboot/loader/entries/01-archiso-linux.conf" \
  || die "Le profil releng a changé : entrée de démarrage introuvable (efiboot/loader/entries/01-archiso-linux.conf)."

# 3f. Si l'hôte désactive la « sandbox » pacman (conteneur sans Landlock), mkarchiso doit faire pareil
if [[ $SKIP_PKG_CHECK != 1 ]] && grep -q '^DisableSandbox' /etc/pacman.conf 2>/dev/null \
   && ! grep -q '^DisableSandbox' "$PROFILE/pacman.conf"; then
  sed -i '/^\[options\]/a DisableSandbox' "$PROFILE/pacman.conf"
fi

# 3g. Identité de l'ISO et permissions (profiledef.sh est un script bash lu par mkarchiso)
LABEL="${OS_ID^^}_$(date +%Y%m)"
cat >> "$PROFILE/profiledef.sh" <<EOF

# ─── $OS_NAME ───
iso_name="$OS_ID"
iso_label="${LABEL:0:32}"
iso_publisher="$OS_NAME <$OS_URL>"
iso_application="$OS_NAME Live/Installer"
bootmodes=('uefi.systemd-boot')
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15' '-b' '1M')
kernel_params_x86_64="quiet loglevel=3 amd_pstate=active"
file_permissions+=(
  ["/usr/local/bin/selene"]="0:0:755"
  ["/usr/local/bin/selene-brand"]="0:0:755"
  ["/usr/local/bin/selene-gamemode-session"]="0:0:755"
  ["/usr/local/bin/selene-install"]="0:0:755"
  ["/usr/local/bin/selene-live-setup"]="0:0:755"
  ["/etc/skel/Desktop/selene-install.desktop"]="0:0:755"
  ["/etc/sudoers.d/10-selene-live"]="0:0:440"
)
EOF

# ── 4. Contrôles ─────────────────────────────────────────────────────────────
msg "4/6  Contrôles"
bash -n "$PROFILE/profiledef.sh" || die "profiledef.sh invalide."
if grep -rIn '@OS_[A-Z]*@' "$A" --exclude-dir=selene | grep -q .; then
  grep -rIn '@OS_[A-Z]*@' "$A" --exclude-dir=selene || true
  die "Des variables @OS_...@ n'ont pas été remplacées."
fi
info "Profil prêt : $PROFILE"

if [[ $DRY_RUN == 1 ]]; then
  msg "DRY_RUN : arrêt avant mkarchiso."
  exit 0
fi

# ── 5. Construction ──────────────────────────────────────────────────────────
msg "5/6  Construction de l'ISO (10 à 30 minutes selon la machine)"
mkarchiso -v -w "$WORK/work" -o "$OUT" "$PROFILE"

# ── 6. Fin ───────────────────────────────────────────────────────────────────
msg "6/6  Terminé"
( cd "$OUT" && sha256sum ./*.iso > SHA256SUMS )
ls -lh "$OUT"
