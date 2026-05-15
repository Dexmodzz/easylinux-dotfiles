#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
#  noctalia-dotfiles — install.sh
#  Clone completo del sistema su CachyOS base
#  Basato su: https://github.com/Echilonvibin/minimaLinux
#
#  USO:          sudo bash install.sh
#  DRY-RUN:      sudo bash install.sh --dry-run
#  REQUISITI:    CachyOS installato (base o desktop), connessione internet
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Timer ─────────────────────────────────────────────────────────────────────
START_TIME=$(date +%s)

export LC_MESSAGES=C
export LANG=C

# ── Dry-run flag ──────────────────────────────────────────────────────────────
DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

# ── Log file ──────────────────────────────────────────────────────────────────
LOG_FILE="/tmp/noctalia-install-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# ── Tracking variabili per checklist finale ───────────────────────────────────
STATUS_PKGS=0       # 1=ok 2=warn
STATUS_AUR=0
STATUS_SERVICES=0
STATUS_FLATHUB=0
STATUS_DDCUTIL=0
STATUS_DOTFILES=0
STATUS_GTK=0

# ── Utility ───────────────────────────────────────────────────────────────────
append_unique_package() {
    local -n _list="$1"; local _pkg="$2"
    for _p in "${_list[@]+"${_list[@]}"}"; do [ "$_p" = "$_pkg" ] && return 0; done
    _list+=("$_pkg")
}

# Wrapper per dry-run
run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        printf "${YELLOW}  [DRY-RUN]${ALL_OFF} %s\n" "$*" >&2
    else
        "$@"
    fi
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

msg()   { printf "${GREEN}▶${ALL_OFF}${BOLD} %s${ALL_OFF}\n" "$*" >&2; }
info()  { printf "${YELLOW}  • %s${ALL_OFF}\n" "$*" >&2; }
warn()  { printf "${YELLOW}  ⚠ %s${ALL_OFF}\n" "$*" >&2; }
error() { printf "${RED}  ✗ %s${ALL_OFF}\n" "$*" >&2; }

# section STEP TOTAL TITLE  oppure  section TITLE (senza numerazione)
section() {
    if [ "$#" -eq 3 ]; then
        echo ""
        printf "${CYAN}${BOLD}══════════════════════════════════════════\n  [%s/%s] %s\n══════════════════════════════════════════${ALL_OFF}\n" "$1" "$2" "$3"
        echo ""
    else
        echo ""
        printf "${CYAN}${BOLD}══════════════════════════════════════════\n  %s\n══════════════════════════════════════════${ALL_OFF}\n" "$1"
        echo ""
    fi
}

# Barra di progresso: progress_bar CURRENT TOTAL [LABEL]
progress_bar() {
    local current=$1 total=$2 label="${3:-}"
    local width=38
    local filled=$(( total > 0 ? current * width / total : 0 ))
    local empty=$(( width - filled ))
    local pct=$(( total > 0 ? current * 100 / total : 0 ))
    local bar=""
    local i
    for (( i=0; i<filled; i++ )); do bar+="█"; done
    for (( i=0; i<empty;  i++ )); do bar+="░"; done
    printf "\r${CYAN}  [%s] %3d%%${ALL_OFF}  %s" "$bar" "$pct" "$label" >&2
}

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

[ "$DRY_RUN" -eq 1 ] && printf "${YELLOW}${BOLD}  *** MODALITÀ DRY-RUN: nessuna modifica verrà applicata ***${ALL_OFF}\n\n"
info "Log: $LOG_FILE"
echo ""

# ── Controlli preliminari ─────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && { echo "Esegui con: sudo bash install.sh"; exit 1; }
[ ! -f /etc/pacman.conf ]      && { echo "ERRORE: /etc/pacman.conf non trovato."; exit 1; }
[ ! -d "$SCRIPT_DIR/.config" ] && { echo "ERRORE: cartella .config non trovata in $SCRIPT_DIR"; exit 1; }

msg "Verifico connessione internet..."
if ! ping -c1 -W3 archlinux.org &>/dev/null; then
    echo "ERRORE: nessuna connessione internet. Controlla la rete e riprova."
    exit 1
fi
info "Connessione OK"

