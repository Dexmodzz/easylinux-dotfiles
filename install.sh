#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
#  noctalia-dotfiles — install.sh
#  Clone completo del sistema su CachyOS base
#  Basato su: https://github.com/Echilonvibin/minimaLinux
#
#  USO: sudo bash install.sh
#  REQUISITI: CachyOS installato (base o desktop), connessione internet
# ─────────────────────────────────────────────────────────────────────────────

export LC_MESSAGES=C
export LANG=C

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# ── Utility ───────────────────────────────────────────────────────────────────
append_unique_package() {
    local -n _list="$1"; local _pkg="$2"
    for _p in "${_list[@]}"; do [ "$_p" = "$_pkg" ] && return 0; done
    _list+=("$_pkg")
}

disable_colors() { unset ALL_OFF BOLD BLUE GREEN RED YELLOW CYAN MAGENTA; }
enable_colors() {
    if tput setaf 0 &>/dev/null; then
        ALL_OFF="$(tput sgr0)"; BOLD="$(tput bold)"
        RED="${BOLD}$(tput setaf 1)";    GREEN="${BOLD}$(tput setaf 2)"
        YELLOW="${BOLD}$(tput setaf 3)"; BLUE="${BOLD}$(tput setaf 4)"
        MAGENTA="${BOLD}$(tput setaf 5)"; CYAN="${BOLD}$(tput setaf 6)"
    else
        ALL_OFF="\e[0m"; BOLD="\e[1m"; RED="\e[1;31m"; GREEN="\e[1;32m"
        YELLOW="\e[1;33m"; BLUE="\e[1;34m"; MAGENTA="\e[1;35m"; CYAN="\e[1;36m"
    fi
    readonly ALL_OFF BOLD BLUE GREEN RED YELLOW CYAN MAGENTA
}
[[ -t 2 ]] && enable_colors || disable_colors

msg()     { printf "${GREEN}▶${ALL_OFF}${BOLD} %s${ALL_OFF}\n" "$*" >&2; }
info()    { printf "${YELLOW}  • %s${ALL_OFF}\n" "$*" >&2; }
warn()    { printf "${YELLOW}  ⚠ %s${ALL_OFF}\n" "$*" >&2; }
error()   { printf "${RED}  ✗ %s${ALL_OFF}\n" "$*" >&2; }
section() { echo ""; printf "${CYAN}${BOLD}══════════════════════════════════════════\n  %s\n══════════════════════════════════════════${ALL_OFF}\n" "$*"; echo ""; }

# ── Banner ────────────────────────────────────────────────────────────────────
printf "${CYAN}${BOLD}"
cat << 'EOF'

  ███╗   ██╗ ██████╗  ██████╗████████╗ █████╗ ██╗     ██╗ █████╗
  ████╗  ██║██╔═══██╗██╔════╝╚══██╔══╝██╔══██╗██║     ██║██╔══██╗
  ██╔██╗ ██║██║   ██║██║        ██║   ███████║██║     ██║███████║
  ██║╚██╗██║██║   ██║██║        ██║   ██╔══██║██║     ██║██╔══██║
  ██║ ╚████║╚██████╔╝╚██████╗   ██║   ██║  ██║███████╗██║██║  ██║
  ╚═╝  ╚═══╝ ╚═════╝  ╚═════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝╚═╝  ╚═╝

     Clone completo — CachyOS · KDE · Hyprland · Noctalia Shell
EOF
printf "${ALL_OFF}\n"

# ── Controlli preliminari ─────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && { echo "Esegui con: sudo bash install.sh"; exit 1; }
[ ! -f /etc/pacman.conf ] && { echo "ERRORE: /etc/pacman.conf non trovato."; exit 1; }
[ ! -d "$SCRIPT_DIR/.config" ] && { echo "ERRORE: cartella .config non trovata in $SCRIPT_DIR"; exit 1; }

# Ricava l'utente reale
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    ACTUAL_USER="$SUDO_USER"
else
    ACTUAL_USER=$(logname 2>/dev/null)
fi
[ -z "$ACTUAL_USER" ] || [ "$ACTUAL_USER" = "root" ] && {
    echo "ERRORE: impossibile determinare l'utente non-root. Usa: sudo bash install.sh"
    exit 1
}
ACTUAL_USER_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)
[ -z "$ACTUAL_USER_HOME" ] && { echo "ERRORE: home di $ACTUAL_USER non trovata."; exit 1; }

