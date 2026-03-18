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

# ── Helpers ──
backup_and_link() {
    local src="$1" dest="$2"
    mkdir -p "$(dirname "$dest")"

    # Already correct symlink — skip
    if [ -L "$dest" ] && [ "$(readlink -f "$dest")" = "$(readlink -f "$src")" ]; then
        return 1
    fi

    # Exists but not a symlink (or wrong target) — backup
    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
        cp -r "$dest" "$dest.bak.$(date +%s)"
        ok "backed up $(basename "$dest")"
    fi

    rm -rf "$dest"
    ln -sf "$src" "$dest"
    return 0
}

echo ""
echo -e "${CYAN}┌─────────────────────────────────────┐${NC}"
echo -e "${CYAN}│${NC}   dotfiles updater // tarzZan52      ${CYAN}│${NC}"
echo -e "${CYAN}└─────────────────────────────────────┘${NC}"
echo ""

# ── Step 1: Pull latest changes ──
info "Pulling latest changes..."
if git -C "$DOTFILES_DIR" pull --ff-only 2>/dev/null; then
    ok "Repo up to date"
else
    warn "Could not fast-forward — you may have local changes"
    warn "Run 'git -C $DOTFILES_DIR status' to check"
fi

# ── Step 2: Re-link configs ──
UPDATED=0
SKIPPED=0

info "Syncing config symlinks..."

# ~/.config directories
CONFIG_DIRS=(
    niri waybar kitty foot fuzzel tofi swaylock mako
    fastfetch nvim superfile spotify-player trmt
    gtk-3.0 gtk-4.0 qt5ct qt6ct Kvantum xsettingsd nwg-look
)

for dir in "${CONFIG_DIRS[@]}"; do
    if [ -d "$DOTFILES_DIR/.config/$dir" ]; then
        if backup_and_link "$DOTFILES_DIR/.config/$dir" "$HOME/.config/$dir"; then
            ok "linked $dir"
            UPDATED=$((UPDATED + 1))
        else
            SKIPPED=$((SKIPPED + 1))
        fi
    fi
done

# starship.toml
if [ -f "$DOTFILES_DIR/.config/starship.toml" ]; then
    if backup_and_link "$DOTFILES_DIR/.config/starship.toml" "$HOME/.config/starship.toml"; then
        ok "linked starship.toml"
        UPDATED=$((UPDATED + 1))
    else
        SKIPPED=$((SKIPPED + 1))
    fi
fi

# Home dotfiles
for f in .zshrc .gitconfig .gtkrc-2.0; do
    if [ -f "$DOTFILES_DIR/$f" ]; then
        if backup_and_link "$DOTFILES_DIR/$f" "$HOME/$f"; then
            ok "linked $f"
            UPDATED=$((UPDATED + 1))
        else
            SKIPPED=$((SKIPPED + 1))
        fi
    fi
done

# SSH config
if [ -f "$DOTFILES_DIR/.ssh/config" ]; then
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    if backup_and_link "$DOTFILES_DIR/.ssh/config" "$HOME/.ssh/config"; then
        chmod 600 "$HOME/.ssh/config"
        ok "linked .ssh/config"
        UPDATED=$((UPDATED + 1))
    else
        SKIPPED=$((SKIPPED + 1))
    fi
fi

# Local bin scripts
if [ -d "$DOTFILES_DIR/.local/bin" ]; then
    mkdir -p "$HOME/.local/bin"
    for script in "$DOTFILES_DIR/.local/bin/"*; do
        [ -f "$script" ] || continue
        name="$(basename "$script")"
        if backup_and_link "$script" "$HOME/.local/bin/$name"; then
            chmod +x "$script"
            ok "linked $name"
            UPDATED=$((UPDATED + 1))
        else
            SKIPPED=$((SKIPPED + 1))
        fi
    done
fi

# Desktop entries
if [ -d "$DOTFILES_DIR/.local/share/applications" ]; then
    mkdir -p "$HOME/.local/share/applications"
    for desktop in "$DOTFILES_DIR/.local/share/applications/"*.desktop; do
        [ -f "$desktop" ] || continue
        name="$(basename "$desktop")"
        if backup_and_link "$desktop" "$HOME/.local/share/applications/$name"; then
            ok "linked $name"
            UPDATED=$((UPDATED + 1))
        else
            SKIPPED=$((SKIPPED + 1))
        fi
    done
fi

# ── Step 3: Copy wallpapers ──
if [ -d "$DOTFILES_DIR/wallpapers" ]; then
    mkdir -p "$HOME/Pictures/Wallpaper-Bank/wallpapers"
    NEW_WP=0
    for wp in "$DOTFILES_DIR/wallpapers/"*; do
        [ -f "$wp" ] || continue
        name="$(basename "$wp")"
        if [ ! -f "$HOME/Pictures/Wallpaper-Bank/wallpapers/$name" ]; then
            cp "$wp" "$HOME/Pictures/Wallpaper-Bank/wallpapers/$name"
            ok "new wallpaper: $name"
            NEW_WP=$((NEW_WP + 1))
        fi
    done
    [ "$NEW_WP" -eq 0 ] && ok "wallpapers up to date" || ok "$NEW_WP new wallpaper(s) added"
fi

# ── Summary ──
echo ""
echo -e "${GREEN}Update complete:${NC} ${BOLD}$UPDATED${NC} linked, ${BOLD}$SKIPPED${NC} already current"
echo ""
