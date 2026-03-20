#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Colors ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${BLUE}::${NC} $1"; }
ok()    { echo -e "  ${GREEN}✓${NC} $1"; }
warn()  { echo -e "  ${YELLOW}!${NC} $1"; }
err()   { echo -e "  ${RED}✗${NC} $1"; }
step()  { echo ""; echo -e "${CYAN}━━━ ${BOLD}$1${NC}"; }

ERRORS=()

# ── Packages ──
PACMAN_PKGS=(
    # core
    base-devel git curl rsync unzip

    # shell
    zsh starship zoxide fastfetch
    zsh-autosuggestions zsh-syntax-highlighting

    # terminals
    foot kitty

    # compositor & desktop
    niri waybar swaybg swaylock fuzzel tofi mako
    playerctl brightnessctl

    # wayland utils
    wl-clipboard grim slurp libnotify xdg-utils

    # editor
    neovim

    # file managers
    thunar superfile

    # theming
    nwg-look kvantum qt5ct qt6ct xsettingsd

    # fonts
    ttf-jetbrains-mono-nerd otf-firamono-nerd otf-font-awesome
    noto-fonts-cjk

    # media
    pipewire wireplumber pavucontrol

    # python (for waybar scripts)
    python python-gobject gtk-layer-shell

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

install_paru() {
    info "Installing paru (AUR helper)..."
    local tmpdir
    tmpdir="$(mktemp -d)"
    git clone https://aur.archlinux.org/paru-bin.git "$tmpdir/paru-bin"
    (cd "$tmpdir/paru-bin" && makepkg -si --noconfirm)
    rm -rf "$tmpdir"
    if command -v paru &>/dev/null; then
        ok "paru installed"
    else
        err "paru installation failed"
        ERRORS+=("paru installation failed")
    fi
}

# ── Main ──
echo ""
echo -e "${CYAN}┌─────────────────────────────────────┐${NC}"
echo -e "${CYAN}│${NC}   dotfiles installer // tarzZan52   ${CYAN}│${NC}"
echo -e "${CYAN}└─────────────────────────────────────┘${NC}"
echo ""

# ── Check: Arch Linux ──
if ! command -v pacman &>/dev/null; then
    err "This installer requires Arch Linux (pacman not found)."
    exit 1
fi

# ── Step 1: System update & packages ──
step "Step 1/8 — Installing pacman packages"
info "Updating system and installing packages..."
if ! sudo pacman -Syu --needed --noconfirm "${PACMAN_PKGS[@]}"; then
    warn "Some pacman packages may have failed — check output above"
    ERRORS+=("Some pacman packages failed to install")
fi

# ── Step 2: AUR helper & packages ──
step "Step 2/8 — AUR packages"
AUR_HELPER=""
for helper in paru yay; do
    if command -v "$helper" &>/dev/null; then
        AUR_HELPER="$helper"
        break
    fi
done

if [ -z "$AUR_HELPER" ]; then
    warn "No AUR helper found — installing paru..."
    install_paru
    AUR_HELPER="paru"
fi

if command -v "$AUR_HELPER" &>/dev/null; then
    info "Installing AUR packages with $AUR_HELPER..."
    if ! $AUR_HELPER -S --needed --noconfirm "${AUR_PKGS[@]}"; then
        warn "Some AUR packages may have failed — check output above"
        ERRORS+=("Some AUR packages failed to install")
    fi
else
    err "No AUR helper available — skipping AUR packages"
    err "Packages needed manually: ${AUR_PKGS[*]}"
    ERRORS+=("AUR packages not installed: ${AUR_PKGS[*]}")
fi

# ── Step 3: Install GTK theme & icons ──
step "Step 3/8 — Themes & icons"
THEME_DIR="$HOME/.local/share/themes"
ICON_DIR="$HOME/.local/share/icons"
mkdir -p "$THEME_DIR" "$ICON_DIR"

# GTK theme via AUR (builds from source with sassc)
info "Installing Tokyonight GTK theme..."
if pacman -Qi tokyonight-gtk-theme-git &>/dev/null; then
    ok "GTK theme already installed (AUR)"
elif command -v paru &>/dev/null; then
    if paru -S --needed --noconfirm tokyonight-gtk-theme-git; then
        ok "GTK theme installed"
    else
        err "Failed to install GTK theme from AUR"
        ERRORS+=("GTK theme install failed")
    fi
elif command -v yay &>/dev/null; then
    if yay -S --needed --noconfirm tokyonight-gtk-theme-git; then
        ok "GTK theme installed"
    else
        err "Failed to install GTK theme from AUR"
        ERRORS+=("GTK theme install failed")
    fi
else
    err "No AUR helper available — cannot install GTK theme"
    ERRORS+=("GTK theme: no AUR helper")
fi

# Icon theme (clone from repo — not included in AUR package)
info "Installing Tokyonight icon theme..."
if [ ! -d "$ICON_DIR/Tokyonight-Light" ]; then
    ICON_BUILD="$(mktemp -d /tmp/tokyonight_icons.XXXXXX)"
    if git clone --depth=1 --filter=blob:none --sparse \
        https://github.com/Fausto-Korpsvart/Tokyonight-GTK-Theme.git "$ICON_BUILD" 2>/dev/null; then
        (cd "$ICON_BUILD" && git sparse-checkout set icons/Tokyonight-Light) 2>/dev/null
        if [ -d "$ICON_BUILD/icons/Tokyonight-Light" ]; then
            cp -r "$ICON_BUILD/icons/Tokyonight-Light" "$ICON_DIR/Tokyonight-Light"
            ok "Icon theme installed"
        else
            err "Icon theme directory not found in repo"
            ERRORS+=("Icon theme: directory not found")
        fi
    else
        err "Failed to clone icon theme repo"
        ERRORS+=("Icon theme: git clone failed")
    fi
    rm -rf "$ICON_BUILD"
else
    ok "Icon theme already installed"
fi

# Update icon cache
if command -v gtk-update-icon-cache &>/dev/null && [ -d "$ICON_DIR/Tokyonight-Light" ]; then
    gtk-update-icon-cache -f "$ICON_DIR/Tokyonight-Light" 2>/dev/null && ok "Icon cache updated" || true
fi

# ── Step 4: Kvantum theme ──
step "Step 4/8 — Kvantum Qt theme"
if command -v kvantummanager &>/dev/null; then
    kvantummanager --set KvArcDark 2>/dev/null && ok "Kvantum theme set to KvArcDark" || warn "Could not set Kvantum theme"
else
    warn "kvantummanager not found — skipping Kvantum theme setup"
fi

# ── Step 5: Symlink dotfiles ──
step "Step 5/8 — Symlinking config files"

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
if [ -f "$DOTFILES_DIR/.config/starship.toml" ]; then
    backup_and_link "$DOTFILES_DIR/.config/starship.toml" "$HOME/.config/starship.toml"
fi

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

# ── Step 6: Create required directories ──
step "Step 6/8 — Creating directories"

mkdir -p "$HOME/Pictures/Wallpaper-Bank/wallpapers"
ok "Wallpaper directory: ~/Pictures/Wallpaper-Bank/wallpapers/"

mkdir -p "$HOME/Pictures/Screenshots"
ok "Screenshots directory: ~/Pictures/Screenshots/"

# Copy bundled wallpapers
if [ -d "$DOTFILES_DIR/wallpapers" ]; then
    info "Copying bundled wallpapers..."
    cp -n "$DOTFILES_DIR/wallpapers/"* "$HOME/Pictures/Wallpaper-Bank/wallpapers/" 2>/dev/null || true
    WP_COUNT=$(find "$DOTFILES_DIR/wallpapers" -type f | wc -l)
    ok "Copied $WP_COUNT wallpaper(s) to ~/Pictures/Wallpaper-Bank/wallpapers/"
fi

# ── Step 7: Shell & services ──
step "Step 7/8 — Shell & services"

# Change default shell to zsh
CURRENT_SHELL="$(getent passwd "$USER" | cut -d: -f7)"
if [ "$CURRENT_SHELL" != "$(command -v zsh)" ]; then
    info "Changing default shell to zsh..."
    if chsh -s "$(command -v zsh)"; then
        ok "Default shell changed to zsh"
    else
        warn "Could not change shell — run manually: chsh -s $(command -v zsh)"
        ERRORS+=("Failed to change default shell to zsh")
    fi
else
    ok "Default shell is already zsh"
fi

# Enable PipeWire & WirePlumber
info "Enabling audio services..."
systemctl --user enable --now pipewire.socket 2>/dev/null && ok "pipewire.socket enabled" || warn "Could not enable pipewire.socket"
systemctl --user enable --now wireplumber.service 2>/dev/null && ok "wireplumber.service enabled" || warn "Could not enable wireplumber.service"
systemctl --user enable --now pipewire-pulse.socket 2>/dev/null && ok "pipewire-pulse.socket enabled" || warn "Could not enable pipewire-pulse.socket"

# ── Step 8: Verify installation ──
step "Step 8/8 — Verifying installation"

echo ""
info "Checking binaries..."
BINS=(
    zsh starship zoxide fastfetch
    foot kitty
    niri waybar swaybg swaylock fuzzel tofi mako
    playerctl brightnessctl wpctl
    grim slurp wl-copy notify-send xdg-open
    nvim thunar
    pavucontrol nwg-look kvantummanager
    python3
)
for cmd in "${BINS[@]}"; do
    if command -v "$cmd" &>/dev/null; then
        ok "$cmd"
    else
        err "$cmd not found"
        ERRORS+=("Binary not found: $cmd")
    fi
done

# Check fonts
echo ""
info "Checking fonts..."
if command -v fc-list &>/dev/null; then
    for font in "JetBrainsMono Nerd Font" "FiraMono Nerd Font" "Font Awesome" "Noto Sans CJK"; do
        if fc-list 2>/dev/null | grep -qi "$font"; then
            ok "$font"
        else
            err "$font not found"
            ERRORS+=("Font not found: $font")
        fi
    done
else
    warn "fc-list not available — cannot verify fonts"
fi

# Check zsh plugins
echo ""
info "Checking zsh plugins..."
for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
    if [ -d "/usr/share/zsh/plugins/$plugin" ]; then
        ok "$plugin"
    else
        err "$plugin not found"
        ERRORS+=("Plugin not found: $plugin")
    fi
done

# Check themes
echo ""
info "Checking themes..."
if pacman -Qi tokyonight-gtk-theme-git &>/dev/null; then
    ok "Tokyonight GTK theme"
else
    err "Tokyonight GTK theme not found"
    ERRORS+=("Tokyonight GTK theme missing")
fi

if [ -d "$HOME/.local/share/icons/Tokyonight-Light" ]; then
    ok "Tokyonight icon theme"
else
    err "Tokyonight icon theme not found"
    ERRORS+=("Tokyonight icon theme missing")
fi

# Check services
echo ""
info "Checking audio services..."
for svc in pipewire.socket wireplumber.service pipewire-pulse.socket; do
    if systemctl --user is-active "$svc" &>/dev/null; then
        ok "$svc active"
    else
        warn "$svc not active"
    fi
done

# ── Summary ──
echo ""
if [ ${#ERRORS[@]} -eq 0 ]; then
    echo -e "${GREEN}┌─────────────────────────────────────┐${NC}"
    echo -e "${GREEN}│${NC}   Installation complete! ${GREEN}✓${NC}           ${GREEN}│${NC}"
    echo -e "${GREEN}│${NC}   Everything installed perfectly.   ${GREEN}│${NC}"
    echo -e "${GREEN}│${NC}   Open a new terminal to see it.   ${GREEN}│${NC}"
    echo -e "${GREEN}└─────────────────────────────────────┘${NC}"
else
    echo -e "${YELLOW}┌─────────────────────────────────────────┐${NC}"
    echo -e "${YELLOW}│${NC}   Installation complete with warnings   ${YELLOW}│${NC}"
    echo -e "${YELLOW}└─────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "${YELLOW}Issues found (${#ERRORS[@]}):${NC}"
    for e in "${ERRORS[@]}"; do
        err "$e"
    done
    echo ""
    echo -e "  Open a new terminal to see changes."
fi

echo ""
info "Tips:"
echo -e "  • Put wallpapers in ${BOLD}~/Pictures/Wallpaper-Bank/wallpapers/${NC}"
echo -e "  • Press ${BOLD}Mod+W${NC} to randomize wallpaper"
echo -e "  • Press ${BOLD}Mod+T${NC} for terminal, ${BOLD}Mod+D${NC} for launcher"
echo -e "  • Run ${BOLD}niri${NC} from your display manager or TTY"
echo ""