CONFIG_DIR="$ACTUAL_USER_HOME/.config"
DDCUTIL_ENABLED=0

echo ""
info "Utente: $ACTUAL_USER  |  Home: $ACTUAL_USER_HOME"
echo ""
echo "Questo script installa un clone completo del sistema (CachyOS + KDE + Hyprland + Noctalia)."
warn "Usare SOLO su una installazione fresca di CachyOS. Procedere a proprio rischio."
echo ""
while true; do
    read -r -p "Vuoi procedere? (s/n): " proceed
    case "$proceed" in s|S|y|Y) break ;; n|N) echo "Annullato."; exit 0 ;; *) echo "s o n." ;; esac
done

# ═════════════════════════════════════════════════════════════════════════════
section "Selezioni interattive"
# ═════════════════════════════════════════════════════════════════════════════

# GPU
GPU_MODE="none"
echo "Tipo di GPU:"
echo "  1. NVIDIA (driver proprietari nvidia-open, per kernel CachyOS)"
echo "  2. AMD   (driver open, già inclusi nel kernel)"
echo "  3. Intel (driver open, già inclusi)"
echo "  4. Salta / gestione manuale"
while true; do
    read -r -p "Scelta (1-4): " gpu_choice
    case "$gpu_choice" in
        1) GPU_MODE="nvidia"; break ;;
        2) GPU_MODE="amd";    break ;;
        3) GPU_MODE="intel";  break ;;
        4) GPU_MODE="none";   break ;;
        *) echo "1-4." ;;
    esac
done

# Stampante
INSTALL_PRINTER=0
echo ""
read -r -p "Supporto stampante? (s/n): " c
[[ "$c" =~ ^[sSyY]$ ]] && INSTALL_PRINTER=1

# Bluetooth
INSTALL_BT=0
echo ""
read -r -p "Bluetooth? (s/n): " c
[[ "$c" =~ ^[sSyY]$ ]] && INSTALL_BT=1

# Audio
AUDIO_MODE="easyeffects"
echo ""
echo "Audio:  0.Salta  1.EasyEffects(default)  2.Dolby Atmos"
read -r -p "Scelta: " c
case "$c" in 0) AUDIO_MODE="none" ;; 2) AUDIO_MODE="dolby" ;; *) AUDIO_MODE="easyeffects" ;; esac

# Gaming
GAMING_PKGS=()
echo ""
echo "Gaming (virgola/spazio, a=tutti, 0=salta):"
echo "  1.steam  2.mangohud  3.protonplus  4.wine  5.winetricks  6.protontricks"
echo "  7.lutris  8.heroic  9.prismlauncher  10.goverlay  11.mangojuice"
read -r -p "Scelta: " gaming_choices
if [ -n "$gaming_choices" ] && [ "$gaming_choices" != "0" ]; then
    [[ "$gaming_choices" =~ ^[aA]$ ]] && gaming_choices="1 2 3 4 5 6 7 8 9 10 11"
    gaming_choices=$(echo "$gaming_choices" | tr ',' ' ')
    for c in $gaming_choices; do
        case "$c" in
            1)  append_unique_package GAMING_PKGS steam ;;
            2)  append_unique_package GAMING_PKGS mangohud; append_unique_package GAMING_PKGS lib32-mangohud ;;
            3)  append_unique_package GAMING_PKGS protonplus ;;
            4)  append_unique_package GAMING_PKGS wine ;;
            5)  append_unique_package GAMING_PKGS winetricks ;;
            6)  append_unique_package GAMING_PKGS protontricks ;;
            7)  append_unique_package GAMING_PKGS lutris ;;
            8)  append_unique_package GAMING_PKGS heroic-games-launcher-bin ;;
            9)  append_unique_package GAMING_PKGS prismlauncher; append_unique_package GAMING_PKGS jdk21-openjdk ;;
            10) append_unique_package GAMING_PKGS goverlay ;;
            11) append_unique_package GAMING_PKGS mangojuice ;;
        esac
    done
fi

# Player AV
AV_PKGS=()
echo ""
echo "Player audio/video (a=tutti, 0=salta):  1.mpv  2.vlc  3.haruna  4.deadbeef  5.rhythmbox"
read -r -p "Scelta: " av_choices
if [ -n "$av_choices" ] && [ "$av_choices" != "0" ]; then
    [[ "$av_choices" =~ ^[aA]$ ]] && av_choices="1 2 3 4 5"
    av_choices=$(echo "$av_choices" | tr ',' ' ')
    for c in $av_choices; do
        case "$c" in
            1) append_unique_package AV_PKGS mpv ;;
            2) append_unique_package AV_PKGS vlc ;;
            3) append_unique_package AV_PKGS haruna ;;
            4) append_unique_package AV_PKGS deadbeef ;;
            5) append_unique_package AV_PKGS rhythmbox ;;
        esac
    done
