#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Colors ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${BLUE}::${NC} $1"; }
ok()    { echo -e "  ${GREEN}✓${NC} $1"; }
warn()  { echo -e "  ${YELLOW}!${NC} $1"; }
err()   { echo -e "  ${RED}✗${NC} $1"; }

# ── Packages ──
PACMAN_PKGS=(
    # shell
    zsh starship zoxide fastfetch
    zsh-autosuggestions zsh-syntax-highlighting
    # terminals
    foot kitty
    # compositor & desktop
    niri waybar swaybg swaylock fuzzel tofi mako
    playerctl brightnessctl
    # editor
    neovim
    # file managers
    thunar superfile
    # theming
    nwg-look kvantum qt5ct qt6ct xsettingsd
    # fonts
    ttf-jetbrains-mono-nerd otf-firamono-nerd
    # media
    pipewire wireplumber pavucontrol
    # utils
    rsync curl unzip python-gobject gtk-layer-shell
    # fun
    trmt
)

AUR_PKGS=(
    swaylock-effects-git
    spotify-player
)

# ── Helpers ──
backup_and_link() {
    local src="$1" dest="$2"
    mkdir -p "$(dirname "$dest")"
    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
        cp -r "$dest" "$dest.bak"
        ok "backed up $(basename "$dest") → $(basename "$dest").bak"
    fi
    rm -rf "$dest"
    ln -sf "$src" "$dest"
    ok "linked $(basename "$dest")"
}

# ── Main ──
echo ""
echo -e "${CYAN}┌─────────────────────────────────────┐${NC}"
echo -e "${CYAN}│${NC}   dotfiles installer // tarzZan52   ${CYAN}│${NC}"
echo -e "${CYAN}└─────────────────────────────────────┘${NC}"
echo ""

# ── Step 1: Install packages ──
if command -v pacman &>/dev/null; then
    info "Installing packages with pacman..."
    sudo pacman -Syu --needed --noconfirm "${PACMAN_PKGS[@]}" 2>/dev/null || warn "some pacman packages failed"

    # AUR helper
    AUR_HELPER=""
    for helper in paru yay; do
        if command -v "$helper" &>/dev/null; then
            AUR_HELPER="$helper"
            break
        fi
    done

    if [ -n "$AUR_HELPER" ]; then
        info "Installing AUR packages with $AUR_HELPER..."
        $AUR_HELPER -S --needed --noconfirm "${AUR_PKGS[@]}" 2>/dev/null || warn "some AUR packages failed"
    else
        warn "no AUR helper found (paru/yay), skipping AUR packages"
        warn "AUR packages needed: ${AUR_PKGS[*]}"
    fi
else
    warn "pacman not found — skipping package install (Arch Linux only)"
fi

# ── Step 2: Install GTK theme ──
info "Installing Tokyonight GTK theme..."
THEME_DIR="$HOME/.local/share/themes"
ICON_DIR="$HOME/.local/share/icons"
mkdir -p "$THEME_DIR" "$ICON_DIR"

if [ ! -d "$THEME_DIR/Tokyonight-Dark" ]; then
    TMP_THEME="/tmp/tokyonight-gtk.tar.xz"
    if curl -sL "https://github.com/Fausto-Korpsvart/Tokyo-Night-GTK-Theme/releases/latest/download/Tokyonight-Dark-B-LB.tar.xz" -o "$TMP_THEME" 2>/dev/null; then
        tar -xf "$TMP_THEME" -C "$THEME_DIR" 2>/dev/null && ok "GTK theme installed" || warn "failed to extract GTK theme"
        rm -f "$TMP_THEME"
    else
        warn "failed to download GTK theme"
    fi
else
    ok "GTK theme already installed"
fi

if [ ! -d "$ICON_DIR/Tokyonight-Light" ]; then
    TMP_ICONS="/tmp/tokyonight-icons.tar.xz"
    if curl -sL "https://github.com/Fausto-Korpsvart/Tokyo-Night-GTK-Theme/releases/latest/download/Tokyonight-Light-Icons.tar.xz" -o "$TMP_ICONS" 2>/dev/null; then
        tar -xf "$TMP_ICONS" -C "$ICON_DIR" 2>/dev/null && ok "icon theme installed" || warn "failed to extract icon theme"
        rm -f "$TMP_ICONS"
    else
        warn "failed to download icon theme"
    fi
else
    ok "icon theme already installed"
fi

# ── Step 3: Symlink dotfiles ──
info "Linking config files..."

# ~/.config directories
CONFIG_DIRS=(
    niri waybar kitty foot fuzzel tofi swaylock mako
    fastfetch nvim superfile spotify-player trmt
    gtk-3.0 gtk-4.0 qt5ct qt6ct Kvantum xsettingsd nwg-look
)

for dir in "${CONFIG_DIRS[@]}"; do
    if [ -d "$DOTFILES_DIR/.config/$dir" ]; then
        backup_and_link "$DOTFILES_DIR/.config/$dir" "$HOME/.config/$dir"
    fi
done

# starship.toml (single file, not directory)
backup_and_link "$DOTFILES_DIR/.config/starship.toml" "$HOME/.config/starship.toml"

# Home dotfiles
for f in .zshrc .gitconfig .gtkrc-2.0; do
    if [ -f "$DOTFILES_DIR/$f" ]; then
        backup_and_link "$DOTFILES_DIR/$f" "$HOME/$f"
    fi
done

# SSH config
if [ -f "$DOTFILES_DIR/.ssh/config" ]; then
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    backup_and_link "$DOTFILES_DIR/.ssh/config" "$HOME/.ssh/config"
    chmod 600 "$HOME/.ssh/config"
fi

# Local bin scripts
if [ -d "$DOTFILES_DIR/.local/bin" ]; then
    mkdir -p "$HOME/.local/bin"
    for script in "$DOTFILES_DIR/.local/bin/"*; do
        [ -f "$script" ] || continue
        backup_and_link "$script" "$HOME/.local/bin/$(basename "$script")"
        chmod +x "$script"
    done
fi

# Desktop entries
if [ -d "$DOTFILES_DIR/.local/share/applications" ]; then
    mkdir -p "$HOME/.local/share/applications"
    for desktop in "$DOTFILES_DIR/.local/share/applications/"*.desktop; do
        [ -f "$desktop" ] || continue
        backup_and_link "$desktop" "$HOME/.local/share/applications/$(basename "$desktop")"
    done
fi

# ── Step 4: Check dependencies ──
echo ""
info "Checking dependencies..."

DEPS=(zsh starship zoxide fastfetch foot kitty niri waybar swaybg fuzzel mako nvim playerctl)
for cmd in "${DEPS[@]}"; do
    if command -v "$cmd" &>/dev/null; then
        ok "$cmd"
    else
        err "$cmd not found"
    fi
done

# Check fonts
if fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd Font"; then
    ok "JetBrainsMono Nerd Font"
else
    err "JetBrainsMono Nerd Font not found"
fi

# Check zsh plugins
for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
    if [ -d "/usr/share/zsh/plugins/$plugin" ]; then
        ok "$plugin"
    else
        err "$plugin not found"
    fi
done

# ── Done ──
echo ""
echo -e "${GREEN}┌─────────────────────────────────────┐${NC}"
echo -e "${GREEN}│${NC}   Installation complete!             ${GREEN}│${NC}"
echo -e "${GREEN}│${NC}   Open a new terminal to see it.     ${GREEN}│${NC}"
echo -e "${GREEN}└─────────────────────────────────────┘${NC}"
echo ""
