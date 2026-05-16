#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
#  noctalia-dotfiles — install.sh
#  Complete system clone on CachyOS base
#  Based on: https://github.com/Echilonvibin/minimaLinux
#
#  USAGE:        sudo bash install.sh
#  DRY-RUN:      sudo bash install.sh --dry-run
#  REQUIREMENTS: CachyOS installed (base or desktop), internet connection
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Timer ─────────────────────────────────────────────────────────────────────
START_TIME=$(date +%s)

export LC_MESSAGES=C
export LANG=C

# ── Dry-run flag ───────────────────────────────────────────────────────────────
DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

# ── Log file ───────────────────────────────────────────────────────────────────
LOG_FILE="/tmp/noctalia-install-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# ── Status tracking for final checklist ───────────────────────────────────────
STATUS_PKGS=0       # 1=ok 2=warn
STATUS_AUR=0
STATUS_SERVICES=0
STATUS_FLATHUB=0
STATUS_CACHYOS=0
STATUS_DDCUTIL=0
STATUS_LAPTOP=0
STATUS_DOTFILES=0
STATUS_GTK=0

# ── Utilities ─────────────────────────────────────────────────────────────────
append_unique_package() {
    local -n _list="$1"; local _pkg="$2"
    for _p in "${_list[@]+"${_list[@]}"}"; do [ "$_p" = "$_pkg" ] && return 0; done
    _list+=("$_pkg")
}

# Dry-run wrapper
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

# section STEP TOTAL TITLE  or  section TITLE (no numbering)
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

# Progress bar: progress_bar CURRENT TOTAL [LABEL]
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

     Complete clone — CachyOS · KDE · Hyprland · Noctalia Shell
EOF
printf "${ALL_OFF}\n"

[ "$DRY_RUN" -eq 1 ] && printf "${YELLOW}${BOLD}  *** DRY-RUN MODE: no changes will be applied ***${ALL_OFF}\n\n"
info "Log: $LOG_FILE"
echo ""

# ── Preliminary checks ────────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && { echo "Run with: sudo bash install.sh"; exit 1; }
[ ! -f /etc/pacman.conf ]      && { echo "ERROR: /etc/pacman.conf not found."; exit 1; }
[ ! -d "$SCRIPT_DIR/.config" ] && { echo "ERROR: .config folder not found in $SCRIPT_DIR"; exit 1; }

msg "Checking internet connection..."
if ! ping -c1 -W3 archlinux.org &>/dev/null; then
    echo "ERROR: no internet connection. Check your network and try again."
    exit 1
fi
info "Connection OK"

msg "Checking disk space..."
FREE_KB=$(df / --output=avail | tail -1)
FREE_GB=$(( FREE_KB / 1024 / 1024 ))
if [ "$FREE_GB" -lt 10 ]; then
    echo "ERROR: not enough free space on / (${FREE_GB}GB available, minimum 10GB required)."
    exit 1
fi
info "Disk space OK: ${FREE_GB}GB free"

# Detect the real (non-root) user
if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    ACTUAL_USER="$SUDO_USER"
else
    ACTUAL_USER=$(logname 2>/dev/null || true)
fi
{ [ -z "${ACTUAL_USER:-}" ] || [ "$ACTUAL_USER" = "root" ]; } && {
    echo "ERROR: cannot determine non-root user. Use: sudo bash install.sh"
    exit 1
}
ACTUAL_USER_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)
[ -z "$ACTUAL_USER_HOME" ] && { echo "ERROR: home directory for $ACTUAL_USER not found."; exit 1; }

CONFIG_DIR="$ACTUAL_USER_HOME/.config"
DDCUTIL_ENABLED=0
INSTALL_COSMIC_STORE=0

echo ""
info "User: $ACTUAL_USER  |  Home: $ACTUAL_USER_HOME"
echo ""
echo "This script installs a complete system clone (CachyOS + KDE + Hyprland + Noctalia)."
warn "Use ONLY on a fresh CachyOS installation. Proceed at your own risk."
echo ""
while true; do
    read -r -p "Do you want to proceed? [y/n]: " proceed
    case "$proceed" in y|Y) break ;; n|N) echo "Aborted."; exit 0 ;; *) echo "y or n." ;; esac
done

# ═════════════════════════════════════════════════════════════════════════════
section "Interactive setup"
# ═════════════════════════════════════════════════════════════════════════════