fi

# Browser
BROWSER=0
echo ""
echo "Browser:  1.Brave  2.Firefox  3.LibreWolf  4.Vivaldi  5.Zen  0.Salta"
read -r -p "Scelta: " c
case "$c" in 1) BROWSER=1 ;; 2) BROWSER=2 ;; 3) BROWSER=3 ;; 4) BROWSER=4 ;; 5) BROWSER=5 ;; *) BROWSER=0 ;; esac

# ddcutil
INSTALL_DDCUTIL=0
echo ""
read -r -p "ddcutil (controllo luminosità monitor DDC/CI)? (s/n): " c
[[ "$c" =~ ^[sSyY]$ ]] && INSTALL_DDCUTIL=1

# ═════════════════════════════════════════════════════════════════════════════
# LISTA PACCHETTI — esportata dal sistema originale con: pacman -Qqe
# ═════════════════════════════════════════════════════════════════════════════
PACKAGES=(
    # Base sistema
    base base-devel sudo vim nano less wget which
    man-db man-pages texinfo logrotate s-nail perl python

    # Filesystem
    btrfs-progs cryptsetup device-mapper e2fsprogs efibootmgr efitools
    f2fs-tools jfsutils lvm2 mdadm mkinitcpio ntfs-3g dosfstools exfatprogs xfsprogs

    # Boot
    limine limine-mkinitcpio-hook update-grub os-prober plymouth

    # Rete
    networkmanager networkmanager-openvpn iwd wpa_supplicant wireless_tools
    modemmanager bind dnsmasq nfs-utils inetutils ethtool

    # Audio (base)
    pipewire-alsa pipewire-pulse wireplumber alsa-firmware alsa-plugins alsa-utils
    pavucontrol playerctl wlsunset

    # KDE Plasma
    plasma-desktop plasma-login-manager plasma-nm plasma-pa
    kscreen kwalletmanager kwallet-pam

    # Hyprland
    hyprland hyprland-protocols hyprlock hypridle hyprshot uwsm
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk

    # Shell e terminale
    fish bash-completion kitty starship fastfetch

    # Temi e aspetto
    adw-gtk-theme bibata-cursor-theme yaru-icon-theme humanity-icon-theme
    qt6ct qt5-wayland qt6-wayland
    noto-fonts noto-fonts-cjk noto-fonts-emoji
    ttf-dejavu ttf-liberation ttf-bitstream-vera ttf-meslo-nerd
    ttf-ms-fonts ttf-opensans ttf-symbola cantarell-fonts
    awesome-terminal-fonts

    # Screenshot e utilità Wayland
    grim slurp satty wofi

    # File manager
    thunar thunar-archive-plugin thunar-media-tags-plugin
    thunar-shares-plugin thunar-vcs-plugin thunar-volman
    tumbler ffmpegthumbnailer libopenraw libgsf poppler-glib
    libgepub freetype2 ark file-roller
    gvfs gvfs-afc gvfs-mtp gvfs-smb

    # App desktop
    gedit vim loupe gnome-calculator gnome-disk-utility
    nwg-look nwg-displays gcolor3 pinta
    flatpak xdg-user-dirs

    # Sistema e strumenti
    gnome-keyring polkit-gnome power-profiles-daemon cpupower upower
    smartmontools sysfsutils usb_modeswitch usbutils
    lsb-release reflector

    # Build / sviluppo
    clang cmake go rust meson ninja pkgconf

    # Archivi
    unrar unzip 7zip

    # Media / codec
    gst-plugins-good gst-plugins-ugly gst-libav gst-plugin-va

    # Bluetooth (base, il servizio verrà abilitato dopo)
    bluez bluez-libs

    # Aspell / dizionari
    aspell hspell libvoikko nuspell

    # Misc
    cava matugen gpu-screen-recorder mission-center
    dunst

    # CachyOS specifici
    cachyos-hello cachyos-hooks cachyos-keyring cachyos-mirrorlist
    cachyos-packageinstaller cachyos-plymouth-bootanimation cachyos-plymouth-theme
    cachyos-rate-mirrors cachyos-settings cachyos-v3-mirrorlist cachyos-v4-mirrorlist
    chaotic-keyring chaotic-mirrorlist chwd
)

