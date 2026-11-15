#!/usr/bin/env bash
# selene-chroot.sh — exécuté DANS le système installé (via arch-chroot) par selene-install.
# Reçoit « utilisateur:motdepasse » sur l'entrée standard et le reste via des variables SELENE_*.
set -Eeuo pipefail

# shellcheck source=/dev/null
. /root/distro.conf
: "${SELENE_USER:?}" "${SELENE_HOST:?}" "${SELENE_LOCALE:?}" "${SELENE_KEYMAP:?}" "${SELENE_TZ:?}"

log()  { printf '\e[32m==>\e[0m %s\n' "$*"; }
warn() { printf '\e[33m[!]\e[0m %s\n' "$*" >&2; }

IFS= read -r CREDS   # « utilisateur:motdepasse »

log "Fuseau horaire, langue et clavier"
ln -sf "/usr/share/zoneinfo/$SELENE_TZ" /etc/localtime
hwclock --systohc || warn "horloge matérielle non réglée (sans gravité)"
sed -i -e 's/^#\(en_US\.UTF-8 UTF-8\)/\1/' -e "s/^#\\(${SELENE_LOCALE} UTF-8\\)/\\1/" /etc/locale.gen
locale-gen
echo "LANG=$SELENE_LOCALE" > /etc/locale.conf
echo "KEYMAP=$SELENE_KEYMAP" > /etc/vconsole.conf
echo "$SELENE_HOST" > /etc/hostname
cat > /etc/hosts <<EOF2
127.0.0.1  localhost
::1        localhost
127.0.1.1  $SELENE_HOST.localdomain $SELENE_HOST
EOF2

log "Identité $OS_NAME"
/usr/local/bin/selene-brand

log "Compte utilisateur"
groupadd -f gamemode
groups=''
for g in wheel video audio input storage gamemode; do   # uniquement les groupes qui existent
  getent group "$g" >/dev/null && groups+="${groups:+,}$g"
done
useradd -m -G "$groups" -s /bin/bash "$SELENE_USER"
printf '%s\n' "$CREDS" | chpasswd
# Le compte root reçoit le même mot de passe : le mode de secours reste utilisable
printf 'root:%s\n' "${CREDS#*:}" | chpasswd
printf '%%wheel ALL=(ALL:ALL) ALL\n' > /etc/sudoers.d/10-wheel
chmod 0440 /etc/sudoers.d/10-wheel

if [[ ${SELENE_END4:-0} == 1 ]]; then
  log "Bureau end-4 : lancement prévu au premier démarrage"
  home=$(getent passwd "$SELENE_USER" | cut -d: -f6)
  grp=$(id -gn "$SELENE_USER")
  install -d -o "$SELENE_USER" -g "$grp" "$home/.config" "$home/.config/autostart"
  cat > "$home/.config/autostart/selene-end4.desktop" <<EOF2
[Desktop Entry]
Type=Application
Name=Installer le bureau end-4
Exec=konsole --separate --hold -e /usr/local/bin/selene end4 --first-login
EOF2
  chown "$SELENE_USER:$grp" "$home/.config/autostart/selene-end4.desktop"
fi

log "Miroirs et services"
mkdir -p /etc/xdg/reflector
cat > /etc/xdg/reflector/reflector.conf <<EOF2
--country France,Germany,Belgium,Netherlands,Switzerland,Luxembourg
--protocol https
--age 24
--latest 20
--sort rate
--save /etc/pacman.d/mirrorlist
EOF2
for unit in NetworkManager.service sddm.service bluetooth.service power-profiles-daemon.service \
            systemd-timesyncd.service fstrim.timer earlyoom.service reflector.timer \
            snapper-timeline.timer snapper-cleanup.timer grub-btrfsd.service; do
  systemctl enable "$unit" || warn "service non activé : $unit"
done
systemctl disable NetworkManager-wait-online.service 2>/dev/null || true   # démarrage plus rapide

if command -v flatpak >/dev/null; then
  flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo \
    || warn "Flathub non ajouté (tu pourras le faire plus tard avec : selene extras)"
fi

log "Snapshots Btrfs (snapper + snap-pac)"
if [[ ! -f /etc/snapper/configs/root ]]; then
  snapper --no-dbus -c root create-config / || warn "snapper n'a pas pu créer sa configuration"
fi
if [[ -f /etc/snapper/configs/root ]]; then
  sed -i -e 's/^TIMELINE_LIMIT_HOURLY=.*/TIMELINE_LIMIT_HOURLY="3"/' \
         -e 's/^TIMELINE_LIMIT_DAILY=.*/TIMELINE_LIMIT_DAILY="3"/' \
         -e 's/^TIMELINE_LIMIT_WEEKLY=.*/TIMELINE_LIMIT_WEEKLY="0"/' \
         -e 's/^TIMELINE_LIMIT_MONTHLY=.*/TIMELINE_LIMIT_MONTHLY="0"/' \
         -e 's/^TIMELINE_LIMIT_YEARLY=.*/TIMELINE_LIMIT_YEARLY="0"/' \
         -e 's/^NUMBER_LIMIT=.*/NUMBER_LIMIT="10"/' \
         -e 's/^NUMBER_LIMIT_IMPORTANT=.*/NUMBER_LIMIT_IMPORTANT="5"/' /etc/snapper/configs/root
  snapper --no-dbus -c root create -d "Installation de $OS_NAME" || warn "snapshot initial non créé"
fi

log "Initramfs et chargeur de démarrage (GRUB)"
mkinitcpio -P
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id="$OS_NAME" --recheck
grub-mkconfig -o /boot/grub/grub.cfg

log "Terminé"