# ── GPU ───────────────────────────────────────────────────────────────────────
GPU_MODE="none"
echo "GPU type:"
echo "  1. NVIDIA  (proprietary nvidia-open drivers, for CachyOS kernel)"
echo "  2. AMD     (open drivers, included in kernel)"
echo "  3. Intel   (open drivers, included in kernel)"
echo "  4. Skip    (manual setup)"
while true; do
    read -r -p "Choice (1-4): " gpu_choice
    case "$gpu_choice" in
        1) GPU_MODE="nvidia"; break ;;
        2) GPU_MODE="amd";    break ;;
        3) GPU_MODE="intel";  break ;;
        4) GPU_MODE="none";   break ;;
        *) echo "Enter a number from 1 to 4." ;;
    esac
done

# ── Printer ───────────────────────────────────────────────────────────────────
INSTALL_PRINTER=0
echo ""
echo "Printer support:"
echo "  1. Yes"
echo "  2. No"
while true; do
    read -r -p "Choice (1-2): " c
    case "$c" in 1) INSTALL_PRINTER=1; break ;; 2) break ;; *) echo "1 or 2." ;; esac
done

# ── Bluetooth ─────────────────────────────────────────────────────────────────
INSTALL_BT=0
echo ""
echo "Bluetooth:"
echo "  1. Yes  (install bluez, blueman, enable service)"
echo "  2. No"
while true; do
    read -r -p "Choice (1-2): " c
    case "$c" in 1) INSTALL_BT=1; break ;; 2) break ;; *) echo "1 or 2." ;; esac
done

# ── Audio ─────────────────────────────────────────────────────────────────────
AUDIO_MODE="easyeffects"
echo ""
echo "Audio:"
echo "  0. Skip"
echo "  1. EasyEffects  (default, equalizer and effects)"
echo "  2. Dolby Atmos  (PipeWire surround profile)"
while true; do
    read -r -p "Choice (0-2): " c
    case "$c" in
        0) AUDIO_MODE="none";           break ;;
        1|"") AUDIO_MODE="easyeffects"; break ;;
        2) AUDIO_MODE="dolby";          break ;;
        *) echo "0, 1 or 2." ;;
    esac
done

# ── Gaming ────────────────────────────────────────────────────────────────────
GAMING_PKGS=()
echo ""
echo "Gaming packages (comma/space separated, a=all, 0=skip):"
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
echo "   a. Install all"
echo "   0. Skip"
read -r -p "Choice: " gaming_choices
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

# ── Audio/Video players ───────────────────────────────────────────────────────
AV_PKGS=()
echo ""
echo "Audio/Video players (comma/space separated, a=all, 0=skip):"
echo "  1. mpv        (lightweight, command line)"
echo "  2. vlc        (versatile)"
echo "  3. haruna     (KDE, modern)"
echo "  4. deadbeef   (music, modular)"
echo "  5. rhythmbox  (GNOME, music)"
echo "  a. Install all"
echo "  0. Skip"
read -r -p "Choice: " av_choices
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
echo "  0. Skip"
while true; do
    read -r -p "Choice (0-5): " c
    case "$c" in 0|1|2|3|4|5) BROWSER=$c; break ;; *) echo "0-5." ;; esac
done

# ── Cosmic Store ──────────────────────────────────────────────────────────────
echo ""
echo "Cosmic Store (Flatpak app store with modern UI):"
echo "  1. Yes  (install cosmic-store, configure Flathub with full permissions)"
echo "  2. No"
while true; do
    read -r -p "Choice (1-2): " c
    case "$c" in 1) INSTALL_COSMIC_STORE=1; break ;; 2) break ;; *) echo "1 or 2." ;; esac
done

# ── Laptop ────────────────────────────────────────────────────────────────────
INSTALL_LAPTOP=0
echo ""
echo "Laptop components (battery and power management):"
echo "  1. Yes  (install auto-cpufreq, enable battery management service)"
echo "  2. No"
while true; do
    read -r -p "Choice (1-2): " c
    case "$c" in 1) INSTALL_LAPTOP=1; break ;; 2) break ;; *) echo "1 or 2." ;; esac
done

# ── ddcutil ───────────────────────────────────────────────────────────────────
INSTALL_DDCUTIL=0
echo ""
echo "ddcutil (monitor brightness control via DDC/CI):"
echo "  1. Yes"
echo "  2. No"
while true; do
    read -r -p "Choice (1-2): " c
    case "$c" in 1) INSTALL_DDCUTIL=1; break ;; 2) break ;; *) echo "1 or 2." ;; esac
