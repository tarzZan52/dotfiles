#!/usr/bin/env python3

import gi
import subprocess
import os
import hashlib
import re
import signal
import sys
import random

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GdkPixbuf", "2.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gtk, Gdk, GdkPixbuf, GLib, GtkLayerShell

CACHE_DIR = "/tmp/yandex_covers"
CURRENT_LINK = "/tmp/yandex_cover_current.jpg"
OLD_CACHE_DIR = os.path.expanduser("~/.cache/player-popup")
LOCK_FILE = os.path.join(CACHE_DIR, "player-popup.lock")
W = 400
H = 64
ART_THUMB = 44
TOP_MARGIN = 0
WAVE_CHARS = "▁▂▃▄▅▆▇"
WAVE_N = 3


def pctl(*args):
    try:
        return subprocess.run(
            ["playerctl", *args],
            capture_output=True, text=True, timeout=2
        ).stdout.strip()
    except Exception:
        return ""


def track_key(title, artist):
    return hashlib.md5(f"{title}|{artist}".encode(), usedforsecurity=False).hexdigest()


def get_art(title, artist, track_id=None):
    """Get cached art. Priority: symlink → track_id cache → hash cache → old cache."""
    # 1. Current symlink (always points to latest)
    if os.path.exists(CURRENT_LINK):
        real = os.path.realpath(CURRENT_LINK)
        if os.path.exists(real) and os.path.getsize(real) > 100:
            return real
    # 2. By track ID in new cache
    if track_id:
        p = os.path.join(CACHE_DIR, f"{track_id}.jpg")
        if os.path.exists(p) and os.path.getsize(p) > 100:
            return p
    # 3. By title|artist hash in new cache
    tkey = track_key(title, artist)
    p = os.path.join(CACHE_DIR, f"{tkey}.jpg")
    if os.path.exists(p) and os.path.getsize(p) > 100:
        return p
    # 4. Old cache fallback
    old = os.path.join(OLD_CACHE_DIR, f"track_{tkey}.jpg")
    if os.path.exists(old) and os.path.getsize(old) > 100:
        return old
    return None



def get_popup_x():
    display = Gdk.Display.get_default()
    monitor = display.get_primary_monitor() or display.get_monitor(0)
    geo = monitor.get_geometry()
    screen_w = geo.width
    center = screen_w // 2
    mpris_center = center + 110
    popup_x = mpris_center - W // 2
    return max(10, min(screen_w - W - 10, popup_x))