msg "Verifico spazio disco..."
FREE_KB=$(df / --output=avail | tail -1)
FREE_GB=$(( FREE_KB / 1024 / 1024 ))
if [ "$FREE_GB" -lt 10 ]; then
    echo "ERRORE: spazio libero insufficiente su / (${FREE_GB}GB disponibili, minimi 10GB)."
    exit 1
fi
info "Spazio disco OK: ${FREE_GB}GB liberi"

# Ricava l'utente reale
if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    ACTUAL_USER="$SUDO_USER"
else
    ACTUAL_USER=$(logname 2>/dev/null || true)
fi
{ [ -z "${ACTUAL_USER:-}" ] || [ "$ACTUAL_USER" = "root" ]; } && {
    echo "ERRORE: impossibile determinare l'utente non-root. Usa: sudo bash install.sh"
    exit 1
}
ACTUAL_USER_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)
[ -z "$ACTUAL_USER_HOME" ] && { echo "ERRORE: home di $ACTUAL_USER non trovata."; exit 1; }

CONFIG_DIR="$ACTUAL_USER_HOME/.config"
DDCUTIL_ENABLED=0
INSTALL_COSMIC_STORE=0

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

# ── GPU ───────────────────────────────────────────────────────────────────────
GPU_MODE="none"
echo "Tipo di GPU:"
echo "  1. NVIDIA  (driver proprietari nvidia-open, per kernel CachyOS)"
echo "  2. AMD     (driver open, inclusi nel kernel)"
echo "  3. Intel   (driver open, inclusi nel kernel)"
echo "  4. Salta   (gestione manuale)"
while true; do
    read -r -p "Scelta (1-4): " gpu_choice
    case "$gpu_choice" in
        1) GPU_MODE="nvidia"; break ;;
        2) GPU_MODE="amd";    break ;;
        3) GPU_MODE="intel";  break ;;
        4) GPU_MODE="none";   break ;;
        *) echo "Inserisci un numero da 1 a 4." ;;
    esac
done

# ── Stampante ─────────────────────────────────────────────────────────────────
INSTALL_PRINTER=0
echo ""
echo "Supporto stampante:"
echo "  1. Sì"
echo "  2. No"
while true; do
    read -r -p "Scelta (1-2): " c
    case "$c" in 1) INSTALL_PRINTER=1; break ;; 2) break ;; *) echo "1 o 2." ;; esac
done

# ── Bluetooth ─────────────────────────────────────────────────────────────────
INSTALL_BT=0
echo ""
echo "Bluetooth:"
echo "  1. Sì  (installa bluez, blueman, abilita servizio)"
echo "  2. No"
while true; do
    read -r -p "Scelta (1-2): " c
    case "$c" in 1) INSTALL_BT=1; break ;; 2) break ;; *) echo "1 o 2." ;; esac
done

# ── Audio ─────────────────────────────────────────────────────────────────────
AUDIO_MODE="easyeffects"
echo ""
echo "Audio:"
echo "  0. Salta"
echo "  1. EasyEffects  (default, equalizzatore e effetti)"
echo "  2. Dolby Atmos  (profilo PipeWire surround)"
while true; do
    read -r -p "Scelta (0-2): " c
    case "$c" in
        0) AUDIO_MODE="none";           break ;;
        1|"") AUDIO_MODE="easyeffects"; break ;;
        2) AUDIO_MODE="dolby";          break ;;
        *) echo "0, 1 o 2." ;;
    esac
done

