#!/usr/bin/env python3
"""Notification center panel for mako — Catppuccin Mocha, with slide animation."""

import gi
import subprocess
import os
import signal
import sys
import re

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gtk, Gdk, GLib, GtkLayerShell

LOCK_FILE = "/tmp/notif-center.lock"
W = 420
ANIM_STEPS = 16
ANIM_MS = 12
UPDATE_INTERVAL = 3000

# Catppuccin Mocha
C = {
    "base": "#1e1e2e",
    "mantle": "#181825",
    "crust": "#11111b",
    "surface0": "#313244",
    "surface1": "#45475a",
    "overlay0": "#6c7086",
    "text": "#cdd6f4",
    "subtext0": "#a6adc8",
    "subtext1": "#bac2de",
    "lavender": "#b4befe",
    "mauve": "#cba6f7",
    "red": "#f38ba8",
    "peach": "#fab387",
    "yellow": "#f9e2af",
    "green": "#a6e3a1",
    "blue": "#89b4fa",
    "pink": "#f5c2e7",
    "teal": "#94e2d5",
}

APP_COLORS = {
    "Telegram Desktop": C["blue"],
    "Firefox": C["yellow"],
    "Spotify": C["green"],
    "Screenshot": C["pink"],
    "DnD": C["yellow"],
    "notify-send": C["mauve"],
}


def parse_history():
    """Parse makoctl history plain-text output into list of dicts."""
    try:
        out = subprocess.run(
            ["makoctl", "history"],
            capture_output=True, text=True, timeout=2
        ).stdout.strip()
    except Exception:
        return []

    if not out:
        return []

    notifs = []
    current = None

    for line in out.splitlines():
        m = re.match(r"^Notification\s+(\d+):\s*(.*)", line)
        if m:
            if current:
                notifs.append(current)
            current = {
                "id": m.group(1),
                "summary": m.group(2).strip(),
                "app": "",
                "body": "",
                "urgency": "normal",
                "category": "",
            }
            continue

        if current is None:
            continue

        line_s = line.strip()
        if line_s.startswith("App name:"):
            current["app"] = line_s[len("App name:"):].strip()
        elif line_s.startswith("Body:"):
            current["body"] = line_s[len("Body:"):].strip()
        elif line_s.startswith("Urgency:"):
            current["urgency"] = line_s[len("Urgency:"):].strip()
        elif line_s.startswith("Category:"):
            current["category"] = line_s[len("Category:"):].strip()

    if current:
        notifs.append(current)

    return notifs


def parse_pending():
    """Parse makoctl list (currently visible notifications)."""
    try:
        out = subprocess.run(
            ["makoctl", "list"],
            capture_output=True, text=True, timeout=2
        ).stdout.strip()
    except Exception:
        return []

    if not out:
        return []

    notifs = []
    current = None

    for line in out.splitlines():
        m = re.match(r"^Notification\s+(\d+):\s*(.*)", line)
        if m:
            if current:
                notifs.append(current)
            current = {
                "id": m.group(1),
                "summary": m.group(2).strip(),
                "app": "",
                "body": "",
                "urgency": "normal",
                "category": "",
            }
            continue

        if current is None:
            continue

        line_s = line.strip()
        if line_s.startswith("App name:"):
            current["app"] = line_s[len("App name:"):].strip()
        elif line_s.startswith("Body:"):
            current["body"] = line_s[len("Body:"):].strip()
        elif line_s.startswith("Urgency:"):
            current["urgency"] = line_s[len("Urgency:"):].strip()
        elif line_s.startswith("Category:"):
            current["category"] = line_s[len("Category:"):].strip()

    if current:
        notifs.append(current)

    return notifs


def get_dnd():
    try:
        out = subprocess.run(
            ["makoctl", "mode"],
            capture_output=True, text=True, timeout=2
        ).stdout.strip()
        return "do-not-disturb" in out
    except Exception:
        return False


