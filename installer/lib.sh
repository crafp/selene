# shellcheck shell=bash
# lib.sh — fonctions communes à build.sh, à l'installateur et aux outils.

if [[ -t 1 ]]; then
  C_RED=$'\e[31m'; C_GRN=$'\e[32m'; C_YLW=$'\e[33m'; C_BLU=$'\e[34m'; C_BLD=$'\e[1m'; C_RST=$'\e[0m'
else
  C_RED=''; C_GRN=''; C_YLW=''; C_BLU=''; C_BLD=''; C_RST=''
fi
msg()  { printf '%s==>%s %s\n' "$C_GRN$C_BLD" "$C_RST" "$*"; }
info() { printf '%s -->%s %s\n' "$C_BLU$C_BLD" "$C_RST" "$*"; }
warn() { printf '%s[!]%s %s\n' "$C_YLW$C_BLD" "$C_RST" "$*" >&2; }
die()  { printf '%s[x]%s %s\n' "$C_RED$C_BLD" "$C_RST" "$*" >&2; exit 1; }

# read_list FICHIER... : affiche les lignes utiles d'une liste de paquets
# (sans commentaires, lignes vides, ni retours chariot Windows).
read_list() {
  local f
  for f in "$@"; do
    [[ -f $f ]] || die "Liste introuvable : $f"
    sed -e 's/\r$//' -e 's/[[:space:]]*#.*$//' -e 's/^[[:space:]]*//' -e '/^$/d' "$f"
  done
}

# resolve_packages CONF DBPATH FICHIER... : vérifie chaque paquet dans les dépôts.
#  - paquet « ?nom » absent  -> ignoré (avertissement)
#  - paquet requis absent    -> erreur (code 1) AVANT de toucher au moindre disque
# Affiche sur stdout la liste finale, sans doublons.
resolve_packages() {
  local conf=$1 db=$2; shift 2
  local line name optional
  local -a missing=() out=()
  while IFS= read -r line; do
    optional=0
    name=${line%%[[:space:]]*}
    if [[ $name == \?* ]]; then optional=1; name=${name#\?}; fi
    if pacman --config "$conf" --dbpath "$db" -Si "$name" &>/dev/null \
       || pacman --config "$conf" --dbpath "$db" -Sg "$name" &>/dev/null; then
      out+=("$name")
    elif ((optional)); then
      warn "paquet optionnel introuvable, ignoré : $name"
    else
      missing+=("$name")
    fi
  done < <(read_list "$@")
  if ((${#missing[@]})); then
    printf 'Paquets REQUIS introuvables dans les dépôts : %s\n' "${missing[*]}" >&2
    return 1
  fi
  printf '%s\n' "${out[@]}" | awk '!seen[$0]++'
}

# render_tree SRC DEST : copie SRC dans DEST (fusion) après avoir
#  - remplacé les variables @OS_NAME@ @OS_ID@ @OS_TAGLINE@ @OS_URL@
#  - supprimé les retours chariot Windows (CRLF)
#  - remis des permissions saines (scripts exécutables, sudoers en 0440)
# Nécessite que distro.conf ait été chargé (source).
render_tree() {
  local src=$1 dest=$2 stage f
  [[ -d $src ]] || die "Dossier introuvable : $src"
  stage=$(mktemp -d)
  cp -a "$src"/. "$stage"/
  while IFS= read -r -d '' f; do
    sed -i -e 's/\r$//' \
      -e "s|@OS_NAME@|${OS_NAME}|g" \
      -e "s|@OS_ID@|${OS_ID}|g" \
      -e "s|@OS_TAGLINE@|${OS_TAGLINE}|g" \
      -e "s|@OS_URL@|${OS_URL}|g" "$f"
  done < <(grep -rIlZ '' "$stage" || true)
  chmod -R u=rwX,go=rX "$stage"
  if [[ -d $stage/usr/local/bin ]]; then chmod 0755 "$stage"/usr/local/bin/*; fi
  if [[ -d $stage/etc/sudoers.d ]]; then chmod 0440 "$stage"/etc/sudoers.d/*; fi
  if [[ -d $stage/etc/skel/Desktop ]]; then chmod 0755 "$stage"/etc/skel/Desktop/*; fi
  mkdir -p "$dest"
  cp -a "$stage"/. "$dest"/
  rm -rf "$stage"
}

# pacman_conf_for_host SRC DEST : copie une config pacman pour un usage temporaire (vérifications, ISO).
#  - retire DownloadUser (les téléchargements se font en root dans ces contextes)
#  - recopie DisableSandbox si l'hôte l'utilise (conteneurs Docker, LXC… sans Landlock)
pacman_conf_for_host() {
  sed -e 's/\r$//' -e '/^DownloadUser/d' "$1" > "$2"
  if grep -q '^DisableSandbox' /etc/pacman.conf 2>/dev/null; then
    sed -i '/^\[options\]/a DisableSandbox' "$2"
  fi
}