# ── Gaming ────────────────────────────────────────────────────────────────────
GAMING_PKGS=()
echo ""
echo "Pacchetti Gaming (separati da virgola/spazio, a=tutti, 0=salta):"
echo "   1. steam"
echo "   2. mangohud"
echo "   3. protonplus"
echo "   4. wine"
echo "   5. winetricks"
echo "   6. protontricks"
echo "   7. lutris"
echo "   8. heroic-games-launcher-bin"
echo "   9. prismlauncher"
echo "  10. goverlay"
echo "  11. mangojuice"
echo "   a. Installa tutti"
echo "   0. Salta"
read -r -p "Scelta: " gaming_choices
if [ -n "$gaming_choices" ] && [ "$gaming_choices" != "0" ]; then
    [[ "$gaming_choices" =~ ^[aA]$ ]] && gaming_choices="1 2 3 4 5 6 7 8 9 10 11"
    gaming_choices=$(echo "$gaming_choices" | tr ',' ' ')
    for c in $gaming_choices; do
        case "$c" in
            1)  append_unique_package GAMING_PKGS steam ;;
            2)  append_unique_package GAMING_PKGS mangohud
                append_unique_package GAMING_PKGS lib32-mangohud ;;
            3)  append_unique_package GAMING_PKGS protonplus ;;
            4)  append_unique_package GAMING_PKGS wine ;;
            5)  append_unique_package GAMING_PKGS winetricks ;;
            6)  append_unique_package GAMING_PKGS protontricks ;;
            7)  append_unique_package GAMING_PKGS lutris ;;
            8)  append_unique_package GAMING_PKGS heroic-games-launcher-bin ;;
            9)  append_unique_package GAMING_PKGS prismlauncher
                append_unique_package GAMING_PKGS jdk21-openjdk ;;
            10) append_unique_package GAMING_PKGS goverlay ;;
            11) append_unique_package GAMING_PKGS mangojuice ;;
        esac
    done
fi

# ── Player Audio/Video ────────────────────────────────────────────────────────
AV_PKGS=()
echo ""
echo "Player Audio/Video (separati da virgola/spazio, a=tutti, 0=salta):"
echo "  1. mpv        (leggero, riga di comando)"
echo "  2. vlc        (versatile)"
echo "  3. haruna     (KDE, moderno)"
echo "  4. deadbeef   (musica, modulare)"
echo "  5. rhythmbox  (GNOME, musica)"
echo "  a. Installa tutti"
echo "  0. Salta"
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

# ── Browser ───────────────────────────────────────────────────────────────────
BROWSER=0
echo ""
echo "Browser:"
echo "  1. Brave"
echo "  2. Firefox"
echo "  3. LibreWolf"
echo "  4. Vivaldi"
echo "  5. Zen Browser"
echo "  0. Salta"
while true; do
    read -r -p "Scelta (0-5): " c
    case "$c" in 0|1|2|3|4|5) BROWSER=$c; break ;; *) echo "0-5." ;; esac
done

# ── Cosmic Store ──────────────────────────────────────────────────────────────
echo ""
echo "Cosmic Store (app store Flatpak con interfaccia grafica moderna):"
echo "  1. Sì  (installa cosmic-store, configura Flathub con permessi completi)"
echo "  2. No"
while true; do
    read -r -p "Scelta (1-2): " c
    case "$c" in 1) INSTALL_COSMIC_STORE=1; break ;; 2) break ;; *) echo "1 o 2." ;; esac
done

# ── ddcutil ───────────────────────────────────────────────────────────────────
INSTALL_DDCUTIL=0
echo ""
echo "ddcutil (controllo luminosità monitor via DDC/CI):"
echo "  1. Sì"
echo "  2. No"
while true; do
    read -r -p "Scelta (1-2): " c
    case "$c" in 1) INSTALL_DDCUTIL=1; break ;; 2) break ;; *) echo "1 o 2." ;; esac
done

# ── Box riepilogo scelte ───────────────────────────────────────────────────────
_gpu_label="Salta (manuale)"
case "$GPU_MODE" in nvidia) _gpu_label="NVIDIA (nvidia-open)" ;; amd) _gpu_label="AMD (mesa/vulkan)" ;; intel) _gpu_label="Intel (vulkan-intel)" ;; esac

_browser_label="Salta"
case "$BROWSER" in 1) _browser_label="Brave" ;; 2) _browser_label="Firefox" ;; 3) _browser_label="LibreWolf" ;; 4) _browser_label="Vivaldi" ;; 5) _browser_label="Zen Browser" ;; esac

_audio_label="Salta"
case "$AUDIO_MODE" in easyeffects) _audio_label="EasyEffects" ;; dolby) _audio_label="Dolby Atmos" ;; esac

_gaming_label="Nessuno"
[ "${#GAMING_PKGS[@]}" -gt 0 ] && _gaming_label="${GAMING_PKGS[*]}"