class PlayerPopup(Gtk.Window):
    def __init__(self):
        super().__init__()
        self._wave_h = [random.uniform(0.3, 0.6) for _ in range(WAVE_N)]
        self._wave_t = [random.uniform(0.3, 1.0) for _ in range(WAVE_N)]
        self._playing = False

        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.TOP)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.LEFT, True)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.TOP, TOP_MARGIN)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.LEFT, get_popup_x())
        GtkLayerShell.set_exclusive_zone(self, 0)
        GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.NONE)

        self.set_decorated(False)
        self.set_resizable(False)
        self.set_name("player-popup")

        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual:
            self.set_visual(visual)
        self.set_app_paintable(True)

        self._build_ui()
        self._apply_css()
        self._update()
        # Retry art fetch shortly after open (artUrl may appear briefly)
        GLib.timeout_add(500, self._update)
        GLib.timeout_add(1500, self._update)
        GLib.timeout_add(3000, self._update)
        GLib.timeout_add(5000, self._update_loop)
        GLib.timeout_add(120, self._wave_tick)

    def _update_loop(self):
        self._update()
        return True

    def _build_ui(self):
        main = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        main.set_name("popup-box")
        main.set_size_request(W, H)
        self.add(main)

        # Left: art thumbnail or placeholder icon
        self.art_image = Gtk.Image()
        self.art_image.set_name("art-thumb")
        self.art_image.set_size_request(ART_THUMB, ART_THUMB)

        self.art_placeholder = Gtk.Label(label="󰎆")
        self.art_placeholder.set_name("art-placeholder")

        self.art_stack = Gtk.Stack()
        self.art_stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
        self.art_stack.set_transition_duration(300)
        self.art_stack.add_named(self.art_placeholder, "placeholder")
        self.art_stack.add_named(self.art_image, "art")
        self.art_stack.set_visible_child_name("placeholder")
        self.art_stack.set_valign(Gtk.Align.CENTER)
        self.art_stack.set_margin_start(12)
        main.pack_start(self.art_stack, False, False, 0)

        # Center: title row (with mini waves) + artist
        center = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
        center.set_valign(Gtk.Align.CENTER)
        center.set_margin_start(10)
        center.set_margin_end(6)

        # Title row: title + wave indicator
        title_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)

        self.title_l = Gtk.Label()
        self.title_l.set_name("title")
        self.title_l.set_ellipsize(3)
        self.title_l.set_max_width_chars(22)
        self.title_l.set_halign(Gtk.Align.START)
        self.title_l.set_xalign(0)
        title_row.pack_start(self.title_l, False, True, 0)

        self.wave_l = Gtk.Label()
        self.wave_l.set_name("wave")
        self.wave_l.set_halign(Gtk.Align.START)
        self.wave_l.set_valign(Gtk.Align.END)
        title_row.pack_start(self.wave_l, False, False, 0)

        center.pack_start(title_row, False, False, 0)

        self.artist_l = Gtk.Label()
        self.artist_l.set_name("artist")
        self.artist_l.set_ellipsize(3)
        self.artist_l.set_max_width_chars(24)
        self.artist_l.set_halign(Gtk.Align.START)
        self.artist_l.set_xalign(0)
        center.pack_start(self.artist_l, False, False, 0)

        main.pack_start(center, True, True, 0)

        # Right: controls
        ctrls = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        ctrls.set_valign(Gtk.Align.CENTER)
        ctrls.set_margin_end(10)

        ctrls.pack_start(self._btn("󰒮", "prev"), False, False, 0)
        self.play_btn = self._btn("󰐊", "play")
        ctrls.pack_start(self.play_btn, False, False, 0)
        ctrls.pack_start(self._btn("󰒭", "next"), False, False, 0)

        main.pack_end(ctrls, False, False, 0)

    def _wave_tick(self):
        if self._playing:
            for i in range(WAVE_N):
                self._wave_h[i] += (self._wave_t[i] - self._wave_h[i]) * 0.3
                if abs(self._wave_h[i] - self._wave_t[i]) < 0.08:
                    self._wave_t[i] = random.uniform(0.1, 1.0)
            chars = []
            for i in range(WAVE_N):
                idx = int(self._wave_h[i] * (len(WAVE_CHARS) - 1))
                idx = max(0, min(len(WAVE_CHARS) - 1, idx))
                chars.append(WAVE_CHARS[idx])
            self.wave_l.set_text("".join(chars))
        else:
            self.wave_l.set_text("")
        return True

    def _btn(self, icon, action):
        label = Gtk.Label(label=icon)
        label.set_name("btn-play" if action == "play" else "btn")
        ebox = Gtk.EventBox()
        ebox.add(label)
        ebox.set_above_child(True)

        def on_press(w, ev, a=action):
            label.set_opacity(0.4)
            if a == "play":
                pctl("play-pause")
            elif a == "prev":
                pctl("previous")
            elif a == "next":
                pctl("next")
            GLib.timeout_add(150, lambda: label.set_opacity(1.0) or False)
            GLib.timeout_add(300, self._update)
            return True

        ebox.connect("button-press-event", on_press)
        return ebox

    def _apply_css(self):
        css = """
        #player-popup {
            background-color: transparent;
        }
        #popup-box {
            background-color: #1e1e2e;
            border-radius: 12px;
            border: 1px solid #313244;
        }
        #art-thumb {
            border-radius: 8px;
        }
        #art-placeholder {
            color: #45475a;
            font-size: 24px;
            font-family: "JetBrainsMono Nerd Font";
        }
        #wave {
            color: #cba6f7;
            font-size: 10px;
            font-family: monospace;
        }
        #title {
            color: #cdd6f4;
            font-size: 13px;
            font-weight: bold;
            font-family: "JetBrainsMono Nerd Font";
        }
        #artist {
            color: #a6adc8;
            font-size: 11px;
            font-family: "JetBrainsMono Nerd Font";
        }
        #btn, #btn-play {
            color: #bac2de;
            font-size: 17px;
            font-family: "JetBrainsMono Nerd Font";
            padding: 5px 8px;
            border-radius: 8px;
            background-color: transparent;
        }
        #btn-play {
            font-size: 22px;
            background-color: #cba6f7;
            color: #1e1e2e;
            padding: 5px 12px;
            border-radius: 10px;
        }
        #btn:hover {
            background-color: #313244;
        }
        #btn-play:hover {
            background-color: #b4befe;
        }
        """.encode()
        prov = Gtk.CssProvider()
        prov.load_from_data(css)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), prov,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

    def _update(self):
        title = pctl("metadata", "xesam:title")
        artist = pctl("metadata", "xesam:artist")
        album = pctl("metadata", "xesam:album")
        status = pctl("status")

        self.title_l.set_text(title or "Nothing playing")
        self.artist_l.set_text(artist or album or "")

        play_label = self.play_btn.get_child()
        play_label.set_text("󰏤" if status == "Playing" else "󰐊")
        self._playing = (status == "Playing")

        t, a = title or "", artist or ""
        # Extract track ID from xesam:url
        tid = None
        xurl = pctl("metadata", "xesam:url")
        if xurl:
            m = re.search(r'/track/(\d+)', xurl)
            if m:
                tid = m.group(1)
        art_path = get_art(t, a, tid)

        if art_path:
            try:
                pb = GdkPixbuf.Pixbuf.new_from_file_at_scale(
                    art_path, ART_THUMB, ART_THUMB, True
                )
                self.art_image.set_from_pixbuf(pb)
                self.art_stack.set_visible_child_name("art")
            except Exception:
                self.art_stack.set_visible_child_name("placeholder")
        else:
            self.art_stack.set_visible_child_name("placeholder")

        return True


def main():
    os.makedirs(CACHE_DIR, exist_ok=True)

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

    def cleanup(*_):
        try:
            os.remove(LOCK_FILE)
        except OSError:
            pass
        Gtk.main_quit()

    signal.signal(signal.SIGTERM, cleanup)
    signal.signal(signal.SIGINT, cleanup)

    win = PlayerPopup()
    win.show_all()
    win.connect("destroy", lambda _: cleanup())
    Gtk.main()


if __name__ == "__main__":
    main()
