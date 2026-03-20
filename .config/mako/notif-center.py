#!/usr/bin/env python3
"""Notification center panel for mako — Catppuccin Mocha theme."""

import gi
import subprocess
import json
import os
import signal
import sys
import html
from datetime import datetime

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gtk, Gdk, GLib, GtkLayerShell

LOCK_FILE = "/tmp/notif-center.lock"
W = 420
H = 600
UPDATE_INTERVAL = 3000

# Catppuccin Mocha palette
C = {
    "base": "#1e1e2e",
    "mantle": "#181825",
    "surface0": "#313244",
    "surface1": "#45475a",
    "overlay0": "#6c7086",
    "text": "#cdd6f4",
    "subtext": "#a6adc8",
    "lavender": "#b4befe",
    "mauve": "#cba6f7",
    "red": "#f38ba8",
    "peach": "#fab387",
    "yellow": "#f9e2af",
    "green": "#a6e3a1",
    "blue": "#89b4fa",
    "pink": "#f5c2e7",
}

APP_COLORS = {
    "Telegram Desktop": C["blue"],
    "Firefox": C["yellow"],
    "Spotify": C["green"],
    "Screenshot": C["pink"],
}


def get_history():
    try:
        out = subprocess.run(
            ["makoctl", "history"],
            capture_output=True, text=True, timeout=2
        ).stdout.strip()
        if not out:
            return []
        data = json.loads(out)
        return data.get("data", [[]])[0] if "data" in data else []
    except Exception:
        return []


def get_dnd_active():
    try:
        out = subprocess.run(
            ["makoctl", "mode"],
            capture_output=True, text=True, timeout=2
        ).stdout.strip()
        return "do-not-disturb" in out
    except Exception:
        return False