_bt_label="No";      [ "$INSTALL_BT"      -eq 1 ] && _bt_label="Sì"
_printer_label="No"; [ "$INSTALL_PRINTER"  -eq 1 ] && _printer_label="Sì"
_ddcutil_label="No"; [ "$INSTALL_DDCUTIL"  -eq 1 ] && _ddcutil_label="Sì"
_cosmic_label="No";  [ "$INSTALL_COSMIC_STORE" -eq 1 ] && _cosmic_label="Sì"

echo ""
printf "${CYAN}${BOLD}╔══════════════════════════════════════════════╗${ALL_OFF}\n"
printf "${CYAN}${BOLD}║       RIEPILOGO INSTALLAZIONE                ║${ALL_OFF}\n"
printf "${CYAN}${BOLD}╠══════════════════════════════════════════════╣${ALL_OFF}\n"
printf "${CYAN}${BOLD}║${ALL_OFF}  %-12s ${CYAN}│${ALL_OFF} %-30s ${CYAN}${BOLD}║${ALL_OFF}\n" "GPU"        "$_gpu_label"
printf "${CYAN}${BOLD}║${ALL_OFF}  %-12s ${CYAN}│${ALL_OFF} %-30s ${CYAN}${BOLD}║${ALL_OFF}\n" "Browser"    "$_browser_label"
printf "${CYAN}${BOLD}║${ALL_OFF}  %-12s ${CYAN}│${ALL_OFF} %-30s ${CYAN}${BOLD}║${ALL_OFF}\n" "Audio"      "$_audio_label"
printf "${CYAN}${BOLD}║${ALL_OFF}  %-12s ${CYAN}│${ALL_OFF} %-30.30s ${CYAN}${BOLD}║${ALL_OFF}\n" "Gaming"     "$_gaming_label"
printf "${CYAN}${BOLD}║${ALL_OFF}  %-12s ${CYAN}│${ALL_OFF} %-30s ${CYAN}${BOLD}║${ALL_OFF}\n" "Bluetooth"  "$_bt_label"
printf "${CYAN}${BOLD}║${ALL_OFF}  %-12s ${CYAN}│${ALL_OFF} %-30s ${CYAN}${BOLD}║${ALL_OFF}\n" "Stampante"  "$_printer_label"
printf "${CYAN}${BOLD}║${ALL_OFF}  %-12s ${CYAN}│${ALL_OFF} %-30s ${CYAN}${BOLD}║${ALL_OFF}\n" "ddcutil"    "$_ddcutil_label"
printf "${CYAN}${BOLD}║${ALL_OFF}  %-12s ${CYAN}│${ALL_OFF} %-30s ${CYAN}${BOLD}║${ALL_OFF}\n" "CosmicStore" "$_cosmic_label"
printf "${CYAN}${BOLD}╚══════════════════════════════════════════════╝${ALL_OFF}\n"
echo ""
while true; do
    read -r -p "Confermi e avvii l'installazione? (s/n): " confirm
    case "$confirm" in s|S|y|Y) break ;; n|N) echo "Annullato."; exit 0 ;; *) echo "s o n." ;; esac
done

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
    pipewire-alsa pipewire-pulse wireplumber
    alsa-firmware alsa-plugins alsa-utils sof-firmware
    pavucontrol playerctl wlsunset

    # Firmware
    linux-firmware

    # Wayland utilities
    wl-clipboard

    # KDE Plasma
    plasma-desktop sddm plasma-nm plasma-pa
    kscreen kwalletmanager kwallet-pam

    # Hyprland
    hyprland hyprland-protocols hyprlock hypridle hyprshot uwsm
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk

    # Shell e terminale
    fish bash-completion kitty alacritty starship fastfetch

    # Temi e aspetto
    adw-gtk-theme bibata-cursor-theme yaru-icon-theme humanity-icon-theme
    qt5ct qt6ct qt5-wayland qt6-wayland
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
    gedit loupe gnome-calculator gnome-disk-utility
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
    cava matugen gpu-screen-recorder mission-center dunst

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
            vulkan-icd-loader lib32-vulkan-icd-loader
        )
        ;;
    amd)
        PACKAGES+=(
            mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon
            libva-mesa-driver lib32-libva-mesa-driver
            mesa-vdpau lib32-mesa-vdpau
            vulkan-icd-loader lib32-vulkan-icd-loader
        )
        ;;
    intel)
        PACKAGES+=(
            intel-ucode intel-media-sdk libva-intel-driver-irql
            vulkan-intel lib32-vulkan-intel
            vulkan-icd-loader lib32-vulkan-icd-loader
        )
        ;;
