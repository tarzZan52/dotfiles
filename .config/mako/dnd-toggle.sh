#!/usr/bin/env bash
# Toggle Do Not Disturb mode in mako

makoctl mode -t do-not-disturb

modes="$(makoctl mode)"

if echo "$modes" | grep -q "do-not-disturb"; then
    notify-send -a "DnD" "Do Not Disturb" "Notifications muted" -i notifications-disabled -u low
else
    notify-send -a "DnD" "Do Not Disturb" "Notifications enabled" -i notifications -u low
fi

# Signal waybar to update DnD widget
pkill -RTMIN+9 waybar
