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

# ── Sanity checks ──
echo ""
echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│${NC}   dotfiles ARM VMware installer // tarzZan52  ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}   Arch Linux ARM (aarch64) + Niri + Wayland   ${CYAN}│${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"
echo ""

if ! command -v pacman &>/dev/null; then
    err "pacman not found — this script is for Arch Linux only."
    exit 1
fi

ARCH="$(uname -m)"
if [ "$ARCH" != "aarch64" ]; then
    warn "Detected architecture: $ARCH (expected aarch64)"
    warn "This script is designed for Arch Linux ARM on Apple Silicon VMs"
    read -rp "Continue anyway? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] || exit 0
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 1: Fix TTY & remove kmscon
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
step "Step 1/9 — Preparing system & fixing TTY"

# kmscon grabs the DRM node and blocks Niri/Wayland from accessing GPU
if pacman -Qi kmscon &>/dev/null; then
    info "Removing kmscon (blocks DRM node for Wayland)..."
    sudo pacman -Rns --noconfirm kmscon && ok "kmscon removed" || warn "Failed to remove kmscon"
else
    ok "kmscon not installed"
fi

info "Restoring standard TTY getty..."
sudo systemctl enable getty@tty1.service 2>/dev/null && ok "getty@tty1 enabled" || warn "getty@tty1 already enabled"

info "Setting boot target to multi-user (TTY login)..."
sudo systemctl set-default multi-user.target && ok "Default target: multi-user" || warn "Could not set default target"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 2: Graphics stack (VirGL / VMware)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
step "Step 2/9 — Installing graphics stack (Mesa + VirGL)"

GFX_PKGS=(mesa vulkan-virtio wayland xorg-xwayland xwayland-satellite)

info "Installing: ${GFX_PKGS[*]}"
if ! sudo pacman -S --needed --noconfirm "${GFX_PKGS[@]}"; then
    warn "Some graphics packages failed — check output above"
    ERRORS+=("Some graphics packages failed to install")
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 3: Niri + core desktop utilities
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
step "Step 3/9 — Installing Niri & desktop utilities"

DESKTOP_PKGS=(
    # compositor & bar
    niri waybar

    # terminal & launchers
    foot fuzzel

    # background & notifications
    swaybg mako

    # audio (pulse/alsa compat needed for apps to see audio)
    pipewire pipewire-pulse pipewire-alsa wireplumber

    # system tools
    fastfetch btop starship

    # wayland utils
    wl-clipboard grim slurp libnotify xdg-utils

    # control
    playerctl brightnessctl

    # theming (GTK/Qt)
    kvantum kvantum-qt5 qt5ct qt6ct nwg-look xsettingsd
)

info "Installing: ${DESKTOP_PKGS[*]}"
if ! sudo pacman -S --needed --noconfirm "${DESKTOP_PKGS[@]}"; then
    warn "Some desktop packages failed — check output above"
    ERRORS+=("Some desktop packages failed to install")
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 4: Fonts
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
step "Step 4/9 — Installing fonts"

FONT_PKGS=(
    ttf-font-awesome
    ttf-nerd-fonts-symbols-common
    ttf-jetbrains-mono-nerd
    noto-fonts-emoji
    noto-fonts-cjk
)

info "Installing: ${FONT_PKGS[*]}"
if ! sudo pacman -S --needed --noconfirm "${FONT_PKGS[@]}"; then
    warn "Some font packages failed — check output above"
    ERRORS+=("Some font packages failed to install")
fi

# Rebuild font cache
info "Rebuilding font cache..."
fc-cache -fv &>/dev/null && ok "Font cache rebuilt" || warn "fc-cache failed"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 5: AUR helper (paru)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
step "Step 5/9 — Installing AUR helper (paru)"

if command -v paru &>/dev/null; then
    ok "paru already installed"