esac

[ "$INSTALL_BT"      -eq 1 ] && PACKAGES+=(bluez-hid2hci bluez-obex bluez-utils blueman)
[ "$AUDIO_MODE" = "easyeffects" ] && PACKAGES+=(easyeffects lsp-plugins-lv2 calf)
[ "$INSTALL_PRINTER" -eq 1 ] && PACKAGES+=(
    cups cups-filters cups-pdf hplip gutenprint system-config-printer
    foomatic-db foomatic-db-engine foomatic-db-gutenprint-ppds
    foomatic-db-nonfree foomatic-db-nonfree-ppds foomatic-db-ppds
    python-pyqt5 python-pyqt6 python-reportlab
)

# ═════════════════════════════════════════════════════════════════════════════
section 1 9 "Installazione pacchetti"
# ═════════════════════════════════════════════════════════════════════════════

msg "Aggiorno il sistema..."
run pacman -Syu --noconfirm

msg "Installo tutti i pacchetti core..."
if ! run pacman -S --needed --noconfirm "${PACKAGES[@]}"; then
    warn "Alcuni pacchetti non trovati. Riprovo uno per uno..."
    _total=${#PACKAGES[@]}
    _count=0
    for pkg in "${PACKAGES[@]}"; do
        _count=$(( _count + 1 ))
        progress_bar "$_count" "$_total" "$pkg"
        run pacman -S --needed --noconfirm "$pkg" 2>/dev/null || warn "Non trovato: $pkg"
    done
    echo ""   # newline dopo la barra
    STATUS_PKGS=2
else
    STATUS_PKGS=1
fi
[ "$STATUS_PKGS" -eq 0 ] && STATUS_PKGS=1

# Gaming
[ "${#GAMING_PKGS[@]}" -gt 0 ] && {
    msg "Installo pacchetti gaming..."
    run pacman -S --needed --noconfirm "${GAMING_PKGS[@]}" || true
}

# Player AV
[ "${#AV_PKGS[@]}" -gt 0 ] && {
    msg "Installo player audio/video..."
    run pacman -S --needed --noconfirm "${AV_PKGS[@]}" || true
}

# ═════════════════════════════════════════════════════════════════════════════
section 2 9 "Pacchetti AUR con yay"
# ═════════════════════════════════════════════════════════════════════════════

if ! command -v yay &>/dev/null; then
    msg "Installo yay..."
    run pacman -S --needed --noconfirm git base-devel
    sudo -u "$ACTUAL_USER" git clone https://aur.archlinux.org/yay.git /tmp/yay-build
    (cd /tmp/yay-build && sudo -u "$ACTUAL_USER" makepkg -si --noconfirm)
    rm -rf /tmp/yay-build
fi

msg "Installo noctalia-shell, noctalia-qs e vscodium..."
if run sudo -u "$ACTUAL_USER" yay -S --needed --noconfirm \
    noctalia-shell noctalia-qs vscodium; then
    STATUS_AUR=1
else
    warn "Alcuni AUR packages falliti."
    STATUS_AUR=2
fi

# Cosmic Store
if [ "$INSTALL_COSMIC_STORE" -eq 1 ]; then
    msg "Installo cosmic-store..."
    run sudo -u "$ACTUAL_USER" yay -S --needed --noconfirm cosmic-store || warn "cosmic-store non trovato nell'AUR."
fi

# Browser
case "$BROWSER" in
    1) msg "Installo Brave...";
       run pacman -S --noconfirm brave-bin 2>/dev/null || \
       run sudo -u "$ACTUAL_USER" yay -S --noconfirm brave-origin-nightly-bin ;;
    2) msg "Installo Firefox...";     run pacman -S --noconfirm firefox ;;
    3) msg "Installo LibreWolf...";   run sudo -u "$ACTUAL_USER" yay -S --noconfirm librewolf ;;
    4) msg "Installo Vivaldi...";     run pacman -S --noconfirm vivaldi ;;
    5) msg "Installo Zen Browser..."; run sudo -u "$ACTUAL_USER" yay -S --noconfirm zen-browser-bin ;;
    *) info "Browser saltato." ;;
