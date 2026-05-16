```
███████╗ █████╗ ███████╗██╗   ██╗██╗     ██╗███╗   ██╗██╗   ██╗██╗  ██╗
██╔════╝██╔══██╗██╔════╝╚██╗ ██╔╝██║     ██║████╗  ██║██║   ██║╚██╗██╔╝
█████╗  ███████║███████╗ ╚████╔╝ ██║     ██║██╔██╗ ██║██║   ██║ ╚███╔╝
██╔══╝  ██╔══██║╚════██║  ╚██╔╝  ██║     ██║██║╚██╗██║██║   ██║ ██╔██╗
███████╗██║  ██║███████║   ██║   ███████╗██║██║ ╚████║╚██████╔╝██╔╝ ██╗
╚══════╝╚═╝  ╚═╝╚══════╝   ╚═╝   ╚══════╝╚═╝╚═╝  ╚═══╝╚═════╝ ╚═╝  ╚═╝
```

<div align="center">

[![License](https://img.shields.io/github/license/Dexmodzz/easylinux-dotfiles?style=flat-square)](LICENSE)
[![Stars](https://img.shields.io/github/stars/Dexmodzz/easylinux-dotfiles?style=flat-square)](https://github.com/Dexmodzz/easylinux-dotfiles/stargazers)
[![Last Commit](https://img.shields.io/github/last-commit/Dexmodzz/easylinux-dotfiles?style=flat-square)](https://github.com/Dexmodzz/easylinux-dotfiles/commits/main)
[![Platform](https://img.shields.io/badge/platform-Linux-blue?style=flat-square&logo=linux)](https://kernel.org)
[![Shell](https://img.shields.io/badge/shell-Bash-4EAA25?style=flat-square&logo=gnubash)](https://www.gnu.org/software/bash/)

### One script. Your system. Ready.

*Complete system clone — CachyOS · KDE Plasma · Hyprland · Noctalia Shell*

</div>

---

## System

| | Component | Detail |
|:---:|---|---|
| 🐧 | **Distro** | CachyOS (Arch-based) — recommended |
| 🔧 | **Kernel** | linux-cachyos-bore |
| 🖥️ | **Desktop** | KDE Plasma + Hyprland |
| 🔵 | **Shell** | Noctalia Shell |
| 🖵 | **Terminal** | Kitty / Alacritty |
| 🐟 | **Shell CLI** | Fish + Starship |
| 🎨 | **GTK Theme** | adw-gtk3-dark |
| 🖼️ | **Icons** | Yaru-blue-dark |
| 🖱️ | **Cursor** | Bibata-Modern-Classic |
| 🔵 | **Accent color** | `#5b9fef` (blue) |

> **Tested on:** CachyOS (Arch-based) — recommended.
> **Compatible with:** all Arch-based distributions (Arch Linux, EndeavourOS, Manjaro, etc.)

### Screenshot

![Screenshot](./assets/screenshot.png)

> Replace this placeholder with a real screenshot of your desktop.

---

## Requirements

Before running the script, make sure you have:

- A **fresh CachyOS base installation** (recommended) or any Arch-based distro
- An active **internet connection**
- At least **10 GB of free disk space**
- The script must be run as root via `sudo`

---

## Installation

```bash
git clone https://github.com/Dexmodzz/easylinux-dotfiles.git
cd easylinux-dotfiles
sudo bash install.sh
```

For a dry run (simulates everything, no changes applied):

```bash
sudo bash install.sh --dry-run
```

The script walks you through an interactive setup before applying anything:

| Option | Available choices |
|---|---|
| GPU | NVIDIA (nvidia-open) · AMD (mesa/vulkan) · Intel · Skip |
| Printer support | Yes · No |
| Bluetooth | Yes · No |
| Audio | Skip · EasyEffects · Dolby Atmos |
| Gaming packages | steam · mangohud · protonplus · wine · winetricks · protontricks · lutris · heroic · prismlauncher · goverlay · mangojuice · All · Skip |
| Audio/Video players | mpv · vlc · haruna · deadbeef · rhythmbox · All · Skip |
| Browser | Brave Origin Nightly · Firefox · LibreWolf · Vivaldi · Zen Browser · Skip |
| Cosmic Store | Yes · No |
| Laptop (battery) | Yes (auto-cpufreq) · No |
| ddcutil | Yes · No |

After reviewing the summary box, confirm to start. The script will offer a reboot when finished.

---

## What's Included

Everything below is installed and configured **automatically**:

- 🔧 **CachyOS repositories** — auto-detects your CPU variant (generic / v3 AVX2 / v4 AVX-512)
- 🐚 **linux-cachyos-bore kernel** + headers, initramfs regenerated automatically
- 🖥️ **KDE Plasma** — sddm, plasma-nm, plasma-pa, kscreen, kwallet
- 🪟 **Hyprland** — hyprlock, hypridle, hyprshot, uwsm, xdg-desktop-portal
- 🐟 **Fish shell** set as default + Starship prompt
- 🖵 **Kitty** and **Alacritty** terminals with Noctalia theme applied
- 🎨 **GTK/Qt themes** — adw-gtk3-dark, Yaru-blue-dark icons, Bibata-Modern-Classic cursor
- 🔵 **Noctalia Shell** + noctalia-qs (AUR) with `#5b9fef` accent color
- 💻 **VSCodium** (AUR)
- 📦 **Flatpak** + Flathub remote configured
- 🔊 **PipeWire** audio stack — pipewire-alsa, pipewire-pulse, wireplumber
- 🖨️ **CUPS** printing stack (optional)
- 📶 **Bluetooth** — bluez, blueman, service enabled (optional)
- 🔋 **auto-cpufreq** for laptop battery management (optional)
- 🔆 **ddcutil** for DDC/CI monitor brightness control (optional)
- 🗂️ **Thunar** file manager with plugins + default MIME associations
- 🅰️ **Fonts** — Noto, DejaVu, Liberation, Meslo Nerd, MS Fonts, Symbola
- ⚙️ **All dotfiles** deployed to `~/.config/`
- 🔒 **gsettings** applied — GTK theme, icon theme, cursor, dark color scheme
- 🥾 **Bootloader** updated automatically — Limine detected or GRUB updated via `update-grub`

---

## What's NOT Included

These must be configured **manually** after the installation:

- **`monitors.conf`** — The script creates a placeholder. Edit it with your actual monitor configuration:
  ```ini
  # Example
  monitor=DP-1,2560x1440@144,0x0,1
  monitor=HDMI-A-1,1920x1080@60,2560x0,1
  ```
  See the [Hyprland monitor documentation](https://wiki.hyprland.org/Configuring/Monitors/).

- **Locale and timezone** — Not modified by the script. Configure with `localectl` and `timedatectl`.

- **User passwords** — Not set or changed.

- **Hybrid GPU setups** — NVIDIA Optimus or AMD+Intel hybrid configurations require manual tuning.

---

## Troubleshooting

### Black screen after reboot (NVIDIA)

Verify the kernel module is loaded:
```bash
uname -r        # should contain 'cachyos' or 'bore'
lsmod | grep nvidia
```
If the module is missing, reinstall:
```bash
sudo pacman -S linux-cachyos-bore-nvidia-open nvidia-utils
sudo mkinitcpio -P
sudo reboot
```

### No audio (sof-firmware)

If audio devices are not detected after reboot:
```bash
sudo pacman -S sof-firmware alsa-firmware
sudo reboot
```
Then open `pavucontrol` and verify the correct output device is selected.

### Monitor not detected (monitors.conf)

If Hyprland starts but the display is blank or at the wrong resolution:
```bash
hyprctl monitors    # list detected outputs
nano ~/.config/hypr/monitors.conf
```
Use the output names returned by `hyprctl monitors` in your configuration.

### Hyprland not loading theme or colors

Make sure `~/.config/hypr/hyprland.conf` includes:
```ini
source = ~/.config/hypr/themes/theme.conf
source = ~/.config/hypr/noctalia/noctalia-colors.conf
```

---

## Structure

```
easylinux-dotfiles/
├── install.sh                ← main installer script
├── pkglist-explicit.txt      ← full explicit package list (pacman -Qqe)
├── pkglist-aur.txt           ← AUR packages list
└── .config/
    ├── hypr/                 ← Hyprland: keybinds, animations, window rules, startup, scripts
    ├── noctalia/             ← Noctalia Shell: colors.json, settings.json, plugins.json
    ├── kitty/                ← Kitty terminal config + Noctalia color theme
    ├── alacritty/            ← Alacritty terminal config + Noctalia color theme
    ├── fish/                 ← Fish shell config and environment variables
    ├── starship.toml         ← Starship prompt configuration
    ├── fastfetch/            ← System info screen config + ASCII logo
    ├── gtk-3.0/              ← GTK3 settings: theme, icons, cursor, bookmarks
    ├── gtk-4.0/              ← GTK4 settings
    ├── qt5ct/                ← Qt5 theme: Breeze style + Noctalia color palette
    ├── qt6ct/                ← Qt6 theme: Breeze style + Noctalia color palette
    ├── kdeglobals            ← KDE global settings: theme, fonts, colors
    ├── kwinrc                ← KWin window manager settings
    ├── plasmashellrc         ← Plasma shell configuration
    ├── kscreenlockerrc       ← KDE screen locker configuration
    └── kwalletrc             ← KWallet configuration
```

---

## Contributing

Found a missing package, a broken step, or a distro-specific issue?
Open an [issue](https://github.com/Dexmodzz/easylinux-dotfiles/issues) or submit a [pull request](https://github.com/Dexmodzz/easylinux-dotfiles/pulls) — all contributions are welcome.

When reporting a bug, please include:
- Your distro and kernel version (`uname -r`)
- The relevant section of `/tmp/noctalia-install-*.log`
- Steps to reproduce the problem

---

## Credits & Links

Inspired by [minimaLinux](https://github.com/Echilonvibin/minimaLinux) by **Echilonvibin**.

| Resource | Link |
|---|---|
| 📖 Hyprland wiki | https://wiki.hyprland.org |
| 🐧 CachyOS | https://cachyos.org |
| 🔵 Noctalia Shell | https://github.com/nicheface/noctalia-shell |

---

<div align="center">

Released under the **MIT License** — use it, fork it, break it, improve it.

</div>
