# dotfiles

Terminal rice for Arch Linux ARM + foot + starship + zsh (Tokyo Night theme).

## Quick install

```bash
bash <(curl -sL https://raw.githubusercontent.com/tarzZan52/dotfiles/main/install-remote.sh)
```

## What's included

- **`.zshrc`** — zsh config with plugins, aliases, starship + zoxide init
- **`starship.toml`** — powerline prompt with rounded pills, Tokyo Night colors
- **`foot.ini`** — foot terminal config, Tokyo Night palette, JetBrainsMono Nerd Font

## Manual install

```bash
git clone https://github.com/tarzZan52/dotfiles.git ~/dotfiles
cd ~/dotfiles
bash install.sh
```

## Dependencies

```bash
sudo pacman -S starship zoxide fastfetch zsh foot ttf-jetbrains-mono-nerd zsh-autosuggestions zsh-syntax-highlighting
```