done

# ── Summary box ───────────────────────────────────────────────────────────────
_gpu_label="Skip (manual)"
case "$GPU_MODE" in nvidia) _gpu_label="NVIDIA (nvidia-open)" ;; amd) _gpu_label="AMD (mesa/vulkan)" ;; intel) _gpu_label="Intel (vulkan-intel)" ;; esac

_browser_label="Skip"
case "$BROWSER" in 1) _browser_label="Brave Origin Nightly" ;; 2) _browser_label="Firefox" ;; 3) _browser_label="LibreWolf" ;; 4) _browser_label="Vivaldi" ;; 5) _browser_label="Zen Browser" ;; esac

_audio_label="Skip"
case "$AUDIO_MODE" in easyeffects) _audio_label="EasyEffects" ;; dolby) _audio_label="Dolby Atmos" ;; esac

_gaming_label="None"
[ "${#GAMING_PKGS[@]}" -gt 0 ] && _gaming_label="${GAMING_PKGS[*]}"

_bt_label="No";      [ "$INSTALL_BT"           -eq 1 ] && _bt_label="Yes"
_printer_label="No"; [ "$INSTALL_PRINTER"       -eq 1 ] && _printer_label="Yes"
_ddcutil_label="No"; [ "$INSTALL_DDCUTIL"       -eq 1 ] && _ddcutil_label="Yes"
_cosmic_label="No";  [ "$INSTALL_COSMIC_STORE"  -eq 1 ] && _cosmic_label="Yes"
_laptop_label="No";  [ "$INSTALL_LAPTOP"        -eq 1 ] && _laptop_label="Yes (auto-cpufreq)"

echo ""
printf "${CYAN}${BOLD}╔══════════════════════════════════════════════╗${ALL_OFF}\n"
printf "${CYAN}${BOLD}║       INSTALLATION SUMMARY                   ║${ALL_OFF}\n"
printf "${CYAN}${BOLD}╠══════════════════════════════════════════════╣${ALL_OFF}\n"
printf "${CYAN}${BOLD}║${ALL_OFF}  %-12s ${CYAN}│${ALL_OFF} %-30s ${CYAN}${BOLD}║${ALL_OFF}\n" "GPU"         "$_gpu_label"
printf "${CYAN}${BOLD}║${ALL_OFF}  %-12s ${CYAN}│${ALL_OFF} %-30s ${CYAN}${BOLD}║${ALL_OFF}\n" "Browser"     "$_browser_label"
printf "${CYAN}${BOLD}║${ALL_OFF}  %-12s ${CYAN}│${ALL_OFF} %-30s ${CYAN}${BOLD}║${ALL_OFF}\n" "Audio"       "$_audio_label"
printf "${CYAN}${BOLD}║${ALL_OFF}  %-12s ${CYAN}│${ALL_OFF} %-30.30s ${CYAN}${BOLD}║${ALL_OFF}\n" "Gaming"     "$_gaming_label"
printf "${CYAN}${BOLD}║${ALL_OFF}  %-12s ${CYAN}│${ALL_OFF} %-30s ${CYAN}${BOLD}║${ALL_OFF}\n" "Bluetooth"   "$_bt_label"
printf "${CYAN}${BOLD}║${ALL_OFF}  %-12s ${CYAN}│${ALL_OFF} %-30s ${CYAN}${BOLD}║${ALL_OFF}\n" "Printer"     "$_printer_label"
printf "${CYAN}${BOLD}║${ALL_OFF}  %-12s ${CYAN}│${ALL_OFF} %-30s ${CYAN}${BOLD}║${ALL_OFF}\n" "ddcutil"     "$_ddcutil_label"
printf "${CYAN}${BOLD}║${ALL_OFF}  %-12s ${CYAN}│${ALL_OFF} %-30s ${CYAN}${BOLD}║${ALL_OFF}\n" "Laptop"      "$_laptop_label"
printf "${CYAN}${BOLD}║${ALL_OFF}  %-12s ${CYAN}│${ALL_OFF} %-30s ${CYAN}${BOLD}║${ALL_OFF}\n" "CosmicStore" "$_cosmic_label"
printf "${CYAN}${BOLD}╚══════════════════════════════════════════════╝${ALL_OFF}\n"
echo ""
while true; do
    read -r -p "Confirm and start installation? [y/n]: " confirm
    case "$confirm" in y|Y) break ;; n|N) echo "Aborted."; exit 0 ;; *) echo "y or n." ;; esac
