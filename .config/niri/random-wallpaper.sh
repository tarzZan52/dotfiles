#!/bin/bash
# ╔══════════════════════════════════════════╗
# ║  RANDOM WALLPAPER // NIRI + SWAYBG      ║
# ╚══════════════════════════════════════════╝

WALLPAPER_DIR="$HOME/Pictures/Wallpaper-Bank/wallpapers"

WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.webp" -o -name "*.bmp" \) | shuf -n 1)

if [ -z "$WALLPAPER" ]; then
    notify-send "Wallpaper" "No images found in $WALLPAPER_DIR" -u critical
    exit 1
fi

pkill swaybg
sleep 0.1
swaybg -m fill -i "$WALLPAPER" &
disown

notify-send "Wallpaper" "$(basename "$WALLPAPER")" -i "$WALLPAPER" -t 2000