else
    info "Installing rust (required to build paru)..."
    sudo pacman -S --needed --noconfirm rust || { err "Failed to install rust"; ERRORS+=("AUR helper: rust install failed"); }

    PARU_BUILD="$(mktemp -d /tmp/paru_build.XXXXXX)"
    info "Cloning paru from AUR..."
    if git clone --depth=1 https://aur.archlinux.org/paru.git "$PARU_BUILD"; then
        if (cd "$PARU_BUILD" && makepkg -si --noconfirm); then
            ok "paru installed"
        else
            err "paru build failed"
            ERRORS+=("AUR helper: paru build failed")
        fi
    else
        err "Failed to clone paru"
        ERRORS+=("AUR helper: git clone failed")
    fi
    rm -rf "$PARU_BUILD"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 6: Build open-vm-tools for aarch64
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
step "Step 6/9 — Building open-vm-tools for aarch64"
info "This is the most critical step — building from Arch PKGBUILD with ARM patches"

# Build dependencies
info "Installing build dependencies..."
sudo pacman -S --needed --noconfirm base-devel git python3 \
    fuse3 gtkmm3 libcanberra libdnet libmspack libsigc++ \
    libxss open-iscsi procps-ng uriparser xmlsec rpcsvc-proto \
    2>/dev/null || warn "Some build deps may be missing"

BUILD_DIR="$(mktemp -d /tmp/vmtools_build.XXXXXX)"
info "Build directory: $BUILD_DIR"

(
    cd "$BUILD_DIR"

    info "Cloning Arch open-vm-tools PKGBUILD..."
    if ! git clone --depth=1 https://gitlab.archlinux.org/archlinux/packaging/packages/open-vm-tools.git; then
        err "Failed to clone open-vm-tools repo"
        ERRORS+=("open-vm-tools: git clone failed")
        exit 1
    fi

    cd open-vm-tools

    info "Patching PKGBUILD for aarch64 support..."

    # Add aarch64 to supported architectures
    sed -i "s/arch=('x86_64')/arch=('x86_64' 'aarch64')/" PKGBUILD
    ok "Added aarch64 to arch=()"

    # Add -Wno-discarded-qualifiers to CFLAGS inside build()
    # The PKGBUILD has no export CFLAGS line — we insert one right after build() {
    # This suppresses a const-qualifier error that breaks the build on newer GCC
    sed -i '/^build[[:space:]]*()[[:space:]]*{/a\  export CFLAGS="$CFLAGS -Wno-discarded-qualifiers"' PKGBUILD
    ok "Added -Wno-discarded-qualifiers to CFLAGS"

    info "Downloading and extracting sources (makepkg --nobuild -s)..."
    if ! makepkg --nobuild -s --noconfirm 2>&1; then
        err "makepkg --nobuild failed"
        ERRORS+=("open-vm-tools: makepkg --nobuild failed")
        exit 1
    fi
    ok "Sources prepared"

    # Fix glib2 g_free macro collision
    GLIB_STUBS="src/open-vm-tools/open-vm-tools/lib/rpcChannel/glib_stubs.c"
    if [ -f "$GLIB_STUBS" ]; then
        info "Patching glib_stubs.c (g_free macro conflict)..."
        sed -i '/void g_free/i #undef g_free' "$GLIB_STUBS"
        ok "Patched g_free macro"
    else
        warn "glib_stubs.c not found at expected path — build may fail"
    fi

    info "Building and installing open-vm-tools (this takes a while)..."
    if makepkg -es --noconfirm; then
        ok "open-vm-tools built successfully"

        # Install the built package
        info "Installing built package..."
        if sudo pacman -U --noconfirm open-vm-tools-*.pkg.tar.*; then
            ok "open-vm-tools installed"
        else
            err "Failed to install open-vm-tools package"
            ERRORS+=("open-vm-tools: pacman -U failed")
        fi
    else
        err "open-vm-tools build failed"
        ERRORS+=("open-vm-tools: build failed — check output above")
    fi
) || true

# Enable and start vmtoolsd (may already be installed from a prior run)
info "Enabling and starting vmtoolsd service..."
sudo systemctl enable --now vmtoolsd.service 2>/dev/null && ok "vmtoolsd.service enabled & started" || warn "Could not enable vmtoolsd.service"