# GPU
case "$GPU_MODE" in
    nvidia)
        PACKAGES+=(
            linux-cachyos-bore-nvidia-open
            nvidia-utils lib32-nvidia-utils
            opencl-nvidia lib32-opencl-nvidia
            nvidia-settings libva-nvidia-driver
            lib32-vulkan-icd-loader vulkan-icd-loader
        )
        ;;
    amd)
        PACKAGES+=(
            mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon
            libva-mesa-driver lib32-libva-mesa-driver
            mesa-vdpau lib32-mesa-vdpau vulkan-icd-loader lib32-vulkan-icd-loader
        )
        ;;
    intel)
        PACKAGES+=(
            intel-ucode intel-media-sdk libva-intel-driver-irql
            vulkan-intel lib32-vulkan-intel
            lib32-vulkan-icd-loader vulkan-icd-loader
        )
        ;;
esac

# Bluetooth completo
[ "$INSTALL_BT" -eq 1 ] && PACKAGES+=(bluez-hid2hci bluez-obex bluez-utils blueman)

# Audio extra
[ "$AUDIO_MODE" = "easyeffects" ] && PACKAGES+=(easyeffects lsp-plugins-lv2 calf)

# Stampante
[ "$INSTALL_PRINTER" -eq 1 ] && PACKAGES+=(
    cups cups-filters cups-pdf hplip gutenprint system-config-printer
    foomatic-db foomatic-db-engine foomatic-db-gutenprint-ppds
    foomatic-db-nonfree foomatic-db-nonfree-ppds foomatic-db-ppds
    python-pyqt5 python-pyqt6 python-reportlab
)

# ═════════════════════════════════════════════════════════════════════════════
section "Installazione pacchetti"
# ═════════════════════════════════════════════════════════════════════════════

msg "Aggiorno il sistema..."
pacman -Syu --noconfirm || { echo "ERRORE: aggiornamento fallito."; exit 1; }

msg "Installo tutti i pacchetti core..."
pacman -S --needed --noconfirm "${PACKAGES[@]}" || {
    warn "Alcuni pacchetti non trovati nei repo. Riprovo ignorando gli errori..."
    for pkg in "${PACKAGES[@]}"; do
        pacman -S --needed --noconfirm "$pkg" 2>/dev/null || warn "Non trovato: $pkg"
    done
}

# Gaming
[ ${#GAMING_PKGS[@]} -gt 0 ] && {
    msg "Installo pacchetti gaming..."
    pacman -S --needed --noconfirm "${GAMING_PKGS[@]}" || true
}

# Player AV
[ ${#AV_PKGS[@]} -gt 0 ] && {
    msg "Installo player audio/video..."
    pacman -S --needed --noconfirm "${AV_PKGS[@]}" || true
}

# ═════════════════════════════════════════════════════════════════════════════
section "Pacchetti AUR con yay"
# ═════════════════════════════════════════════════════════════════════════════

# Installa yay se non presente (su CachyOS di solito è già installato)
if ! command -v yay &>/dev/null; then
    msg "Installo yay..."
    pacman -S --needed --noconfirm git base-devel
    sudo -u "$ACTUAL_USER" git clone https://aur.archlinux.org/yay.git /tmp/yay-build
    (cd /tmp/yay-build && sudo -u "$ACTUAL_USER" makepkg -si --noconfirm)
    rm -rf /tmp/yay-build
fi

msg "Installo noctalia-shell, noctalia-qs e vscodium..."
sudo -u "$ACTUAL_USER" yay -S --needed --noconfirm \
    noctalia-shell noctalia-qs vscodium || warn "Alcuni AUR packages falliti."

# Browser via AUR/repo
case "$BROWSER" in
    1) msg "Installo Brave...";      pacman -S --noconfirm brave-bin        2>/dev/null || sudo -u "$ACTUAL_USER" yay -S --noconfirm brave-origin-nightly-bin ;;
    2) msg "Installo Firefox...";    pacman -S --noconfirm firefox ;;
    3) msg "Installo LibreWolf...";  sudo -u "$ACTUAL_USER" yay -S --noconfirm librewolf ;;
    4) msg "Installo Vivaldi...";    pacman -S --noconfirm vivaldi ;;
    5) msg "Installo Zen Browser..."; sudo -u "$ACTUAL_USER" yay -S --noconfirm zen-browser-bin ;;
    *) info "Browser saltato." ;;
