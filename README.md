# ☾ SeleneOS

**Arch Linux en mode nuit : rapide, fluide, prêt pour le jeu.**
Fait sur mesure pour un **ASUS Vivobook S14 (M5406UA)** : Ryzen 9 8945HS, Radeon 780M, 16 Go de RAM, écran OLED 2880×1800.

> ⚠️ **Honnêteté d'abord.** Ce projet n'a pas pu être démarré sur un vrai PC pendant sa création : les scripts ont été
> vérifiés (syntaxe, shellcheck, partitionnement testé sur des images disque), pas l'ISO complète. Les premiers essais
> serviront à corriger les petits détails — envoie-moi les messages d'erreur et on itère.
> Ce n'est pas un système écrit « de zéro » : c'est une **distribution dérivée d'Arch**, comme CachyOS ou EndeavourOS
> (Arch + une sélection de paquets + des réglages + un thème + un installateur).

---

## Ce que tu obtiens

| | |
|---|---|
| **Base** | Arch Linux (rolling), noyau **linux-zen** (réactivité bureau/jeu) + **linux-lts** en secours |
| **Bureau** | **KDE Plasma 6 en Wayland** : barre du haut fine + dock flottant, flou, thème sombre indigo « Selene Night », fond d'écran lunaire, icônes Papirus, polices Inter / JetBrains Mono |
| **Performances** | `amd_pstate=active`, zram (swap compressé en RAM), réglages mémoire/réseau (BBR), ordonnanceurs d'E/S adaptés, cache de shaders 10 Go, indexation de fichiers désactivée, démarrage allégé |
| **Gaming** (esprit Bazzite) | Steam, **gamescope**, GameMode, MangoHud, Wine-staging, Lutris, Vulkan RADV 32+64 bits, session **« Game Mode »** (Steam plein écran façon console), Flatpak (Proton-GE, Heroic, Bottles via `selene extras`) |
| **Sécurité des mises à jour** | Btrfs compressé + **snapshots automatiques avant/après chaque mise à jour** (snapper + snap-pac), démarrables depuis GRUB |
| **Boîte à outils** | la commande `selene` (un peu comme `ujust` sous Bazzite) |
| **Double démarrage** | Windows reste possible (GRUB le détecte) |
| **Style « end-4 » (option)** | le bureau Hyprland + Quickshell vu sur TikTok (**end4-pC**), installable en une commande à côté de KDE — voir plus bas |

---

## Étape 1 — Construire l'ISO

Il faut un environnement Arch Linux pour construire l'ISO. Le plus simple quand on est sous Windows :

### Option A — GitHub Actions (recommandé, rien à installer)

