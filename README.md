<h1 align="center">
  <img src="https://raw.githubusercontent.com/tarzZan52/dotfiles/main/assets/screenshot.jpg" width="800"/>
  <br/>
  <br/>
  <img src="https://img.shields.io/badge/Arch_Linux-1793D1?style=for-the-badge&logo=arch-linux&logoColor=white"/>
  <img src="https://img.shields.io/badge/Wayland-FFB800?style=for-the-badge&logo=wayland&logoColor=black"/>
  <img src="https://img.shields.io/badge/Niri-7aa2f7?style=for-the-badge&logoColor=white"/>
  <img src="https://img.shields.io/badge/Neovim-57A143?style=for-the-badge&logo=neovim&logoColor=white"/>
  <img src="https://img.shields.io/badge/Tokyo_Night-1a1b26?style=for-the-badge"/>
</h1>

<p align="center">
  <b>Arch Linux ARM (aarch64) rice — Niri + Waybar + Foot/Kitty on Wayland</b>
</p>

<p align="center">
  <a href="#-stack">Stack</a> •
  <a href="#-features">Features</a> •
  <a href="#-quick-install">Install</a> •
  <a href="#-keybinds">Keybinds</a> •
  <a href="#-structure">Structure</a>
</p>

---

## 🧩 Stack

<table>
<tr><td><b>Layer</b></td><td><b>Tool</b></td><td><b>Theme</b></td></tr>
<tr><td>🖥 Compositor</td><td><a href="https://github.com/YaLTeR/niri">Niri</a></td><td>—</td></tr>
<tr><td>📊 Status bar</td><td><a href="https://github.com/Alexays/Waybar">Waybar</a></td><td>Catppuccin Mocha</td></tr>
<tr><td>⬛ Terminal</td><td><a href="https://codeberg.org/dnkl/foot">Foot</a></td><td>Tokyo Night</td></tr>
<tr><td>⬛ Terminal (alt)</td><td><a href="https://sw.kovidgoyal.net/kitty/">Kitty</a></td><td>Nord</td></tr>
<tr><td>🐚 Shell</td><td>Zsh + <a href="https://starship.rs">Starship</a> + <a href="https://github.com/ajeetdsouza/zoxide">Zoxide</a></td><td>Tokyo Night Rounded</td></tr>
<tr><td>📝 Editor</td><td><a href="https://neovim.io">Neovim</a> (AstroNvim v5)</td><td>AstroDark</td></tr>
<tr><td>🚀 Launcher</td><td><a href="https://codeberg.org/dnkl/fuzzel">Fuzzel</a> / <a href="https://github.com/philj56/tofi">Tofi</a></td><td>Tokyo Night / Nord</td></tr>
<tr><td>🔒 Lock screen</td><td><a href="https://github.com/jirutka/swaylock-effects">swaylock-effects</a></td><td>Cyberpunk Neon</td></tr>
<tr><td>🔔 Notifications</td><td><a href="https://github.com/emersion/mako">Mako</a></td><td>Catppuccin</td></tr>
<tr><td>📁 File manager</td><td><a href="https://github.com/yorukot/superfile">Superfile</a> / Thunar</td><td>Nord</td></tr>
<tr><td>🎵 Music</td><td><a href="https://github.com/aome510/spotify-player">spotify-player</a></td><td>Dracula</td></tr>
<tr><td>📋 Fetch</td><td><a href="https://github.com/fastfetch-cli/fastfetch">Fastfetch</a></td><td>Custom ASCII</td></tr>
<tr><td>🎨 GTK</td><td>Tokyonight-Dark + Tokyonight-Light icons</td><td>—</td></tr>
<tr><td>🎨 Qt</td><td>Kvantum (KvArcDark)</td><td>—</td></tr>
<tr><td>🔤 Font</td><td>JetBrainsMono Nerd Font</td><td>—</td></tr>
</table>

## ✨ Features

- **Niri** — tiling Wayland compositor, vim-style navigation (`Mod+HJKL`), 10 workspaces, rounded corners (16px), shadows
- **Waybar** — Chinese numeral workspace icons (一二三四五六七八九十), MPRIS media widget with colored player icons, custom Python scripts
- **Starship** — multiline prompt with powerline rounded pills, git status, language versions, memory usage, time
- **Swaylock** — cyberpunk lock screen with screenshot blur, vignette, neon indicator rings (magenta/cyan/amber/red states)
- **Dual terminal** — Foot (main, 85% opacity, Tokyo Night) and Kitty (alt, Nord, with vim-slime support)
- **Music integration** — `art-cacher.py` caches album art from Yandex Music / Spotify / Firefox MPRIS, `player-popup.py` shows GTK3 media controls with waveform animation via GtkLayerShell
- **Full theming** — GTK 2/3/4, Qt 5/6, Kvantum, xsettingsd all consistently themed with Tokyonight

## 🚀 Quick install

```bash
bash <(curl -sL https://raw.githubusercontent.com/tarzZan52/dotfiles/main/install-remote.sh)
```

### Manual install

```bash
git clone https://github.com/tarzZan52/dotfiles.git ~/dotfiles
cd ~/dotfiles
bash install.sh
```

The installer will:
1. Install packages via `pacman` + AUR helper (auto-installs `paru` if needed)
2. Download Tokyonight GTK + icon themes
3. Symlink all configs to their proper locations (existing files backed up as `.bak`)
4. Set default shell to zsh, enable PipeWire audio services
5. Verify all dependencies, fonts, themes, and services

### 🍎 Arch Linux ARM (VMware Fusion on Apple Silicon)

Separate installer for running this rice in a VMware Fusion VM on Apple Silicon Macs:

```bash
git clone https://github.com/tarzZan52/dotfiles.git ~/dotfiles
cd ~/dotfiles
bash install-arm-vmware.sh
```

