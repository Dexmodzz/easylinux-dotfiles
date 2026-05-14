# easylinux-dotfiles

Clone completo del mio sistema CachyOS — installa tutto con un singolo script.

## Sistema

| Componente | Dettaglio |
|---|---|
| **Distro** | CachyOS (Arch-based) |
| **Kernel** | linux-cachyos-bore |
| **Desktop** | KDE Plasma + Hyprland |
| **Shell** | Noctalia Shell |
| **Terminale** | Kitty / Alacritty |
| **Shell CLI** | Fish + Starship |
| **Tema GTK** | adw-gtk3-dark |
| **Icone** | Yaru-blue-dark |
| **Cursore** | Bibata-Modern-Classic |
| **Colore accent** | `#5b9fef` (blu) |

## Installazione

Parti da una installazione fresca di **CachyOS base**, poi:

```bash
git clone https://github.com/dexmodzz/easylinux-dotfiles.git
cd easylinux-dotfiles
sudo bash install.sh
```

Lo script ti chiederà interattivamente:
- Tipo di GPU (NVIDIA / AMD / Intel)
- Pacchetti gaming (Steam, Lutris, Heroic, Proton...)
- Browser (Brave, Firefox, Zen, Vivaldi, LibreWolf)
- Player audio/video (mpv, VLC, Haruna...)
- Bluetooth, stampante, EasyEffects / Dolby Atmos
- ddcutil (controllo luminosità monitor via DDC/CI)

Al termine riavvia e il sistema è pronto.

## Configurazione monitor

Il file `~/.config/hypr/monitors.conf` viene creato come placeholder — **devi configurarlo** con la risoluzione del tuo monitor:

```ini
# Esempio
monitor=DP-1,1920x1080@144,0x0,1
monitor=HDMI-A-1,1920x1080@60,1920x0,1
```

Vedi la [documentazione Hyprland](https://wiki.hyprland.org/Configuring/Monitors/).

## Struttura

```
easylinux-dotfiles/
├── install.sh              ← script principale
├── pkglist-explicit.txt    ← lista pacchetti installati esplicitamente
├── pkglist-aur.txt         ← pacchetti AUR
└── .config/
    ├── hypr/               ← Hyprland (keybinds, animazioni, regole...)
    ├── noctalia/           ← Noctalia Shell (colori, settings, plugins)
    ├── kitty/              ← terminale Kitty
    ├── alacritty/          ← terminale Alacritty
    ├── fish/               ← shell Fish
    ├── starship.toml       ← prompt Starship
    ├── fastfetch/          ← schermata di sistema
    ├── gtk-3.0/            ← tema GTK3
    ├── gtk-4.0/            ← tema GTK4
    ├── qt6ct/              ← tema Qt6
    ├── qt5ct/              ← tema Qt5
    └── kdeglobals          ← impostazioni KDE
```

## Crediti

Ispirato a [minimaLinux](https://github.com/Echilonvibin/minimaLinux) di Echilonvibin.