esac

# ═════════════════════════════════════════════════════════════════════════════
section "Servizi di sistema"
# ═════════════════════════════════════════════════════════════════════════════

msg "Abilito servizi..."
systemctl enable NetworkManager
systemctl enable power-profiles-daemon
systemctl enable cups 2>/dev/null || true
[ "$INSTALL_BT" -eq 1 ] && systemctl enable bluetooth

# Plymouth
systemctl enable plymouth-quit-wait.service 2>/dev/null || true

# ═════════════════════════════════════════════════════════════════════════════
section "ddcutil"
# ═════════════════════════════════════════════════════════════════════════════

if [ "$INSTALL_DDCUTIL" -eq 1 ]; then
    msg "Installo e configuro ddcutil..."
    pacman -S --noconfirm --needed ddcutil || true
    sudo -u "$ACTUAL_USER" yay -S --noconfirm --needed ddcutil-service || true
    modprobe i2c-dev || true
    echo "i2c-dev" > /etc/modules-load.d/i2c-dev.conf
    udevadm control --reload-rules; udevadm trigger
    usermod -aG i2c "$ACTUAL_USER" || true
    DDCUTIL_ENABLED=1
fi

# ═════════════════════════════════════════════════════════════════════════════
section "Deploy dotfiles"
# ═════════════════════════════════════════════════════════════════════════════

CONFIG_SRC="$SCRIPT_DIR/.config"
sudo -u "$ACTUAL_USER" mkdir -p "$CONFIG_DIR"