# Cleanup
rm -rf "$BUILD_DIR"
ok "Cleaned up build directory"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 6: Deploy dotfiles
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
step "Step 7/9 — Deploying dotfiles"

mkdir -p "$HOME/.config"

# Config directories to copy
CONFIG_DIRS=(
    niri waybar foot fuzzel tofi mako
    fastfetch nvim superfile spotify-player trmt
    swaylock kitty
    gtk-3.0 gtk-4.0 qt5ct qt6ct Kvantum xsettingsd nwg-look
)

for dir in "${CONFIG_DIRS[@]}"; do
    if [ -d "$DOTFILES_DIR/.config/$dir" ]; then
        if [ -e "$HOME/.config/$dir" ] && [ ! -L "$HOME/.config/$dir" ]; then
            cp -r "$HOME/.config/$dir" "$HOME/.config/$dir.bak"
            ok "backed up $dir → $dir.bak"
        fi
        rm -rf "$HOME/.config/$dir"
        cp -r "$DOTFILES_DIR/.config/$dir" "$HOME/.config/$dir"
        ok "copied $dir"
    fi
done

# starship.toml
if [ -f "$DOTFILES_DIR/.config/starship.toml" ]; then
    cp "$DOTFILES_DIR/.config/starship.toml" "$HOME/.config/starship.toml"
    ok "copied starship.toml"
fi

# Home dotfiles
for f in .zshrc .gitconfig .gtkrc-2.0; do
    if [ -f "$DOTFILES_DIR/$f" ]; then
        [ -f "$HOME/$f" ] && cp "$HOME/$f" "$HOME/$f.bak"
        cp "$DOTFILES_DIR/$f" "$HOME/$f"
        ok "copied $f"
    fi
done

# Local bin scripts
if [ -d "$DOTFILES_DIR/.local/bin" ]; then
    mkdir -p "$HOME/.local/bin"
    for script in "$DOTFILES_DIR/.local/bin/"*; do
        [ -f "$script" ] || continue
        cp "$script" "$HOME/.local/bin/$(basename "$script")"
        chmod +x "$HOME/.local/bin/$(basename "$script")"
        ok "copied $(basename "$script") to ~/.local/bin/"
    done
fi

# Desktop entries
if [ -d "$DOTFILES_DIR/.local/share/applications" ]; then
    mkdir -p "$HOME/.local/share/applications"
    for desktop in "$DOTFILES_DIR/.local/share/applications/"*.desktop; do
        [ -f "$desktop" ] || continue
        cp "$desktop" "$HOME/.local/share/applications/$(basename "$desktop")"
        ok "copied $(basename "$desktop")"
    done
fi

# Create required directories
mkdir -p "$HOME/Pictures/Wallpaper-Bank/wallpapers"
mkdir -p "$HOME/Pictures/Screenshots"
ok "Created ~/Pictures/Wallpaper-Bank/wallpapers/"
ok "Created ~/Pictures/Screenshots/"

# Copy bundled wallpapers
if [ -d "$DOTFILES_DIR/wallpapers" ]; then
    info "Copying bundled wallpapers..."
    cp -n "$DOTFILES_DIR/wallpapers/"* "$HOME/Pictures/Wallpaper-Bank/wallpapers/" 2>/dev/null || true
    WP_COUNT=$(find "$DOTFILES_DIR/wallpapers" -type f | wc -l)
    ok "Copied $WP_COUNT wallpaper(s) to ~/Pictures/Wallpaper-Bank/wallpapers/"
fi

# ── Patch niri config for VMware dynamic resolution ──
NIRI_CFG="$HOME/.config/niri/config.kdl"
if [ -f "$NIRI_CFG" ]; then
    info "Patching niri config for VMware (commenting out fixed mode)..."
    # Comment out `mode "..."` lines inside output blocks so the hypervisor
    # can dynamically set the resolution via open-vm-tools/vmtoolsd
    sed -i 's/^\([[:space:]]*\)mode "[^"]*"/\1\/\/ mode removed for VMware dynamic resolution/' "$NIRI_CFG"
    ok "Commented out fixed mode in niri config (scale preserved)"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 8: Themes (GTK + Qt + Icons)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