1. Crée un dépôt GitHub **public** (le stockage gratuit des artefacts est très limité en privé) et envoie-y ce dossier :
   ```bash
   git init && git add . && git commit -m "SeleneOS"
   git branch -M main
   git remote add origin https://github.com/TON-PSEUDO/selene.git
   git push -u origin main
   ```
   (vérifie que le dossier caché `.github/` est bien envoyé — avec `git push` c'est automatique).
2. Onglet **Actions** → **Construire l'ISO** → **Run workflow**. Compte 30 à 60 minutes.
3. En bas de la page de l'exécution : télécharge l'artefact **selene-iso** (un .zip qui contient l'ISO et `SHA256SUMS`).

Si le job échoue, ouvre les logs et colle-moi les dernières lignes : en général, c'est un nom de paquet qui a changé chez Arch.

### Option B — Docker Desktop (Windows, WSL2)
```powershell
docker run --rm -it --privileged -v "${PWD}:/repo" -w /repo archlinux:latest bash -c "sed -i 's/^#DisableSandbox/DisableSandbox/' /etc/pacman.conf && pacman -Syu --noconfirm archiso && bash tools/check-packages.sh && bash build.sh"
```
L'ISO apparaît dans le dossier `out/`.

### Option C — Une machine virtuelle Arch
Démarre l'ISO officielle d'Arch dans VirtualBox, puis : `pacman -Sy archiso git`, récupère ce dossier, et lance `sudo bash build.sh`.

---

## Étape 2 — Préparer la clé USB et le PC

1. **Écris l'ISO sur une clé USB** (8 Go minimum) avec **Rufus** (choisis le mode **« Image DD »**) ou copie-la sur une clé **Ventoy**.
2. **Désactive Secure Boot** dans le BIOS (touche **F2** au démarrage ; **Échap** ouvre le menu de démarrage sur la plupart des ASUS). L'ISO n'est pas signée pour Secure Boot.
3. Si tu veux **garder Windows** :
   - note ta **clé de récupération BitLocker** (<https://account.microsoft.com/devices/recoverykey>) *avant* de toucher au BIOS : Windows peut la demander ensuite ;
   - désactive le **démarrage rapide** de Windows ;
   - dans **Gestion des disques**, fais un clic droit sur `C:` → **Réduire le volume** (au moins 60 Go) et laisse l'espace **non alloué**.

---

## Étape 3 — Essayer, puis installer

1. Démarre sur la clé (menu **Échap** → ta clé en mode UEFI). Tu arrives directement sur le bureau **live** : **rien n'est écrit sur ton disque**, c'est l'occasion de tester Wi-Fi, son, écran, clavier AZERTY, touchpad.
2. Connecte-toi à Internet (icône réseau du bureau) : l'installateur télécharge les paquets (plusieurs Go).
3. Double-clique sur **« Installer SeleneOS »** (ou `sudo selene-install` dans un terminal) et réponds aux questions :
   - **disque** : la clé USB est exclue automatiquement ;
   - **mode 1** : *effacer tout le disque* (Windows supprimé) — ou **mode 2** : *à côté de Windows* (utilise l'espace non alloué, réutilise la partition EFI de Windows) ;
   - nom d'utilisateur, mot de passe, nom de la machine.
4. Quand c'est fini : retire la clé, redémarre. Dans GRUB, choisis **SeleneOS** (ou Windows).

> Langue, clavier et fuseau sont réglés pour la France (`fr_FR`, AZERTY, `Europe/Paris`) — modifiables dans `distro.conf`.

---

## Après l'installation

### La commande `selene`
```
selene info             résumé du système (noyau, CPU, GPU, mémoire, zram, ordonnanceur…)
selene update           met à jour Arch (snapshot auto avant/après) puis Flatpak
selene perf [mode]      profil d'énergie : saver | balanced | performance
selene gamemode on|off  démarrer directement en Game Mode (Steam plein écran), ou non
selene scx on|off       ordonnanceur sched_ext « lavd » (expérimental, pensé pour le jeu)
selene end4 [fork]      bureau « end-4 » (Hyprland + Quickshell) ; « fork » = le style end4-pC
selene extras proton heroic bottles flatseal   (ou : all)   — via Flatpak
selene aur              installe « paru » pour le dépôt utilisateur AUR
selene snapshots        liste des points de restauration Btrfs
selene clean            nettoie caches, orphelins, journaux
```

### Jouer
- Au premier lancement de **Steam**, connecte-toi, puis *Paramètres → Compatibilité → Activer Steam Play pour tous les autres titres*.
- Installe **Proton-GE** : `selene extras proton`, puis ouvre ProtonUp-Qt.
- Options de lancement Steam d'un jeu : `gamemoderun mangohud %command%` (GameMode + compteur de FPS ; `Maj droite + F12` pour l'afficher/masquer).
- **Game Mode** : à l'écran de connexion, choisis la session **« SeleneOS Mode Jeu »** (Steam plein écran dans gamescope). Quitter Steam te ramène à l'écran de connexion. Pour y démarrer directement : `selene gamemode on`. Résolution/fréquence/VRR : `/etc/selene/gamemode.conf`.
- ⚠️ Les jeux dont l'**anti-triche est au niveau noyau** (Valorant, Fortnite, certains Call of Duty…) ne tournent pas sous Linux, sur aucune distribution.

### Si une mise à jour casse quelque chose
Redémarre → dans GRUB, ouvre le sous-menu des **snapshots Btrfs** et démarre un point d'avant la mise à jour (lecture seule). Tu peux aussi choisir **linux-lts** dans les options avancées. L'application **Btrfs Assistant** (si installée) permet de restaurer un snapshot.

---

## Le style « end-4 / end4-pC » (celui de TikTok)

**Ce que c'est.** [`end4-pC`](https://github.com/pctrade/end4-pC) est un *fork personnel* d'**illogical-impulse**, le bureau d'**end-4**
([`dots-hyprland`](https://github.com/end-4/dots-hyprland)) : **Hyprland** (fenêtres en mosaïque) + **Quickshell** (barre, panneaux,
vue d'ensemble des fenêtres, couleurs Material qui suivent ton fond d'écran, paroles, widgets…). Ce n'est **pas un OS** : c'est une
configuration qui se pose sur un Arch — donc compatible avec SeleneOS. KDE reste installé et sert de session de secours.

**Comment l'avoir.**
1. Pendant l'installation, réponds **o** à la question *« bureau end-4 »* : au premier démarrage, un terminal lance l'installateur officiel
   d'end-4 (20 à 60 min, des paquets AUR sont compilés). Tu peux aussi le faire plus tard avec `selene end4`.
2. Déconnecte-toi et choisis la session **Hyprland** sur l'écran de connexion.
3. Passe au style TikTok avec `selene end4 fork` (installe le fork et le met par défaut dans Hyprland). Pour juste l'essayer :
   `killall qs; qs -c end4-pC & disown`.

Raccourcis utiles : `Super + /` liste des raccourcis · `Super + Entrée` terminal · `Super` lanceur (tape `<` pour voir les raccourcis du fork).

**À savoir, honnêtement.**
- C'est un bureau **en mosaïque, pensé pour le clavier** : la prise en main est très différente de KDE.
- C'est une **cible mouvante** : Hyprland 0.55 a changé le format de sa configuration et cassé des installations ; ces dépôts sont tenus par des
  particuliers. Une mise à jour peut casser le bureau pendant quelques jours : garde KDE comme secours (les snapshots Btrfs aident aussi).
- Je n'ai pas pu tester cette installation sur ton PC : elle utilise le script officiel d'end-4 tel que je l'ai lu, pas une version modifiée.

**Pour voir le résultat dès maintenant**, il existe une ISO communautaire qui démarre directement sur le bureau end-4 :
[`El3ssar/illogical-impulse-iso`](https://github.com/El3ssar/illogical-impulse-iso) (non testée par moi ; Secure Boot à désactiver aussi).

---

## Dépannage (spécifique à ton modèle)

- **Wi-Fi (MediaTek MT7922, pilote `mt7921e`)** : des cas de Wi-Fi disparu après une mise à jour de `linux-firmware` ont été signalés sur ce Vivobook. Solution : revenir à un snapshot, ou réinstaller une ancienne version du paquet depuis `/var/cache/pacman/pkg`. En attendant : partage de connexion USB depuis un téléphone.
- **Son absent ou faible** : `sof-firmware` et `alsa-ucm-conf` sont déjà installés. Lance `wpctl status` et `sudo dmesg | grep -iE "audio|sof|snd"` et envoie-moi le résultat.
- **L'écran OLED scintille** : essaie de désactiver le PSR de l'AMD : dans `/etc/default/grub`, ajoute `amdgpu.dcdebugmask=0x10` à `GRUB_CMDLINE_LINUX_DEFAULT`, puis `sudo grub-mkconfig -o /boot/grub/grub.cfg`.
- **Windows n'apparaît pas dans GRUB** : `sudo grub-mkconfig -o /boot/grub/grub.cfg` après le premier démarrage.
- **Batterie** : Plasma propose une limite de charge (Paramètres → Gestion de l'énergie) si ton BIOS l'expose.
- **Le bureau n'a pas la bonne disposition / le bon thème** (compte existant) : `rm -rf ~/.config/kdedefaults ~/.config/plasma-org.kde.plasma.desktop-appletsrc` puis reconnecte-toi.

---

## Personnaliser

| Je veux… | Je modifie… |
|---|---|
| renommer l'OS | `distro.conf` |
| changer les couleurs | `overlay/system/usr/share/color-schemes/SeleneNight.colors` |
| changer le fond d'écran | `python3 tools/make-wallpaper.py` (ou remplace l'image dans `overlay/system/usr/share/wallpapers/SeleneNight/`) |
| changer la barre / le dock | `overlay/system/usr/share/plasma/look-and-feel/org.selene.night.desktop/contents/layouts/org.kde.plasma.desktop-layout.js` |
| ajouter/retirer des logiciels | `packages/*.txt` (un `?` devant le nom = optionnel) |
| régler le noyau / la mémoire | `overlay/system/etc/sysctl.d/99-selene.conf`, `etc/default/grub` |

Avant de reconstruire, `sudo bash tools/check-packages.sh` (sur Arch) vérifie que tous les paquets existent encore.

---

## Structure du projet

```
distro.conf            nom, identité, langue/clavier/fuseau par défaut
build.sh               construit l'ISO (profil archiso « releng » + nos ajouts)
packages/              listes de paquets : base, desktop, gaming, apps, iso
installer/             selene-install (disque, Btrfs, pacstrap) + selene-chroot.sh (config système)
overlay/system/        réglages appliqués au système installé ET au live (thème, sysctl, zram, SDDM, Game Mode…)
overlay/live/          réglages propres à l'ISO live (autologin, installateur sur le bureau)
tools/                 check-packages.sh, make-wallpaper.py
.github/workflows/     construction automatique de l'ISO sur GitHub
```

## Limites actuelles et pistes

- Pas de chiffrement du disque (LUKS) ni d'hibernation dans cette première version.
- **Secure Boot** non pris en charge.
- Le design « LunariaOS » n'a pas pu être retrouvé : l'identité visuelle est une interprétation (nuit lunaire, indigo/lavande, verre dépoli). Envoie une capture d'écran de ce que tu veux et j'ajuste couleurs, dock et fond.
- Le bureau end-4 est une option installée après coup (via l'installateur officiel) ; en faire le bureau **par défaut** dès l'installation demande de pré-compiler ses paquets AUR dans l'ISO (comme le fait l'ISO communautaire ci-dessus).
- Pistes pour aller plus loin : noyau **CachyOS** (BORE, optimisé Zen 4), écran de démarrage Plymouth, thème GRUB, installateur graphique (Calamares), profil HDR.