# Backup
BACKUP_TS=$(date +%s)
msg "Backup configurazioni esistenti..."
for item in "$CONFIG_SRC"/*/; do
    name=$(basename "$item")
    target="$CONFIG_DIR/$name"
    [ -e "$target" ] && {
        mv "$target" "$CONFIG_DIR/${name}.bak.${BACKUP_TS}"
        info "Backup: $name"
    }
done
# Backup anche file singoli nella root .config
for f in "$CONFIG_SRC"/*.{toml,ini,conf,json,jsonc} 2>/dev/null; do
    [ -f "$f" ] || continue
    name=$(basename "$f")
    target="$CONFIG_DIR/$name"
    [ -e "$target" ] && mv "$target" "$CONFIG_DIR/${name}.bak.${BACKUP_TS}"
done

msg "Copio tutti i dotfiles..."
cp -rf "$CONFIG_SRC"/. "$CONFIG_DIR"/
chown -R "$ACTUAL_USER:$ACTUAL_USER" "$CONFIG_DIR"

# Fix path assoluto qt6ct.conf
if [ -f "$CONFIG_DIR/qt6ct/qt6ct.conf" ]; then
    sed -i "s|__HOME__|$ACTUAL_USER_HOME|g" "$CONFIG_DIR/qt6ct/qt6ct.conf"
    chown "$ACTUAL_USER:$ACTUAL_USER" "$CONFIG_DIR/qt6ct/qt6ct.conf"
    info "Path qt6ct aggiornato"
fi

# monitors.conf: crea un placeholder se non esiste
if [ ! -f "$CONFIG_DIR/hypr/monitors.conf" ]; then
    sudo -u "$ACTUAL_USER" tee "$CONFIG_DIR/hypr/monitors.conf" >/dev/null << 'MONEOF'
# Configura i tuoi monitor qui.
# Esempio: monitor=DP-1,1920x1080@144,0x0,1
# Vedi: https://wiki.hyprland.org/Configuring/Monitors/
monitor=,preferred,auto,1
MONEOF
    info "monitors.conf placeholder creato — configuralo con i tuoi monitor"
fi

# DDC in noctalia settings
[ "$DDCUTIL_ENABLED" -eq 1 ] && [ -f "$CONFIG_DIR/noctalia/settings.json" ] && {
    python3 - "$CONFIG_DIR/noctalia/settings.json" <<'PY'
import json, sys
p = sys.argv[1]
with open(p) as f: d = json.load(f)
d.setdefault("brightness", {})["enableDdcSupport"] = True
with open(p, "w") as f: json.dump(d, f, indent=4); f.write("\n")
PY
    chown "$ACTUAL_USER:$ACTUAL_USER" "$CONFIG_DIR/noctalia/settings.json"
}

msg "Permessi script hyprland..."
[ -d "$CONFIG_DIR/hypr/Scripts" ] && find "$CONFIG_DIR/hypr/Scripts" -type f -exec chmod +x {} \;

# ═════════════════════════════════════════════════════════════════════════════
section "Tema GTK e Qt"
# ═════════════════════════════════════════════════════════════════════════════

if command -v gsettings &>/dev/null; then
    sudo -u "$ACTUAL_USER" gsettings set org.gnome.desktop.interface gtk-theme    'adw-gtk3-dark'
    sudo -u "$ACTUAL_OFF" gsettings set org.gnome.desktop.interface icon-theme   'Yaru-blue-dark'
    sudo -u "$ACTUAL_USER" gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Classic'
    sudo -u "$ACTUAL_USER" gsettings set org.gnome.desktop.interface cursor-size  24
    sudo -u "$ACTUAL_USER" gsettings set org.gnome.desktop.interface font-name    'Adwaita Sans 11'
    sudo -u "$ACTUAL_USER" gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    msg "gsettings applicati"
fi

# Variabili Qt
ENV_FILE="$ACTUAL_USER_HOME/.config/environment.d/qt-theme.conf"
sudo -u "$ACTUAL_USER" mkdir -p "$(dirname "$ENV_FILE")"
[ ! -f "$ENV_FILE" ] && sudo -u "$ACTUAL_USER" tee "$ENV_FILE" >/dev/null << 'ENV'
QT_QPA_PLATFORMTHEME=qt6ct
QT_STYLE_OVERRIDE=Breeze
ENV

# ═════════════════════════════════════════════════════════════════════════════
section "Thunar e directory utente"
# ═════════════════════════════════════════════════════════════════════════════

sudo -u "$ACTUAL_USER" xdg-user-dirs-update || true
sudo -u "$ACTUAL_USER" xdg-mime default thunar.desktop inode/directory application/x-gnome-saved-search 2>/dev/null || true

BM="$ACTUAL_USER_HOME/.config/gtk-3.0/bookmarks"
sudo -u "$ACTUAL_USER" mkdir -p "$(dirname "$BM")"
sudo -u "$ACTUAL_USER" tee "$BM" >/dev/null << EOF
file://$ACTUAL_USER_HOME/Documents
file://$ACTUAL_USER_HOME/Downloads
file://$ACTUAL_USER_HOME/Pictures
file://$ACTUAL_USER_HOME/Music
file://$ACTUAL_USER_HOME/Videos
file://$ACTUAL_USER_HOME/.config/hypr
EOF

# Profilo Dolby
[ "$AUDIO_MODE" = "dolby" ] && [ -d "$SCRIPT_DIR/pipewire" ] && {
    sudo -u "$ACTUAL_USER" mkdir -p "$CONFIG_DIR/pipewire"
    cp -rf "$SCRIPT_DIR/pipewire/"* "$CONFIG_DIR/pipewire/"
    chown -R "$ACTUAL_USER:$ACTUAL_USER" "$CONFIG_DIR/pipewire"
    msg "Profilo Dolby PipeWire applicato"
}

# ═════════════════════════════════════════════════════════════════════════════
section "✔  Installazione completata!"
# ═════════════════════════════════════════════════════════════════════════════

printf "${GREEN}${BOLD}Tutto installato e configurato.${ALL_OFF}\n\n"
printf "${CYAN}Note importanti:${ALL_OFF}\n"
printf "  • ${YELLOW}monitors.conf${ALL_OFF} è un placeholder: configuralo con la risoluzione del tuo monitor\n"
printf "      nano %s/hypr/monitors.conf\n" "$CONFIG_DIR"
printf "  • Se usi NVIDIA, verifica che il kernel corretto sia attivo:\n"
printf "      uname -r  (deve contenere 'cachyos' o 'bore')\n"
printf "  • Verifica che hyprland.conf includa:\n"
printf "      ${YELLOW}source = ~/.config/hypr/themes/theme.conf${ALL_OFF}\n"
printf "      ${YELLOW}source = ~/.config/hypr/noctalia/noctalia-colors.conf${ALL_OFF}\n\n"

while true; do
    read -r -p "Riavviare ora? (s/n): " r
    case "$r" in
        s|S|y|Y) echo "Riavvio..."; reboot now; break ;;
        n|N) printf "\n${YELLOW}Ricordati di riavviare!${ALL_OFF}\n"; break ;;
        *) echo "s o n." ;;
    esac
done