This script handles the quirks of aarch64 VMs:
1. **Fixes TTY** — removes `kmscon` (blocks DRM node), restores `getty@tty1`, sets `multi-user.target`
2. **Graphics stack** — installs Mesa, VirGL, Wayland, XWayland for VMware's virtual GPU
3. **Builds `open-vm-tools` from source** — the official package is x86_64-only, so the script clones the Arch PKGBUILD, patches it for aarch64 (adds arch, fixes GCC `-Wno-discarded-qualifiers`, undefines `g_free` macro), and builds with `makepkg`
4. **Deploys configs** — copies dotfiles and patches `niri/config.kdl` to remove the fixed `mode` line so VMware can dynamically set the resolution
5. **No auto-start** — after reboot, log in at TTY1 and run `niri-session` manually

> **Note:** The ARM installer copies configs instead of symlinking them, so edits in `~/.config/` won't reflect back to the repo. This is intentional for a VM setup where you may want to diverge from the main config.

### Updating

Pull latest changes and re-sync all symlinks:

```bash
bash ~/dotfiles/update.sh
```

The updater will `git pull`, re-link any configs that drifted (backing up changed files), and copy new wallpapers.

## ⌨️ Keybinds

<details>
<summary><b>Niri keybinds (click to expand)</b></summary>

| Key | Action |
|-----|--------|
| `Mod+T` | Terminal (foot) |
| `Mod+D` | App launcher (fuzzel) |
| `Mod+E` | File manager (thunar) |
| `Mod+Q` | Close window |
| `Mod+O` | Overview |
| `Mod+H/J/K/L` | Focus left/down/up/right |
| `Mod+Ctrl+H/J/K/L` | Move window |
| `Mod+1-9, 0` | Switch workspace 1-10 |
| `Mod+Shift+1-9, 0` | Move window to workspace |
| `Mod+Ctrl+1-9, 0` | Move column to workspace |
| `Mod+F` | Maximize column |
| `Mod+Shift+F` | Fullscreen |
| `Mod+V` | Toggle floating |
| `Mod+Shift+V` | Switch focus floating/tiling |
| `Mod+C` | Center column |
| `Mod+R` | Cycle preset widths (⅓ → ½ → ⅔) |
| `Mod+[ / ]` | Consume/expel window |
| `Mod+, / .` | Consume into/expel from column |
| `Mod+- / =` | Resize column ±10% |
| `Mod+W` | Random wallpaper |
| `Mod+Shift+S` | Screenshot |
| `Super+Alt+L` | Lock screen |
| `Mod+Shift+E` | Quit niri |
| `XF86Audio*` | Volume / media controls |
| `XF86MonBrightness*` | Brightness ±10% |

</details>

## 📂 Structure

```
dotfiles/
├── .config/
│   ├── niri/                # compositor config + wallpaper script
│   │   ├── config.kdl
│   │   └── random-wallpaper.sh
│   ├── waybar/              # bar config, styles, python scripts
│   │   ├── config.jsonc
│   │   ├── style.css
│   │   ├── art-cacher.py    # album art caching daemon
│   │   └── player-popup.py  # GTK3 media popup
│   ├── kitty/               # terminal (Nord)
│   ├── foot/                # terminal (Tokyo Night)
│   ├── fuzzel/              # launcher
│   ├── tofi/                # launcher (fullscreen)
│   ├── swaylock/            # lock screen (cyberpunk)
│   ├── mako/                # notifications
│   ├── starship.toml        # shell prompt
│   ├── fastfetch/           # system info + ascii logo
│   ├── nvim/                # AstroNvim v5
│   ├── superfile/           # TUI file manager
│   ├── spotify-player/      # Spotify TUI
│   ├── trmt/                # turing machine animation
│   ├── gtk-3.0/             # GTK3 theme settings
│   ├── gtk-4.0/             # GTK4 theme settings
│   ├── qt5ct/               # Qt5 theme
│   ├── qt6ct/               # Qt6 theme
│   ├── Kvantum/             # Kvantum engine
│   ├── xsettingsd/          # X settings daemon
│   └── nwg-look/            # GTK configurator
├── .local/
│   ├── bin/nvim-foot        # launch nvim in foot
│   └── share/applications/
│       └── nvim.desktop     # desktop entry
├── .ssh/config              # SSH config (no keys)
├── .zshrc                   # zsh config
├── .gitconfig               # git identity
├── .gtkrc-2.0               # GTK2 theme
├── wallpapers/              # bundled wallpapers (copied to ~/Pictures/...)
├── assets/                  # screenshots
├── install.sh               # main installer (bare metal)
├── install-arm-vmware.sh    # installer for ARM VM (Apple Silicon + VMware)
├── install-remote.sh        # one-liner bootstrap
└── update.sh                # pull latest + re-sync symlinks
```

## 📦 Dependencies

<details>
<summary><b>Full package list (click to expand)</b></summary>

```bash
# Core desktop
sudo pacman -S niri waybar foot kitty swaybg fuzzel tofi mako swaylock

# Shell & tools
sudo pacman -S zsh starship zoxide fastfetch neovim superfile thunar

# Media & audio
sudo pacman -S playerctl brightnessctl pipewire wireplumber pavucontrol

# Fonts
sudo pacman -S ttf-jetbrains-mono-nerd otf-firamono-nerd otf-font-awesome noto-fonts-cjk

# Theming
sudo pacman -S nwg-look kvantum qt5ct qt6ct xsettingsd

# Utils
sudo pacman -S rsync curl unzip python-gobject gtk-layer-shell trmt

# AUR
paru -S swaylock-effects-git spotify-player
```

</details>

---

<p align="center">
  <sub>made with ☕ and too much time in the terminal</sub>
</p>