done

# ═════════════════════════════════════════════════════════════════════════════
# PACKAGE LIST — exported from the original system with: pacman -Qqe
# ═════════════════════════════════════════════════════════════════════════════
PACKAGES=(
    # Base system
    base base-devel sudo vim nano less wget which
    man-db man-pages texinfo logrotate s-nail perl python

    # Filesystem
    btrfs-progs cryptsetup device-mapper e2fsprogs efibootmgr efitools
    f2fs-tools jfsutils lvm2 mdadm mkinitcpio ntfs-3g dosfstools exfatprogs xfsprogs

    # Boot
    limine limine-mkinitcpio-hook update-grub os-prober plymouth

    # Network
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

    # Shell and terminal
    fish bash-completion kitty alacritty starship fastfetch

    # Themes and appearance
    adw-gtk-theme bibata-cursor-theme yaru-icon-theme humanity-icon-theme
    qt5ct qt6ct qt5-wayland qt6-wayland
    noto-fonts noto-fonts-cjk noto-fonts-emoji
    ttf-dejavu ttf-liberation ttf-bitstream-vera ttf-meslo-nerd
    ttf-ms-fonts ttf-opensans ttf-symbola cantarell-fonts
    awesome-terminal-fonts

    # Screenshot and Wayland utilities
    grim slurp satty wofi

    # File manager
    thunar thunar-archive-plugin thunar-media-tags-plugin
    thunar-shares-plugin thunar-vcs-plugin thunar-volman
    tumbler ffmpegthumbnailer libopenraw libgsf poppler-glib
    libgepub freetype2 ark file-roller
    gvfs gvfs-afc gvfs-mtp gvfs-smb

    # Desktop apps
    gedit loupe gnome-calculator gnome-disk-utility
    nwg-look nwg-displays gcolor3 pinta
    flatpak xdg-user-dirs

    # System tools
    gnome-keyring polkit-gnome power-profiles-daemon cpupower upower
    smartmontools sysfsutils usb_modeswitch usbutils
    lsb-release reflector

    # Build / development
    clang cmake go rust meson ninja pkgconf

    # Archives
    unrar unzip 7zip

    # Media / codecs
    gst-plugins-good gst-plugins-ugly gst-libav gst-plugin-va

    # Bluetooth (base; service enabled later if selected)
    bluez bluez-libs

    # Spell checkers
    aspell hspell libvoikko nuspell

    # Misc
    cava matugen gpu-screen-recorder mission-center dunst

    # CachyOS-specific packages
    cachyos-hello cachyos-hooks cachyos-keyring cachyos-mirrorlist
    cachyos-packageinstaller cachyos-plymouth-bootanimation cachyos-plymouth-theme
    cachyos-rate-mirrors cachyos-settings cachyos-v3-mirrorlist cachyos-v4-mirrorlist
    chaotic-keyring chaotic-mirrorlist chwd
)

# GPU-specific packages
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
section 1 10 "CachyOS repositories and bore kernel"
# ═════════════════════════════════════════════════════════════════════════════

msg "Adding official CachyOS repositories..."
_cachyos_tmp="/tmp/cachyos-repo-setup"
rm -rf "$_cachyos_tmp" && mkdir -p "$_cachyos_tmp"
(
    cd "$_cachyos_tmp"
    if ! run curl -O https://mirror.cachyos.org/cachyos-repo.tar.xz; then
        error "Failed to download cachyos-repo.tar.xz."
        exit 1
    fi
    run tar xvf cachyos-repo.tar.xz
    cd cachyos-repo
    if ! run bash ./cachyos-repo.sh; then
        error "cachyos-repo.sh failed — cannot continue without CachyOS repositories."
        exit 1
    fi
) || { error "CachyOS repository setup failed."; exit 1; }
rm -rf "$_cachyos_tmp"

# Detect which repo variant was added
_cachyos_repo_added="cachyos (generic)"
grep -q "\[cachyos-v3\]" /etc/pacman.conf 2>/dev/null && _cachyos_repo_added="cachyos-v3 (CPU with AVX2)"
grep -q "\[cachyos-v4\]" /etc/pacman.conf 2>/dev/null && _cachyos_repo_added="cachyos-v4 (CPU with AVX-512)"
msg "Repository added: $_cachyos_repo_added"