esac

# ═════════════════════════════════════════════════════════════════════════════
section 3 9 "Servizi di sistema"
# ═════════════════════════════════════════════════════════════════════════════

msg "Abilito servizi..."
run systemctl enable NetworkManager
run systemctl enable power-profiles-daemon
run systemctl enable sddm
[ "$INSTALL_PRINTER" -eq 1 ] && run systemctl enable cups         || true
[ "$INSTALL_BT"      -eq 1 ] && run systemctl enable bluetooth    || true
run systemctl enable plymouth-quit-wait.service 2>/dev/null        || true
STATUS_SERVICES=1

# ═════════════════════════════════════════════════════════════════════════════
section 4 9 "Flatpak e Flathub"
# ═════════════════════════════════════════════════════════════════════════════

msg "Aggiungo Flathub remote..."
if run sudo -u "$ACTUAL_USER" flatpak remote-add --if-not-exists flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo; then
    STATUS_FLATHUB=1
else
    warn "Flathub remote fallito."
    STATUS_FLATHUB=2
fi

if [ "$INSTALL_COSMIC_STORE" -eq 1 ]; then
    msg "Configuro permessi Flatpak per cosmic-store..."
    run sudo -u "$ACTUAL_USER" flatpak override --user \
        --filesystem=home \
        --share=network \
        --share=ipc \
        --socket=wayland \
        --socket=fallback-x11 \
        com.system76.CosmicStore 2>/dev/null || true
    info "Permessi Flatpak applicati a cosmic-store"
fi

# ═════════════════════════════════════════════════════════════════════════════
section 5 9 "ddcutil"
# ═════════════════════════════════════════════════════════════════════════════

if [ "$INSTALL_DDCUTIL" -eq 1 ]; then
    msg "Installo e configuro ddcutil..."
    run pacman -S --noconfirm --needed ddcutil || true
    run sudo -u "$ACTUAL_USER" yay -S --noconfirm --needed ddcutil-service || true
    run modprobe i2c-dev || true
    echo "i2c-dev" > /etc/modules-load.d/i2c-dev.conf
    run udevadm control --reload-rules
    run udevadm trigger
    run usermod -aG i2c "$ACTUAL_USER" || true
    DDCUTIL_ENABLED=1
    STATUS_DDCUTIL=1
    info "ddcutil configurato. Fai logout/reboot per applicare i gruppi."
else
    STATUS_DDCUTIL=0   # saltato, non un errore
fi

# ═════════════════════════════════════════════════════════════════════════════
section 6 9 "Shell predefinita"
# ═════════════════════════════════════════════════════════════════════════════

if command -v fish &>/dev/null; then
    msg "Imposto fish come shell predefinita per $ACTUAL_USER..."
    run chsh -s /usr/bin/fish "$ACTUAL_USER"
    info "Shell impostata a fish"
fi

# ═════════════════════════════════════════════════════════════════════════════
section 7 9 "Deploy dotfiles"
# ═════════════════════════════════════════════════════════════════════════════

CONFIG_SRC="$SCRIPT_DIR/.config"
run sudo -u "$ACTUAL_USER" mkdir -p "$CONFIG_DIR"