class NotifCenter(Gtk.Window):
    def __init__(self):
        super().__init__()

        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.TOP)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.RIGHT, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.BOTTOM, True)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.TOP, 6)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.RIGHT, -(W + 20))
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.BOTTOM, 6)
        GtkLayerShell.set_exclusive_zone(self, 0)
        GtkLayerShell.set_keyboard_mode(
            self, GtkLayerShell.KeyboardMode.ON_DEMAND
        )

        self.set_decorated(False)
        self.set_resizable(False)
        self.set_name("notif-center")
        self.set_default_size(W, -1)

        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual:
            self.set_visual(visual)
        self.set_app_paintable(True)

        self._anim_step = 0
        self._closing = False

        self._apply_css()
        self._build_ui()

        self.connect("key-press-event", self._on_key)

    def start_open(self):
        self.show_all()
        self._refresh()
        self._anim_step = 0
        self._closing = False
        GLib.timeout_add(ANIM_MS, self._animate_open)
        self._update_id = GLib.timeout_add(UPDATE_INTERVAL, self._refresh)

    def _animate_open(self):
        self._anim_step += 1
        t = min(self._anim_step / ANIM_STEPS, 1.0)
        # ease-out cubic
        t2 = 1.0 - (1.0 - t) ** 3
        margin = int(-(W + 20) * (1.0 - t2) + 6 * t2)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.RIGHT, margin)
        return self._anim_step < ANIM_STEPS

    def _animate_close(self):
        self._anim_step += 1
        t = min(self._anim_step / ANIM_STEPS, 1.0)
        # ease-in cubic
        t2 = t ** 3
        margin = int(6 * (1.0 - t2) + -(W + 20) * t2)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.RIGHT, margin)
        if self._anim_step >= ANIM_STEPS:
            _cleanup()
            return False
        return True

    def close_animated(self):
        if self._closing:
            return
        self._closing = True
        self._anim_step = 0
        if hasattr(self, "_update_id"):
            GLib.source_remove(self._update_id)
        GLib.timeout_add(ANIM_MS, self._animate_close)

    def _on_key(self, widget, event):
        if event.keyval == Gdk.KEY_Escape:
            self.close_animated()
            return True
        return False

    def _build_ui(self):
        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        root.set_name("panel")

        # ── Header ──
        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        header.set_name("header")

        title = Gtk.Label(label="  Notifications")
        title.set_name("header-title")
        title.set_halign(Gtk.Align.START)
        header.pack_start(title, True, True, 0)

        # DnD toggle
        self.dnd_btn = Gtk.Label()
        self.dnd_btn.set_name("header-btn")
        dnd_box = Gtk.EventBox()
        dnd_box.add(self.dnd_btn)
        dnd_box.connect("button-press-event", self._toggle_dnd)
        header.pack_end(dnd_box, False, False, 0)

        # Clear all
        clear_label = Gtk.Label(label="  Clear")
        clear_label.set_name("header-btn-clear")
        clear_box = Gtk.EventBox()
        clear_box.add(clear_label)
        clear_box.connect("button-press-event", self._clear_all)
        header.pack_end(clear_box, False, False, 0)

        root.pack_start(header, False, False, 0)

        # ── Scrollable list ──
        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_name("scroll")
        scroll.set_min_content_height(200)

        self.list_box = Gtk.Box(
            orientation=Gtk.Orientation.VERTICAL, spacing=6
        )
        self.list_box.set_name("notif-list")
        scroll.add(self.list_box)

        # Empty state
        self.empty_box = Gtk.Box(
            orientation=Gtk.Orientation.VERTICAL, spacing=8
        )
        self.empty_box.set_valign(Gtk.Align.CENTER)
        self.empty_box.set_vexpand(True)
        empty_icon = Gtk.Label(label="󰂜")
        empty_icon.set_name("empty-icon")
        self.empty_box.pack_start(empty_icon, False, False, 0)
        empty_text = Gtk.Label(label="All clear")
        empty_text.set_name("empty-text")
        self.empty_box.pack_start(empty_text, False, False, 0)

        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
        self.stack.set_transition_duration(200)
        self.stack.add_named(scroll, "list")
        self.stack.add_named(self.empty_box, "empty")

        root.pack_start(self.stack, True, True, 0)

        # ── Pending count ──
        self.footer = Gtk.Label()
        self.footer.set_name("footer")
        self.footer.set_halign(Gtk.Align.START)
        root.pack_start(self.footer, False, False, 0)

        self.add(root)

    def _refresh(self):
        if self._closing:
            return False

        history = parse_history()
        pending = parse_pending()
        dnd = get_dnd()

        # DnD button
        self.dnd_btn.set_text("󰂛  DnD ON" if dnd else "󰂚  DnD")
        ctx = self.dnd_btn.get_style_context()
        if dnd:
            ctx.add_class("dnd-active")
        else:
            ctx.remove_class("dnd-active")

        # Footer
        pcount = len(pending)
        if pcount > 0:
            self.footer.set_text(f"  {pcount} pending")
            self.footer.show()
        else:
            self.footer.hide()

        # Combine pending + history
        all_notifs = pending + history

        # Clear list
        for child in self.list_box.get_children():
            self.list_box.remove(child)

        if not all_notifs:
            self.stack.set_visible_child_name("empty")
        else:
            self.stack.set_visible_child_name("list")

            # Deduplicate by id
            seen = set()
            for n in all_notifs:
                nid = n["id"]
                if nid in seen:
                    continue
                seen.add(nid)
                card = self._make_card(n)
                self.list_box.pack_start(card, False, False, 0)

        self.list_box.show_all()
        return True

    def _make_card(self, n):
        card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=3)
        card.set_name("card")

        urgency = n.get("urgency", "normal")
        if urgency == "critical":
            card.get_style_context().add_class("critical")
        elif urgency == "low":
            card.get_style_context().add_class("low")

        # Top row: app + category
        top = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        app = n.get("app", "") or "System"
        color = APP_COLORS.get(app, C["mauve"])

        app_icon = self._app_icon(app)
        app_label = Gtk.Label()
        app_label.set_markup(
            f"<span color='{color}' size='small'>"
            f"{app_icon} {GLib.markup_escape_text(app)}</span>"
        )
        app_label.set_halign(Gtk.Align.START)
        top.pack_start(app_label, True, True, 0)

        cat = n.get("category", "")
        if cat:
            cat_label = Gtk.Label()
            cat_label.set_markup(
                f"<span color='{C['overlay0']}' size='x-small'>{cat}</span>"
            )
            top.pack_end(cat_label, False, False, 0)

        card.pack_start(top, False, False, 0)

        # Summary
        summary = n.get("summary", "")
        if summary:
            s_label = Gtk.Label()
            s_label.set_markup(
                f"<b>{GLib.markup_escape_text(summary)}</b>"
            )
            s_label.set_name("card-title")
            s_label.set_halign(Gtk.Align.START)
            s_label.set_xalign(0)
            s_label.set_ellipsize(3)
            s_label.set_max_width_chars(44)
            card.pack_start(s_label, False, False, 0)

        # Body
        body = n.get("body", "")
        if body:
            b_label = Gtk.Label(label=body)
            b_label.set_name("card-body")
            b_label.set_halign(Gtk.Align.START)
            b_label.set_xalign(0)
            b_label.set_line_wrap(True)
            b_label.set_max_width_chars(48)
            b_label.set_lines(3)
            b_label.set_ellipsize(3)
            card.pack_start(b_label, False, False, 0)

        return card

    def _app_icon(self, app):
        icons = {
            "Telegram Desktop": "",
            "Firefox": "󰈹",
            "Spotify": "",
            "Screenshot": "",
            "DnD": "󰂛",
            "notify-send": "󰍡",
        }
        return icons.get(app, "󰂚")

    def _toggle_dnd(self, w, ev):
        subprocess.Popen(
            ["bash", "/home/user/.config/mako/dnd-toggle.sh"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        GLib.timeout_add(400, self._refresh)
        return True

    def _clear_all(self, w, ev):
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
            padding: 12px 14px;
        }}
        #header-title {{
            color: {C["text"]};
            font-size: 14px;
            font-weight: bold;
            font-family: "JetBrainsMono Nerd Font";
        }}
        #header-btn, #header-btn-clear {{
            color: {C["subtext0"]};
            font-size: 12px;
            font-family: "JetBrainsMono Nerd Font";
            padding: 4px 10px;
            border-radius: 8px;
            background-color: {C["surface0"]};
            margin-left: 4px;
        }}
        #header-btn:hover, #header-btn-clear:hover {{
            background-color: {C["surface1"]};
        }}
        #header-btn-clear:hover {{
            color: {C["red"]};
        }}
        #header-btn.dnd-active {{
            background-color: {C["yellow"]};
            color: {C["crust"]};
        }}
        #scroll {{
            background-color: transparent;
        }}
        #notif-list {{
            padding: 4px 10px 10px 10px;
            background-color: transparent;
        }}
        #card {{
            background-color: {C["mantle"]};
            border-radius: 10px;
            padding: 10px 14px;
            border-left: 3px solid {C["mauve"]};
        }}
        #card.critical {{
            border-left-color: {C["red"]};
        }}
        #card.low {{
            border-left-color: {C["surface1"]};
        }}
        #card-title {{
            color: {C["text"]};
            font-size: 13px;
            font-family: "JetBrainsMono Nerd Font";
        }}
        #card-body {{
            color: {C["subtext0"]};
            font-size: 11px;
            font-family: "JetBrainsMono Nerd Font";
        }}
        #empty-icon {{
            color: {C["surface1"]};
            font-size: 40px;
            font-family: "JetBrainsMono Nerd Font";
        }}
        #empty-text {{
            color: {C["overlay0"]};
            font-size: 13px;
            font-family: "JetBrainsMono Nerd Font";
        }}
        #footer {{
            color: {C["overlay0"]};
            font-size: 11px;
            font-family: "JetBrainsMono Nerd Font";
            padding: 6px 14px 10px 14px;
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
    win.start_open()
    win.connect("destroy", lambda _: _cleanup())
    Gtk.main()


if __name__ == "__main__":
    main()