msg "Refreshing package database..."
run pacman -Sy

msg "Installing linux-cachyos-bore and headers..."
if ! run pacman -S --needed --noconfirm linux-cachyos-bore linux-cachyos-bore-headers; then
    error "Kernel linux-cachyos-bore installation failed."
    exit 1
fi

_bore_repo=$(pacman -Qi linux-cachyos-bore 2>/dev/null | awk -F': ' '/^Repository/{gsub(/^ +/,"",$2); print $2}')
[ -z "$_bore_repo" ] && _bore_repo="(not available)"
echo ""
printf "${CYAN}${BOLD}╔══════════════════════════════════════════════╗${ALL_OFF}\n"
printf "${CYAN}${BOLD}║        KERNEL INSTALLED                      ║${ALL_OFF}\n"
printf "${CYAN}${BOLD}╠══════════════════════════════════════════════╣${ALL_OFF}\n"
printf "${CYAN}${BOLD}║${ALL_OFF}  %-12s ${CYAN}│${ALL_OFF} %-30s ${CYAN}${BOLD}║${ALL_OFF}\n" "Kernel"     "linux-cachyos-bore"
printf "${CYAN}${BOLD}║${ALL_OFF}  %-12s ${CYAN}│${ALL_OFF} %-30s ${CYAN}${BOLD}║${ALL_OFF}\n" "Repository" "$_bore_repo"
printf "${CYAN}${BOLD}║${ALL_OFF}  %-12s ${CYAN}│${ALL_OFF} %-30.30s ${CYAN}${BOLD}║${ALL_OFF}\n" "CPU repo"   "$_cachyos_repo_added"
printf "${CYAN}${BOLD}╚══════════════════════════════════════════════╝${ALL_OFF}\n"
echo ""
STATUS_CACHYOS=1

msg "Regenerating initramfs..."
run mkinitcpio -P

# Bootloader detection
if [ -f /etc/limine/limine.conf ] || [ -f /boot/limine/limine.conf ]; then
    info "Limine detected — it will automatically pick up the new kernel on reboot."
elif [ -f /boot/grub/grub.cfg ]; then
    msg "GRUB detected — updating grub.cfg..."
    run update-grub
    msg "grub.cfg updated."
else
    warn "Bootloader not detected automatically — manually update your boot configuration to include linux-cachyos-bore."
fi

# ═════════════════════════════════════════════════════════════════════════════
section 2 10 "Package installation"
# ═════════════════════════════════════════════════════════════════════════════

msg "Updating system..."
run pacman -Syu --noconfirm

