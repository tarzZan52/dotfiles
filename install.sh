#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> Installing dotfiles from $DOTFILES_DIR"

# zshrc
if [ -f "$HOME/.zshrc" ]; then
    cp "$HOME/.zshrc" "$HOME/.zshrc.bak"
    echo "    Backed up existing .zshrc -> .zshrc.bak"
fi
cp "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
echo "    .zshrc installed"

# starship
mkdir -p "$HOME/.config"
if [ -f "$HOME/.config/starship.toml" ]; then
    cp "$HOME/.config/starship.toml" "$HOME/.config/starship.toml.bak"
    echo "    Backed up existing starship.toml -> starship.toml.bak"
fi
cp "$DOTFILES_DIR/.config/starship.toml" "$HOME/.config/starship.toml"
echo "    starship.toml installed"

# foot
mkdir -p "$HOME/.config/foot"
if [ -f "$HOME/.config/foot/foot.ini" ]; then
    cp "$HOME/.config/foot/foot.ini" "$HOME/.config/foot/foot.ini.bak"
    echo "    Backed up existing foot.ini -> foot.ini.bak"
fi
cp "$DOTFILES_DIR/.config/foot/foot.ini" "$HOME/.config/foot/foot.ini"
echo "    foot.ini installed"

# Check dependencies
echo ""
echo "==> Checking dependencies..."
for cmd in starship zoxide fastfetch zsh; do
    if command -v "$cmd" &>/dev/null; then
        echo "    $cmd: OK"
    else
        echo "    $cmd: NOT FOUND - install with: sudo pacman -S $cmd"
    fi
done

# Check font
if fc-list | grep -qi "JetBrainsMono Nerd Font Mono"; then
    echo "    JetBrainsMono Nerd Font Mono: OK"
else
    echo "    JetBrainsMono Nerd Font Mono: NOT FOUND - install with: sudo pacman -S ttf-jetbrains-mono-nerd"
fi

# Check zsh plugins
for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
    if [ -d "/usr/share/zsh/plugins/$plugin" ]; then
        echo "    $plugin: OK"
    else
        echo "    $plugin: NOT FOUND - install with: sudo pacman -S $plugin"
    fi
done

echo ""
echo "==> Done! Open a new terminal to see the changes."
