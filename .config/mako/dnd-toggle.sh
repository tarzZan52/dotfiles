#!/usr/bin/env bash
# Переключает режим "Не беспокоить" в mako
# и шлёт уведомление о статусе

makoctl mode -t do-not-disturb

modes="$(makoctl mode)"

if echo "$modes" | grep -q "do-not-disturb"; then
    notify-send -a "DnD" "Не беспокоить" "Уведомления отключены" -i notifications-disabled -u low
else
    notify-send -a "DnD" "Не беспокоить" "Уведомления включены" -i notifications -u low
fi

# Сигнал для waybar (обновить виджет)
pkill -RTMIN+9 waybar