msg "Installing all core packages..."
if ! run pacman -S --needed --noconfirm "${PACKAGES[@]}"; then
    warn "Some packages not found. Retrying one by one..."
    _total=${#PACKAGES[@]}
    _count=0
    for pkg in "${PACKAGES[@]}"; do
        _count=$(( _count + 1 ))
        progress_bar "$_count" "$_total" "$pkg"
        run pacman -S --needed --noconfirm "$pkg" 2>/dev/null || warn "Not found: $pkg"
    done
    echo ""   # newline after progress bar
    STATUS_PKGS=2
else
    STATUS_PKGS=1
fi
[ "$STATUS_PKGS" -eq 0 ] && STATUS_PKGS=1

# Gaming packages
[ "${#GAMING_PKGS[@]}" -gt 0 ] && {
    msg "Installing gaming packages..."
    run pacman -S --needed --noconfirm "${GAMING_PKGS[@]}" || true
}

# Audio/Video players
[ "${#AV_PKGS[@]}" -gt 0 ] && {
    msg "Installing audio/video players..."
    run pacman -S --needed --noconfirm "${AV_PKGS[@]}" || true
}

# ═════════════════════════════════════════════════════════════════════════════
section 3 10 "AUR packages with yay"
# ═════════════════════════════════════════════════════════════════════════════

if ! command -v yay &>/dev/null; then
    msg "Installing yay..."
    run pacman -S --needed --noconfirm git base-devel
    sudo -u "$ACTUAL_USER" git clone https://aur.archlinux.org/yay.git /tmp/yay-build
    (cd /tmp/yay-build && sudo -u "$ACTUAL_USER" makepkg -si --noconfirm)
    rm -rf /tmp/yay-build
fi

msg "Installing noctalia-shell, noctalia-qs and vscodium..."
if run sudo -u "$ACTUAL_USER" yay -S --needed --noconfirm \
    noctalia-shell noctalia-qs vscodium; then
    STATUS_AUR=1
else
    warn "Some AUR packages failed."
    STATUS_AUR=2
fi

# Laptop / auto-cpufreq
if [ "$INSTALL_LAPTOP" -eq 1 ]; then
    msg "Installing auto-cpufreq..."
    if run sudo -u "$ACTUAL_USER" yay -S --needed --noconfirm auto-cpufreq; then
        STATUS_LAPTOP=1
    else
        warn "auto-cpufreq not found in AUR."
        STATUS_LAPTOP=2
    fi
fi

# Cosmic Store
if [ "$INSTALL_COSMIC_STORE" -eq 1 ]; then
    msg "Installing cosmic-store..."
    run sudo -u "$ACTUAL_USER" yay -S --needed --noconfirm cosmic-store || warn "cosmic-store not found in AUR."
fi

# Browser
case "$BROWSER" in
    1) msg "Installing Brave Origin Nightly...";
       run sudo -u "$ACTUAL_USER" yay -S --noconfirm brave-origin-nightly-bin ;;
    2) msg "Installing Firefox...";     run pacman -S --noconfirm firefox ;;
    3) msg "Installing LibreWolf...";   run sudo -u "$ACTUAL_USER" yay -S --noconfirm librewolf ;;
    4) msg "Installing Vivaldi...";     run pacman -S --noconfirm vivaldi ;;
    5) msg "Installing Zen Browser..."; run sudo -u "$ACTUAL_USER" yay -S --noconfirm zen-browser-bin ;;
    *) info "Browser skipped." ;;
esac

# ═════════════════════════════════════════════════════════════════════════════
section 4 10 "System services"
# ═════════════════════════════════════════════════════════════════════════════

msg "Enabling services..."
run systemctl enable NetworkManager
run systemctl enable power-profiles-daemon
run systemctl enable sddm
[ "$INSTALL_PRINTER" -eq 1 ] && run systemctl enable cups         || true
[ "$INSTALL_BT"      -eq 1 ] && run systemctl enable bluetooth    || true
[ "$INSTALL_LAPTOP"  -eq 1 ] && run systemctl enable auto-cpufreq || true
run systemctl enable plymouth-quit-wait.service 2>/dev/null        || true
STATUS_SERVICES=1

# ═════════════════════════════════════════════════════════════════════════════
section 5 10 "Flatpak and Flathub"
# ═════════════════════════════════════════════════════════════════════════════

msg "Adding Flathub remote..."
if run sudo -u "$ACTUAL_USER" flatpak remote-add --if-not-exists flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo; then
    STATUS_FLATHUB=1
else
    warn "Flathub remote failed."
    STATUS_FLATHUB=2
fi

if [ "$INSTALL_COSMIC_STORE" -eq 1 ]; then
    msg "Configuring Flatpak permissions for cosmic-store..."
    run sudo -u "$ACTUAL_USER" flatpak override --user \
        --filesystem=home \
        --share=network \
        --share=ipc \
        --socket=wayland \
        --socket=fallback-x11 \
        com.system76.CosmicStore 2>/dev/null || true
    info "Flatpak permissions applied to cosmic-store"
fi

# ═════════════════════════════════════════════════════════════════════════════
section 6 10 "ddcutil"
# ═════════════════════════════════════════════════════════════════════════════

if [ "$INSTALL_DDCUTIL" -eq 1 ]; then
    msg "Installing and configuring ddcutil..."
    run pacman -S --noconfirm --needed ddcutil || true
    run sudo -u "$ACTUAL_USER" yay -S --noconfirm --needed ddcutil-service || true
    run modprobe i2c-dev || true
    echo "i2c-dev" > /etc/modules-load.d/i2c-dev.conf
    run udevadm control --reload-rules
    run udevadm trigger
    run usermod -aG i2c "$ACTUAL_USER" || true
    DDCUTIL_ENABLED=1
    STATUS_DDCUTIL=1
    info "ddcutil configured. Log out or reboot to apply group changes."
else
    STATUS_DDCUTIL=0   # skipped, not an error
fi

# ═════════════════════════════════════════════════════════════════════════════
section 7 10 "Default shell"
# ═════════════════════════════════════════════════════════════════════════════