step "Step 8/9 — Installing themes & icons"

THEME_DIR="$HOME/.local/share/themes"
ICON_DIR="$HOME/.local/share/icons"
mkdir -p "$THEME_DIR" "$ICON_DIR"

# GTK theme (download from GitHub releases)
info "Installing Tokyonight GTK theme..."
if [ ! -d "$THEME_DIR/Tokyonight-Dark-B-LB" ]; then
    TMP_THEME="$(mktemp)"
    if curl -fSL "https://github.com/Fausto-Korpsvart/Tokyo-Night-GTK-Theme/releases/latest/download/Tokyonight-Dark-B-LB.tar.xz" -o "$TMP_THEME"; then
        tar -xf "$TMP_THEME" -C "$THEME_DIR" || { err "Failed to extract GTK theme"; ERRORS+=("GTK theme extraction failed"); }
        rm -f "$TMP_THEME"
        # GTK config references "Tokyonight-Dark" — symlink from extracted dir name
        if [ -d "$THEME_DIR/Tokyonight-Dark-B-LB" ] && [ ! -e "$THEME_DIR/Tokyonight-Dark" ]; then
            ln -s "Tokyonight-Dark-B-LB" "$THEME_DIR/Tokyonight-Dark"
        fi
        ok "GTK theme installed"
    else
        err "Failed to download GTK theme"
        ERRORS+=("GTK theme download failed")
    fi
else
    ok "GTK theme already installed"
fi

# Icon theme
info "Installing Tokyonight icon theme..."
if [ ! -d "$ICON_DIR/Tokyonight-Light" ]; then
    TMP_ICONS="$(mktemp)"
    if curl -fSL "https://github.com/Fausto-Korpsvart/Tokyo-Night-GTK-Theme/releases/latest/download/Tokyonight-Light-Icons.tar.xz" -o "$TMP_ICONS"; then
        tar -xf "$TMP_ICONS" -C "$ICON_DIR" && ok "Icon theme installed" || { err "Failed to extract icon theme"; ERRORS+=("Icon theme extraction failed"); }
        rm -f "$TMP_ICONS"
    else
        err "Failed to download icon theme"
        ERRORS+=("Icon theme download failed")
    fi
else
    ok "Icon theme already installed"
fi

# Update icon cache
if command -v gtk-update-icon-cache &>/dev/null && [ -d "$ICON_DIR/Tokyonight-Light" ]; then
    gtk-update-icon-cache -f "$ICON_DIR/Tokyonight-Light" 2>/dev/null && ok "Icon cache updated" || true
fi

# Kvantum Qt theme
info "Setting Kvantum theme..."
if command -v kvantummanager &>/dev/null; then
    kvantummanager --set KvArcDark 2>/dev/null && ok "Kvantum theme set to KvArcDark" || warn "Could not set Kvantum theme"
else
    warn "kvantummanager not found — Kvantum theme not applied"
fi

# Inject environment block into niri config for Qt theming
NIRI_CFG="$HOME/.config/niri/config.kdl"
if [ -f "$NIRI_CFG" ] && ! grep -q 'QT_QPA_PLATFORMTHEME' "$NIRI_CFG"; then
    info "Adding Qt/GTK environment variables to niri config..."
    cat >> "$NIRI_CFG" <<'ENVBLOCK'

environment {
    QT_QPA_PLATFORMTHEME "qt5ct"
    QT_WAYLAND_DISABLE_WINDOWDECORATION "1"
}
ENVBLOCK
    ok "Environment block added to niri config"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 9: Verify installation
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
step "Step 9/9 — Verifying installation"

