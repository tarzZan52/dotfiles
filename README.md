# dotfiles

Arch Linux ARM (aarch64) rice with Niri + Waybar + Foot/Kitty on Wayland.

## Screenshots

> TODO: add screenshots

## Stack

| Layer | Tool | Theme |
|-------|------|-------|
| Compositor | [Niri](https://github.com/YaLTeR/niri) | — |
| Status bar | [Waybar](https://github.com/Alexays/Waybar) | Catppuccin Mocha |
| Terminal (main) | [Foot](https://codeberg.org/dnkl/foot) | Tokyo Night |
| Terminal (alt) | [Kitty](https://sw.kovidgoyal.net/kitty/) | Nord |
| Shell | Zsh + [Starship](https://starship.rs) + [Zoxide](https://github.com/ajeetdsouza/zoxide) | Tokyo Night Rounded |
| Editor | [Neovim](https://neovim.io) (AstroNvim v5) | AstroDark |
| Launcher | [Fuzzel](https://codeberg.org/dnkl/fuzzel) / [Tofi](https://github.com/philj56/tofi) | Tokyo Night / Nord |
| Lock screen | [swaylock-effects](https://github.com/jirutka/swaylock-effects) | Cyberpunk Neon |
| Notifications | [Mako](https://github.com/emersion/mako) | Catppuccin |
| File manager | [Superfile](https://github.com/yorukot/superfile) / Thunar | Nord |
| Music | [spotify-player](https://github.com/aome510/spotify-player) | Dracula |
| Fetch | [Fastfetch](https://github.com/fastfetch-cli/fastfetch) | Custom |
| GTK | Tokyonight-Dark + Tokyonight-Light icons | — |
| Qt | Kvantum (KvArcDark) | — |
| Font | JetBrainsMono Nerd Font | — |

## Features

- **Niri** tiling Wayland compositor with vim-style navigation (`Mod+HJKL`), 10 workspaces, rounded corners, shadows
- **Waybar** with Chinese numeral workspace icons (一二三...), MPRIS media widget, custom Python scripts for album art caching and player popup
- **Starship** multiline prompt with powerline pills — git status, language versions, memory, time
- **Swaylock** cyberpunk lock screen with blur, vignette, neon indicator rings
- **Dual terminal** setup — Foot (main, transparent) and Kitty (alternate, with vim-slime)
- **Music integration** — art-cacher.py caches Yandex Music/Spotify album covers, player-popup.py shows GTK3 media controls via GtkLayerShell
- **Full theming** — GTK 2/3/4, Qt 5/6, Kvantum, xsettingsd all consistently themed

## Quick install

```bash
bash <(curl -sL https://raw.githubusercontent.com/tarzZan52/dotfiles/main/install-remote.sh)
```

## Manual install

```bash
git clone https://github.com/tarzZan52/dotfiles.git ~/dotfiles
cd ~/dotfiles
bash install.sh
```

The installer will:
1. Install packages via `pacman` + AUR helper (paru/yay)
2. Download Tokyonight GTK/icon theme
3. Symlink all configs to their proper locations (existing files are backed up as `.bak`)
4. Check that all dependencies are present

## Structure

```
dotfiles/
├── .config/
│   ├── niri/              # compositor config + wallpaper script
│   ├── waybar/            # bar config, styles, art-cacher & player-popup
│   ├── kitty/             # terminal (Nord theme)
│   ├── foot/              # terminal (Tokyo Night)
│   ├── fuzzel/            # app launcher
│   ├── tofi/              # app launcher (fullscreen)
│   ├── swaylock/          # lock screen (cyberpunk)
│   ├── mako/              # notifications
│   ├── starship.toml      # shell prompt
│   ├── fastfetch/         # system info + ascii logo
│   ├── nvim/              # AstroNvim v5 config
│   ├── superfile/         # TUI file manager
│   ├── spotify-player/    # Spotify TUI
│   ├── trmt/              # turing machine animation
│   ├── gtk-3.0/           # GTK3 theme
│   ├── gtk-4.0/           # GTK4 theme
│   ├── qt5ct/             # Qt5 theme
│   ├── qt6ct/             # Qt6 theme
│   ├── Kvantum/           # Kvantum engine
│   ├── xsettingsd/        # X settings
│   └── nwg-look/          # GTK configurator
├── .local/
│   ├── bin/nvim-foot      # launch nvim in foot terminal
│   └── share/applications/
│       └── nvim.desktop   # desktop entry for nvim
├── .ssh/config            # SSH host config (no keys)
├── .zshrc                 # shell config
├── .gitconfig             # git identity
├── .gtkrc-2.0             # GTK2 theme
├── install.sh             # main installer
└── install-remote.sh      # one-liner bootstrap
```

## Keybinds (Niri)

| Key | Action |
|-----|--------|
| `Mod+T` | Terminal (foot) |
| `Mod+D` | App launcher (fuzzel) |
| `Mod+E` | File manager (thunar) |
| `Mod+Q` | Close window |
| `Mod+H/J/K/L` | Focus left/down/up/right |
| `Mod+Ctrl+H/J/K/L` | Move window |
| `Mod+1-9,0` | Switch workspace |
| `Mod+Shift+1-9,0` | Move window to workspace |
| `Mod+F` | Maximize column |
| `Mod+Shift+F` | Fullscreen |
| `Mod+V` | Toggle floating |
| `Mod+O` | Overview |
| `Mod+W` | Random wallpaper |
| `Mod+Shift+S` | Screenshot |
| `Super+Alt+L` | Lock screen |
| `Mod+Shift+E` | Quit niri |

## Dependencies

```bash
# Core
sudo pacman -S niri waybar foot kitty swaybg fuzzel tofi mako swaylock
sudo pacman -S zsh starship zoxide fastfetch neovim superfile thunar
sudo pacman -S playerctl brightnessctl pipewire wireplumber pavucontrol
sudo pacman -S ttf-jetbrains-mono-nerd otf-firamono-nerd

# Theming
sudo pacman -S nwg-look kvantum qt5ct qt6ct xsettingsd

# Utils
sudo pacman -S rsync curl unzip python-gobject gtk-layer-shell trmt

# AUR
paru -S swaylock-effects-git spotify-player
```
