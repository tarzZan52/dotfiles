#!/usr/bin/env bash
set -euo pipefail

REPO="https://github.com/tarzZan52/dotfiles.git"
DEST="$HOME/dotfiles"

echo "==> Cloning dotfiles..."
if [ -d "$DEST" ]; then
    echo "    $DEST already exists, pulling latest..."
    git -C "$DEST" pull
else
    git clone "$REPO" "$DEST"
fi

echo ""
bash "$DEST/install.sh"