def format_time(unix_ms):
    try:
        ts = int(unix_ms) / 1000000
        dt = datetime.fromtimestamp(ts)
        now = datetime.now()
        diff = now - dt
        if diff.total_seconds() < 60:
            return "just now"
        elif diff.total_seconds() < 3600:
            m = int(diff.total_seconds() // 60)
            return f"{m}m ago"
        elif diff.total_seconds() < 86400:
            h = int(diff.total_seconds() // 3600)
            return f"{h}h ago"
        else:
            return dt.strftime("%d %b %H:%M")
    except Exception:
        return ""


def sanitize(text):
    if not text or not isinstance(text, dict):
        return ""
    val = text.get("data", "")
    clean = html.escape(str(val))
    return clean[:200]


class NotifCenter(Gtk.Window):
    def __init__(self):
        super().__init__()

        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.TOP)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.RIGHT, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.BOTTOM, True)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.TOP, 6)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.RIGHT, 6)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.BOTTOM, 6)
        GtkLayerShell.set_exclusive_zone(self, 0)
        GtkLayerShell.set_keyboard_mode(
            self, GtkLayerShell.KeyboardMode.ON_DEMAND
        )

        self.set_decorated(False)
        self.set_resizable(False)
        self.set_name("notif-center")
        self.set_default_size(W, H)

        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual:
            self.set_visual(visual)
        self.set_app_paintable(True)

        self._apply_css()
        self._build_ui()
        self._refresh()
        GLib.timeout_add(UPDATE_INTERVAL, self._refresh)

        self.connect("key-press-event", self._on_key)

    def _on_key(self, widget, event):
        if event.keyval == Gdk.KEY_Escape:
            _cleanup()
            return True
        return False

    def _build_ui(self):
        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        root.set_name("panel")

        # ── Header ──
        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        header.set_name("header")

        icon = Gtk.Label(label="󰂚")
        icon.set_name("header-icon")
        header.pack_start(icon, False, False, 0)

        title = Gtk.Label(label="Notifications")
        title.set_name("header-title")
        title.set_halign(Gtk.Align.START)
        header.pack_start(title, True, True, 0)

        # DnD toggle button
        self.dnd_btn = Gtk.Label()
        self.dnd_btn.set_name("dnd-btn")
        dnd_ebox = Gtk.EventBox()
        dnd_ebox.add(self.dnd_btn)
        dnd_ebox.connect("button-press-event", self._toggle_dnd)
        dnd_ebox.set_tooltip_text("Toggle Do Not Disturb")
        header.pack_end(dnd_ebox, False, False, 0)

        # Clear all button
        clear_label = Gtk.Label(label="󰎟")
        clear_label.set_name("clear-btn")
        clear_ebox = Gtk.EventBox()
        clear_ebox.add(clear_label)
        clear_ebox.connect("button-press-event", self._clear_all)
        header.pack_end(clear_ebox, False, False, 0)

        root.pack_start(header, False, False, 0)

        # ── Separator ──
        sep = Gtk.Separator()
        sep.set_name("sep")
        root.pack_start(sep, False, False, 0)

        # ── Notification list (scrollable) ──
        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_name("scroll")

        self.list_box = Gtk.Box(
            orientation=Gtk.Orientation.VERTICAL, spacing=6
        )
        self.list_box.set_name("notif-list")
        scroll.add(self.list_box)

        # Empty state
        self.empty_label = Gtk.Label(label="No notifications")
        self.empty_label.set_name("empty")

        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
        self.stack.set_transition_duration(200)
        self.stack.add_named(scroll, "list")
        self.stack.add_named(self.empty_label, "empty")

        root.pack_start(self.stack, True, True, 0)
        self.add(root)

    def _refresh(self):
        history = get_history()
        dnd = get_dnd_active()

        # Update DnD button
        self.dnd_btn.set_text("󰂛" if dnd else "󰂚")
        ctx = self.dnd_btn.get_style_context()
        if dnd:
            ctx.add_class("active")
        else:
            ctx.remove_class("active")

        # Clear old items
        for child in self.list_box.get_children():
            self.list_box.remove(child)

        if not history:
            self.stack.set_visible_child_name("empty")
        else:
            self.stack.set_visible_child_name("list")
            for notif in history:
                card = self._make_card(notif)
                self.list_box.pack_start(card, False, False, 0)

        self.list_box.show_all()
        return True

    def _make_card(self, notif):
        card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        card.set_name("card")

        # Top row: app name + time
        top = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)

        app_name = sanitize(notif.get("app-name", {})) or "Unknown"
        app_label = Gtk.Label()
        color = APP_COLORS.get(app_name, C["mauve"])
        app_label.set_markup(
            f"<span color='{color}' size='small'>{app_name}</span>"
        )
        app_label.set_halign(Gtk.Align.START)
        top.pack_start(app_label, True, True, 0)

        time_str = format_time(
            notif.get("time", {}).get("data", "0")
            if isinstance(notif.get("time"), dict)
            else notif.get("time", "0")
        )
        time_label = Gtk.Label()
        time_label.set_markup(
            f"<span color='{C['overlay0']}' size='small'>{time_str}</span>"
        )
        time_label.set_halign(Gtk.Align.END)
        top.pack_end(time_label, False, False, 0)

        card.pack_start(top, False, False, 0)

        # Title
        summary = sanitize(notif.get("summary", {}))
        if summary:
            title_l = Gtk.Label()
            title_l.set_markup(f"<b>{summary}</b>")
            title_l.set_name("card-title")
            title_l.set_halign(Gtk.Align.START)
            title_l.set_xalign(0)
            title_l.set_ellipsize(3)
            title_l.set_max_width_chars(42)
            card.pack_start(title_l, False, False, 0)

        # Body
        body = sanitize(notif.get("body", {}))
        if body:
            body_l = Gtk.Label(label=body)
            body_l.set_name("card-body")
            body_l.set_halign(Gtk.Align.START)
            body_l.set_xalign(0)
            body_l.set_line_wrap(True)
            body_l.set_max_width_chars(46)
            body_l.set_lines(3)
            body_l.set_ellipsize(3)
            card.pack_start(body_l, False, False, 0)

        return card

    def _toggle_dnd(self, widget, event):
        subprocess.Popen(
            ["bash", "/home/user/.config/mako/dnd-toggle.sh"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        GLib.timeout_add(300, self._refresh)
        return True

    def _clear_all(self, widget, event):
        subprocess.run(
            ["makoctl", "dismiss", "--all"],
            capture_output=True, timeout=2,
        )
        GLib.timeout_add(300, self._refresh)
        return True

    def _apply_css(self):
        css = f"""
        #notif-center {{
            background-color: transparent;
        }}
        #panel {{
            background-color: {C["base"]};
            border-radius: 14px;
            border: 2px solid {C["surface0"]};
        }}
        #header {{
            padding: 14px 16px;
        }}
        #header-icon {{
            color: {C["mauve"]};
            font-size: 20px;
            font-family: "JetBrainsMono Nerd Font";
        }}
        #header-title {{
            color: {C["text"]};
            font-size: 15px;
            font-weight: bold;
            font-family: "JetBrainsMono Nerd Font";
        }}
        #dnd-btn {{
            color: {C["overlay0"]};
            font-size: 18px;
            font-family: "JetBrainsMono Nerd Font";
            padding: 2px 8px;
            border-radius: 8px;
        }}
        #dnd-btn:hover {{
            background-color: {C["surface0"]};
        }}
        #dnd-btn.active {{
            color: {C["yellow"]};
        }}
        #clear-btn {{
            color: {C["overlay0"]};
            font-size: 18px;
            font-family: "JetBrainsMono Nerd Font";
            padding: 2px 8px;
            border-radius: 8px;
        }}
        #clear-btn:hover {{
            background-color: {C["surface0"]};
            color: {C["red"]};
        }}
        #sep {{
            background-color: {C["surface0"]};
            min-height: 1px;
        }}
        #scroll {{
            background-color: transparent;
        }}
        #notif-list {{
            padding: 8px 10px;
            background-color: transparent;
        }}
        #card {{
            background-color: {C["mantle"]};
            border-radius: 10px;
            padding: 10px 14px;
            border: 1px solid {C["surface0"]};
        }}
        #card-title {{
            color: {C["text"]};
            font-size: 13px;
            font-family: "JetBrainsMono Nerd Font";
        }}
        #card-body {{
            color: {C["subtext"]};
            font-size: 11px;
            font-family: "JetBrainsMono Nerd Font";
        }}
        #empty {{
            color: {C["overlay0"]};
            font-size: 14px;
            font-family: "JetBrainsMono Nerd Font";
        }}
        """.encode()
        prov = Gtk.CssProvider()
        prov.load_from_data(css)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), prov,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )


def _cleanup(*_):
    try:
        os.remove(LOCK_FILE)
    except OSError:
        pass
    Gtk.main_quit()


def main():
    # Toggle: if already running, kill it
    if os.path.exists(LOCK_FILE):
        try:
            with open(LOCK_FILE) as f:
                pid = int(f.read().strip())
            os.kill(pid, signal.SIGTERM)
        except (ValueError, ProcessLookupError, OSError):
            pass
        try:
            os.remove(LOCK_FILE)
        except OSError:
            pass
        sys.exit(0)

    with open(LOCK_FILE, "w") as f:
        f.write(str(os.getpid()))

    signal.signal(signal.SIGTERM, _cleanup)
    signal.signal(signal.SIGINT, _cleanup)

    win = NotifCenter()
    win.show_all()
    win.connect("destroy", lambda _: _cleanup())
    Gtk.main()


if __name__ == "__main__":
    main()