BACKUP_TS=$(date +%s)
msg "Backup configurazioni esistenti..."
for item in "$CONFIG_SRC"/*/; do
    name=$(basename "$item")
    target="$CONFIG_DIR/$name"
    [ -e "$target" ] && {
        run mv "$target" "$CONFIG_DIR/${name}.bak.${BACKUP_TS}"
        info "Backup: $name"
    }
done
while IFS= read -r f; do
    name=$(basename "$f")
    target="$CONFIG_DIR/$name"
    [ -e "$target" ] && run mv "$target" "$CONFIG_DIR/${name}.bak.${BACKUP_TS}"
done < <(find "$CONFIG_SRC" -maxdepth 1 -type f \
    \( -name "*.toml" -o -name "*.ini" -o -name "*.conf" \
       -o -name "*.json" -o -name "*.jsonc" \) 2>/dev/null)

msg "Copio tutti i dotfiles..."
run cp -rf "$CONFIG_SRC"/. "$CONFIG_DIR"/
run chown -R "$ACTUAL_USER:$ACTUAL_USER" "$CONFIG_DIR"

if [ -f "$CONFIG_DIR/qt6ct/qt6ct.conf" ]; then
    run sed -i "s|__HOME__|$ACTUAL_USER_HOME|g" "$CONFIG_DIR/qt6ct/qt6ct.conf"
    run chown "$ACTUAL_USER:$ACTUAL_USER" "$CONFIG_DIR/qt6ct/qt6ct.conf"
    info "Path qt6ct aggiornato"
fi

if [ ! -f "$CONFIG_DIR/hypr/monitors.conf" ]; then
    sudo -u "$ACTUAL_USER" tee "$CONFIG_DIR/hypr/monitors.conf" >/dev/null << 'MONEOF'
# Configura i tuoi monitor qui.
# Esempio: monitor=DP-1,1920x1080@144,0x0,1
# Vedi: https://wiki.hyprland.org/Configuring/Monitors/
monitor=,preferred,auto,1
MONEOF
    info "monitors.conf placeholder creato — configuralo con i tuoi monitor"
fi

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
[ -d "$CONFIG_DIR/hypr/Scripts" ] && \
    find "$CONFIG_DIR/hypr/Scripts" -type f -exec chmod +x {} \;
STATUS_DOTFILES=1

# ═════════════════════════════════════════════════════════════════════════════
section 8 9 "Tema GTK e Qt"
# ═════════════════════════════════════════════════════════════════════════════

if command -v gsettings &>/dev/null; then
    run sudo -u "$ACTUAL_USER" gsettings set org.gnome.desktop.interface gtk-theme    'adw-gtk3-dark'
    run sudo -u "$ACTUAL_USER" gsettings set org.gnome.desktop.interface icon-theme   'Yaru-blue-dark'
    run sudo -u "$ACTUAL_USER" gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Classic'
    run sudo -u "$ACTUAL_USER" gsettings set org.gnome.desktop.interface cursor-size  24
    run sudo -u "$ACTUAL_USER" gsettings set org.gnome.desktop.interface font-name    'Adwaita Sans 11'
    run sudo -u "$ACTUAL_USER" gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    msg "gsettings applicati"
    STATUS_GTK=1
else
    warn "gsettings non disponibile"
    STATUS_GTK=2
fi

ENV_FILE="$ACTUAL_USER_HOME/.config/environment.d/qt-theme.conf"
run sudo -u "$ACTUAL_USER" mkdir -p "$(dirname "$ENV_FILE")"
[ ! -f "$ENV_FILE" ] && sudo -u "$ACTUAL_USER" tee "$ENV_FILE" >/dev/null << 'ENV'
QT_QPA_PLATFORMTHEME=qt6ct
QT_STYLE_OVERRIDE=Breeze
ENV

# ═════════════════════════════════════════════════════════════════════════════
section 9 9 "Thunar e directory utente"
# ═════════════════════════════════════════════════════════════════════════════

run sudo -u "$ACTUAL_USER" xdg-user-dirs-update || true
run sudo -u "$ACTUAL_USER" xdg-mime default thunar.desktop \
    inode/directory application/x-gnome-saved-search 2>/dev/null || true

BM="$ACTUAL_USER_HOME/.config/gtk-3.0/bookmarks"
run sudo -u "$ACTUAL_USER" mkdir -p "$(dirname "$BM")"
sudo -u "$ACTUAL_USER" tee "$BM" >/dev/null << EOF
file://$ACTUAL_USER_HOME/Documents
file://$ACTUAL_USER_HOME/Downloads
file://$ACTUAL_USER_HOME/Pictures
file://$ACTUAL_USER_HOME/Music
file://$ACTUAL_USER_HOME/Videos
file://$ACTUAL_USER_HOME/.config/hypr
EOF

[ "$AUDIO_MODE" = "dolby" ] && [ -d "$SCRIPT_DIR/pipewire" ] && {
    run sudo -u "$ACTUAL_USER" mkdir -p "$CONFIG_DIR/pipewire"
    run cp -rf "$SCRIPT_DIR/pipewire/"* "$CONFIG_DIR/pipewire/"
    run chown -R "$ACTUAL_USER:$ACTUAL_USER" "$CONFIG_DIR/pipewire"
    msg "Profilo Dolby PipeWire applicato"
}

# ═════════════════════════════════════════════════════════════════════════════
# CHECKLIST FINALE + TIMER
# ═════════════════════════════════════════════════════════════════════════════
END_TIME=$(date +%s)
ELAPSED=$(( END_TIME - START_TIME ))
ELAPSED_MIN=$(( ELAPSED / 60 ))
ELAPSED_SEC=$(( ELAPSED % 60 ))

_ok="${GREEN}${BOLD}  ✔${ALL_OFF}"
_warn="${YELLOW}${BOLD}  ⚠${ALL_OFF}"
_skip="${CYAN}  –${ALL_OFF}"

_fmt_status() {
    case "$1" in
        1) printf "%s" "$_ok" ;;
        2) printf "%s" "$_warn" ;;
        *) printf "%s" "$_skip" ;;
    esac
}

echo ""
printf "${CYAN}${BOLD}╔══════════════════════════════════════════════╗${ALL_OFF}\n"
printf "${CYAN}${BOLD}║           RIEPILOGO INSTALLAZIONE            ║${ALL_OFF}\n"
printf "${CYAN}${BOLD}╠══════════════════════════════════════════════╣${ALL_OFF}\n"
printf "${CYAN}${BOLD}║${ALL_OFF} $(_fmt_status $STATUS_PKGS)   %-38s ${CYAN}${BOLD}║${ALL_OFF}\n" "Pacchetti core"
printf "${CYAN}${BOLD}║${ALL_OFF} $(_fmt_status $STATUS_AUR)   %-38s ${CYAN}${BOLD}║${ALL_OFF}\n" "Pacchetti AUR (noctalia, vscodium)"
printf "${CYAN}${BOLD}║${ALL_OFF} $(_fmt_status $STATUS_SERVICES)   %-38s ${CYAN}${BOLD}║${ALL_OFF}\n" "Servizi di sistema (sddm, NM...)"
printf "${CYAN}${BOLD}║${ALL_OFF} $(_fmt_status $STATUS_FLATHUB)   %-38s ${CYAN}${BOLD}║${ALL_OFF}\n" "Flatpak / Flathub"
printf "${CYAN}${BOLD}║${ALL_OFF} $(_fmt_status $STATUS_DOTFILES)   %-38s ${CYAN}${BOLD}║${ALL_OFF}\n" "Dotfiles deployati"
printf "${CYAN}${BOLD}║${ALL_OFF} $(_fmt_status $STATUS_GTK)   %-38s ${CYAN}${BOLD}║${ALL_OFF}\n" "Tema GTK / Qt / gsettings"
if [ "$INSTALL_DDCUTIL" -eq 1 ]; then
printf "${CYAN}${BOLD}║${ALL_OFF} $(_fmt_status $STATUS_DDCUTIL)   %-38s ${CYAN}${BOLD}║${ALL_OFF}\n" "ddcutil (DDC/CI monitor)"
fi
printf "${CYAN}${BOLD}╠══════════════════════════════════════════════╣${ALL_OFF}\n"
printf "${CYAN}${BOLD}║${ALL_OFF}  ${GREEN}${BOLD}%-44s${ALL_OFF} ${CYAN}${BOLD}║${ALL_OFF}\n" "Tempo totale: ${ELAPSED_MIN}m ${ELAPSED_SEC}s"
printf "${CYAN}${BOLD}║${ALL_OFF}  Log: %-40s ${CYAN}${BOLD}║${ALL_OFF}\n" "$LOG_FILE"
printf "${CYAN}${BOLD}╚══════════════════════════════════════════════╝${ALL_OFF}\n"
echo ""

printf "${CYAN}Note importanti:${ALL_OFF}\n"
printf "  • ${YELLOW}monitors.conf${ALL_OFF} è un placeholder: configuralo con i tuoi monitor\n"
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