if command -v fish &>/dev/null; then
    msg "Setting fish as default shell for $ACTUAL_USER..."
    run chsh -s /usr/bin/fish "$ACTUAL_USER"
    info "Shell set to fish"
fi

# ═════════════════════════════════════════════════════════════════════════════
section 8 10 "Deploy dotfiles"
# ═════════════════════════════════════════════════════════════════════════════

CONFIG_SRC="$SCRIPT_DIR/.config"
run sudo -u "$ACTUAL_USER" mkdir -p "$CONFIG_DIR"

BACKUP_TS=$(date +%s)
msg "Backing up existing configurations..."
for item in "$CONFIG_SRC"/*/; do
    name=$(basename "$item")
    target="$CONFIG_DIR/$name"
    [ -e "$target" ] && {
        run mv "$target" "$CONFIG_DIR/${name}.bak.${BACKUP_TS}"
        info "Backed up: $name"
    }
done
while IFS= read -r f; do
    name=$(basename "$f")
    target="$CONFIG_DIR/$name"
    [ -e "$target" ] && run mv "$target" "$CONFIG_DIR/${name}.bak.${BACKUP_TS}"
done < <(find "$CONFIG_SRC" -maxdepth 1 -type f \
    \( -name "*.toml" -o -name "*.ini" -o -name "*.conf" \
       -o -name "*.json" -o -name "*.jsonc" \) 2>/dev/null)

msg "Copying all dotfiles..."
run cp -rf "$CONFIG_SRC"/. "$CONFIG_DIR"/
run chown -R "$ACTUAL_USER:$ACTUAL_USER" "$CONFIG_DIR"

if [ -f "$CONFIG_DIR/qt6ct/qt6ct.conf" ]; then
    run sed -i "s|__HOME__|$ACTUAL_USER_HOME|g" "$CONFIG_DIR/qt6ct/qt6ct.conf"
    run chown "$ACTUAL_USER:$ACTUAL_USER" "$CONFIG_DIR/qt6ct/qt6ct.conf"
    info "qt6ct path updated"
fi

if [ ! -f "$CONFIG_DIR/hypr/monitors.conf" ]; then
    sudo -u "$ACTUAL_USER" tee "$CONFIG_DIR/hypr/monitors.conf" >/dev/null << 'MONEOF'
# Configure your monitors here.
# Example: monitor=DP-1,1920x1080@144,0x0,1
# See: https://wiki.hyprland.org/Configuring/Monitors/
monitor=,preferred,auto,1
MONEOF
    info "monitors.conf placeholder created — configure it with your monitor setup"
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

msg "Setting Hyprland script permissions..."
[ -d "$CONFIG_DIR/hypr/Scripts" ] && \
    find "$CONFIG_DIR/hypr/Scripts" -type f -exec chmod +x {} \;
STATUS_DOTFILES=1

# ═════════════════════════════════════════════════════════════════════════════
section 9 10 "GTK and Qt theme"
# ═════════════════════════════════════════════════════════════════════════════

if command -v gsettings &>/dev/null; then
    run sudo -u "$ACTUAL_USER" gsettings set org.gnome.desktop.interface gtk-theme    'adw-gtk3-dark'
    run sudo -u "$ACTUAL_USER" gsettings set org.gnome.desktop.interface icon-theme   'Yaru-blue-dark'
    run sudo -u "$ACTUAL_USER" gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Classic'
    run sudo -u "$ACTUAL_USER" gsettings set org.gnome.desktop.interface cursor-size  24
    run sudo -u "$ACTUAL_USER" gsettings set org.gnome.desktop.interface font-name    'Adwaita Sans 11'
    run sudo -u "$ACTUAL_USER" gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    msg "gsettings applied"
    STATUS_GTK=1
else
    warn "gsettings not available"
    STATUS_GTK=2
fi

ENV_FILE="$ACTUAL_USER_HOME/.config/environment.d/qt-theme.conf"
run sudo -u "$ACTUAL_USER" mkdir -p "$(dirname "$ENV_FILE")"
[ ! -f "$ENV_FILE" ] && sudo -u "$ACTUAL_USER" tee "$ENV_FILE" >/dev/null << 'ENV'
QT_QPA_PLATFORMTHEME=qt6ct
QT_STYLE_OVERRIDE=Breeze
ENV

# ═════════════════════════════════════════════════════════════════════════════
section 10 10 "Thunar and user directories"
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
    msg "Dolby PipeWire profile applied"
}

# ═════════════════════════════════════════════════════════════════════════════
# FINAL CHECKLIST + TIMER
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
printf "${CYAN}${BOLD}║           INSTALLATION SUMMARY               ║${ALL_OFF}\n"
printf "${CYAN}${BOLD}╠══════════════════════════════════════════════╣${ALL_OFF}\n"
printf "${CYAN}${BOLD}║${ALL_OFF} $(_fmt_status $STATUS_CACHYOS)   %-38s ${CYAN}${BOLD}║${ALL_OFF}\n" "CachyOS repositories + bore kernel"
printf "${CYAN}${BOLD}║${ALL_OFF} $(_fmt_status $STATUS_PKGS)   %-38s ${CYAN}${BOLD}║${ALL_OFF}\n" "Core packages"
printf "${CYAN}${BOLD}║${ALL_OFF} $(_fmt_status $STATUS_AUR)   %-38s ${CYAN}${BOLD}║${ALL_OFF}\n" "AUR packages (noctalia, vscodium)"
printf "${CYAN}${BOLD}║${ALL_OFF} $(_fmt_status $STATUS_SERVICES)   %-38s ${CYAN}${BOLD}║${ALL_OFF}\n" "System services (sddm, NM...)"
printf "${CYAN}${BOLD}║${ALL_OFF} $(_fmt_status $STATUS_FLATHUB)   %-38s ${CYAN}${BOLD}║${ALL_OFF}\n" "Flatpak / Flathub"
printf "${CYAN}${BOLD}║${ALL_OFF} $(_fmt_status $STATUS_DOTFILES)   %-38s ${CYAN}${BOLD}║${ALL_OFF}\n" "Dotfiles deployed"
printf "${CYAN}${BOLD}║${ALL_OFF} $(_fmt_status $STATUS_GTK)   %-38s ${CYAN}${BOLD}║${ALL_OFF}\n" "GTK / Qt / gsettings theme"
if [ "$INSTALL_DDCUTIL" -eq 1 ]; then
printf "${CYAN}${BOLD}║${ALL_OFF} $(_fmt_status $STATUS_DDCUTIL)   %-38s ${CYAN}${BOLD}║${ALL_OFF}\n" "ddcutil (DDC/CI monitor control)"
fi
if [ "$INSTALL_LAPTOP" -eq 1 ]; then
printf "${CYAN}${BOLD}║${ALL_OFF} $(_fmt_status $STATUS_LAPTOP)   %-38s ${CYAN}${BOLD}║${ALL_OFF}\n" "auto-cpufreq (battery management)"
fi
printf "${CYAN}${BOLD}╠══════════════════════════════════════════════╣${ALL_OFF}\n"
printf "${CYAN}${BOLD}║${ALL_OFF}  ${GREEN}${BOLD}%-44s${ALL_OFF} ${CYAN}${BOLD}║${ALL_OFF}\n" "Total time: ${ELAPSED_MIN}m ${ELAPSED_SEC}s"
printf "${CYAN}${BOLD}║${ALL_OFF}  Log: %-40s ${CYAN}${BOLD}║${ALL_OFF}\n" "$LOG_FILE"
printf "${CYAN}${BOLD}╚══════════════════════════════════════════════╝${ALL_OFF}\n"
echo ""

printf "${CYAN}Important notes:${ALL_OFF}\n"
printf "  • ${YELLOW}monitors.conf${ALL_OFF} is a placeholder: configure it with your monitor setup\n"
printf "      nano %s/hypr/monitors.conf\n" "$CONFIG_DIR"
printf "  • If you use NVIDIA, verify the correct kernel is active:\n"
printf "      uname -r  (should contain 'cachyos' or 'bore')\n"
printf "  • Make sure hyprland.conf includes:\n"
printf "      ${YELLOW}source = ~/.config/hypr/themes/theme.conf${ALL_OFF}\n"
printf "      ${YELLOW}source = ~/.config/hypr/noctalia/noctalia-colors.conf${ALL_OFF}\n\n"

while true; do
    read -r -p "Reboot now? [y/n]: " r
    case "$r" in
        y|Y) echo "Rebooting..."; reboot now; break ;;
        n|N) printf "\n${YELLOW}Remember to reboot!${ALL_OFF}\n"; break ;;
        *) echo "y or n." ;;
    esac
done