echo ""
info "Checking binaries..."
BINS=(
    niri waybar foot fuzzel swaybg mako
    playerctl brightnessctl wpctl
    grim slurp wl-copy notify-send
    fastfetch btop nvim python3 paru kvantummanager starship
)
for cmd in "${BINS[@]}"; do
    if command -v "$cmd" &>/dev/null; then
        ok "$cmd"
    else
        err "$cmd not found"
        ERRORS+=("Binary not found: $cmd")
    fi
done

echo ""
info "Checking fonts..."
if command -v fc-list &>/dev/null; then
    FONT_FAMILIES="$(fc-list : family 2>/dev/null)"
    for font in "JetBrainsMono Nerd Font" "Font Awesome" "Noto Color Emoji" "Noto Sans CJK"; do
        if echo "$FONT_FAMILIES" | grep -qi "$font"; then
            ok "$font"
        else
            err "$font not found"
            ERRORS+=("Font not found: $font")
        fi
    done
fi

echo ""
info "Checking themes..."
if [ -d "$HOME/.local/share/themes/Tokyonight-Dark-B-LB" ]; then
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

echo ""
info "Checking graphics..."
if command -v glxinfo &>/dev/null; then
    RENDERER="$(glxinfo 2>/dev/null | grep "OpenGL renderer" | cut -d: -f2 | xargs)"
    [ -n "$RENDERER" ] && ok "OpenGL renderer: $RENDERER" || warn "Could not detect OpenGL renderer"
elif command -v vulkaninfo &>/dev/null; then
    ok "vulkaninfo available"
else
    warn "No GL/Vulkan info tools installed — install mesa-utils to verify"
fi

echo ""
info "Checking VMware tools..."
if command -v vmtoolsd &>/dev/null; then
    ok "vmtoolsd found"
elif pacman -Qi open-vm-tools &>/dev/null; then
    ok "open-vm-tools package installed"
else
    err "open-vm-tools not installed"
    ERRORS+=("open-vm-tools not installed")
fi

if systemctl is-enabled vmtoolsd.service &>/dev/null; then
    ok "vmtoolsd.service enabled"
else
    warn "vmtoolsd.service not enabled"
fi

echo ""
info "Checking services..."
for svc in pipewire.socket wireplumber.service; do
    systemctl --user enable "$svc" 2>/dev/null || true
    if systemctl --user is-active "$svc" &>/dev/null; then
        ok "$svc active"
    else
        warn "$svc not active (will start on next login)"
    fi
done

# ── Summary ──
echo ""
if [ ${#ERRORS[@]} -eq 0 ]; then
    echo -e "${GREEN}┌──────────────────────────────────────────────┐${NC}"
    echo -e "${GREEN}│${NC}   Installation complete! ${GREEN}✓${NC}                     ${GREEN}│${NC}"
    echo -e "${GREEN}│${NC}   Everything installed perfectly.              ${GREEN}│${NC}"
    echo -e "${GREEN}└──────────────────────────────────────────────┘${NC}"
else
    echo -e "${YELLOW}┌──────────────────────────────────────────────┐${NC}"
    echo -e "${YELLOW}│${NC}   Installation complete with warnings          ${YELLOW}│${NC}"
    echo -e "${YELLOW}└──────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "${YELLOW}Issues found (${#ERRORS[@]}):${NC}"
    for e in "${ERRORS[@]}"; do
        err "$e"
    done
fi

echo ""
info "Next steps:"
echo -e "  1. ${BOLD}Reboot${NC} the VM: ${BOLD}sudo reboot${NC}"
echo -e "  2. Log in at TTY1"
echo -e "  3. Start the compositor: ${BOLD}niri-session${NC}"
echo -e "  4. Put wallpapers in ${BOLD}~/Pictures/Wallpaper-Bank/wallpapers/${NC}"
echo -e ""
echo -e "  ${BOLD}Mod+T${NC}  terminal  │  ${BOLD}Mod+D${NC}  launcher  │  ${BOLD}Mod+W${NC}  random wallpaper"
echo ""
