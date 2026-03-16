#!/usr/bin/env python3
"""Background daemon that caches album art from Yandex Music.
Priority: mpris:artUrl → Yandex API by track ID → search API → Firefox MPRIS fallback."""

import subprocess
import os
import re
import json
import hashlib
import shutil
import time
import glob
import signal
import sys
import urllib.parse

CACHE_DIR = "/tmp/yandex_covers"
CURRENT_LINK = "/tmp/yandex_cover_current.jpg"
PID_FILE = os.path.join(CACHE_DIR, "art-cacher.pid")
TOKEN_FILE = os.path.expanduser("~/.config/yamusic-tui/config.yaml")
FIREFOX_ART_DIR = os.path.expanduser("~/.config/mozilla/firefox/firefox-mpris")
POLL_INTERVAL = 0.5
GRAB_DELAY = 1.0
MIN_ART_SIZE = 500  # bytes — skip tiny/broken files


def get_token():
    try:
        with open(TOKEN_FILE) as f:
            for line in f:
                if line.strip().startswith("token:"):
                    return line.split(":", 1)[1].strip().strip('"').strip("'")
    except Exception:
        pass
    return None


def pctl(*args):
    try:
        r = subprocess.run(
            ["playerctl", *args],
            capture_output=True, text=True, timeout=2
        )
        return r.stdout.strip()
    except Exception:
        return ""


def get_track_id():
    """Extract track ID from xesam:url like https://music.yandex.ru/album/XXX/track/YYY"""
    url = pctl("metadata", "xesam:url")
    if url:
        m = re.search(r'/track/(\d+)', url)
        if m:
            return m.group(1)
    return None


def curl_download(url, dest, headers=None):
    """Download URL to dest with curl. Returns True on success."""
    cmd = [
        "curl", "-s", "-L",
        "--connect-timeout", "3",
        "--max-time", "5",
        "-o", dest,
    ]
    if headers:
        for k, v in headers.items():
            cmd += ["-H", f"{k}: {v}"]
    cmd.append(url)
    try:
        r = subprocess.run(cmd, capture_output=True, timeout=10)
        return (
            r.returncode == 0
            and os.path.exists(dest)
            and os.path.getsize(dest) > MIN_ART_SIZE
        )
    except Exception:
        return False


def extract_cover_url(data):
    """Extract coverUri from Yandex API response and build full URL."""
    cover = None
    if isinstance(data, dict):
        cover = data.get("coverUri") or data.get("ogImage")
        if not cover:
            albums = data.get("albums", [])
            if albums and isinstance(albums[0], dict):
                cover = albums[0].get("coverUri") or albums[0].get("ogImage")
    if cover:
        cover = cover.replace("%%", "400x400")
        if not cover.startswith("http"):
            cover = "https://" + cover
        return cover
    return None


def fetch_art_by_track_id(track_id, token):
    """Get cover URL from Yandex Music API by track ID."""
    if not token:
        return None
    tmp = f"/tmp/_ym_api_{track_id}.json"
    url = f"https://api.music.yandex.net/tracks/{track_id}"
    headers = {"Authorization": f"OAuth {token}"}
    if curl_download(url, tmp, headers):
        try:
            with open(tmp) as f:
                data = json.load(f)
            results = data.get("result", [])
            if isinstance(results, list) and results:
                return extract_cover_url(results[0])
            elif isinstance(results, dict):
                return extract_cover_url(results)
        except Exception:
            pass
        finally:
            try:
                os.remove(tmp)
            except OSError:
                pass
    return None


def fetch_art_by_search(title, artist, token):
    """Fallback: search Yandex Music API for track cover."""
    if not token or not title:
        return None
    query = f"{title} {artist}".strip()
    encoded = urllib.parse.quote(query)
    tmp = "/tmp/_ym_api_search.json"
    url = f"https://api.music.yandex.net/search?type=track&text={encoded}&page=0&nocorrect=false"
    headers = {"Authorization": f"OAuth {token}"}
    if curl_download(url, tmp, headers):
        try:
            with open(tmp) as f:
                data = json.load(f)
            tracks = data.get("result", {}).get("tracks", {}).get("results", [])
            if tracks:
                return extract_cover_url(tracks[0])
        except Exception:
            pass
        finally:
            try:
                os.remove(tmp)
            except OSError:
                pass
    return None


def get_firefox_art():
    """Get art from Firefox MPRIS cache as last-resort fallback."""
    try:
        files = glob.glob(os.path.join(FIREFOX_ART_DIR, "*"))
        if files:
            return max(files, key=os.path.getmtime)
    except Exception:
        pass
    return None


def update_symlink(target):
    """Point current-cover symlink to target file."""
    try:
        tmp_link = CURRENT_LINK + ".tmp"
        os.symlink(target, tmp_link)
        os.rename(tmp_link, CURRENT_LINK)  # atomic
    except Exception:
        pass


def signal_waybar():
    """Signal waybar to refresh image module."""
    try:
        subprocess.run(["pkill", "-RTMIN+8", "waybar"], timeout=2)
    except Exception:
        pass


def cleanup_old():
    """Remove cached covers older than 7 days."""
    threshold = time.time() - 7 * 86400
    try:
        for f in glob.glob(os.path.join(CACHE_DIR, "*.jpg")):
            if os.path.getmtime(f) < threshold:
                os.remove(f)
    except Exception:
        pass


def grab_art(title, artist, track_id, token):
    """Try all sources in priority order. Returns path on success, None otherwise."""
    # Cache key: prefer track_id, fall back to hash of title|artist
    cache_key = track_id or hashlib.md5(f"{title}|{artist}".encode(), usedforsecurity=False).hexdigest()
    dest = os.path.join(CACHE_DIR, f"{cache_key}.jpg")

    # Already cached in good quality?
    if os.path.exists(dest) and os.path.getsize(dest) > MIN_ART_SIZE:
        return dest

    # 1. Try mpris:artUrl
    art_url = pctl("metadata", "mpris:artUrl")
    if art_url:
        if art_url.startswith("http"):
            if curl_download(art_url, dest):
                return dest
        elif art_url.startswith("file://"):
            src = art_url[7:]
            if os.path.exists(src) and os.path.getsize(src) > MIN_ART_SIZE:
                shutil.copy2(src, dest)
                return dest

    # 2. Yandex API by track ID (most reliable)
    if track_id and token:
        cover_url = fetch_art_by_track_id(track_id, token)
        if cover_url and curl_download(cover_url, dest):
            return dest

    # 3. Yandex API search fallback
    if token and title:
        cover_url = fetch_art_by_search(title, artist, token)
        if cover_url and curl_download(cover_url, dest):
            return dest

    # 4. Firefox MPRIS art (low quality, last resort)
    ff_art = get_firefox_art()
    if ff_art and os.path.getsize(ff_art) > 100:
        shutil.copy2(ff_art, dest)
        return dest

    return None


def main():
    os.makedirs(CACHE_DIR, exist_ok=True)

    # Kill previous instance
    if os.path.exists(PID_FILE):
        try:
            with open(PID_FILE) as f:
                old_pid = int(f.read().strip())
            if old_pid != os.getpid():
                os.kill(old_pid, signal.SIGTERM)
                time.sleep(0.2)
        except (ValueError, ProcessLookupError, OSError):
            pass

    with open(PID_FILE, "w") as f:
        f.write(str(os.getpid()))

    def on_exit(*_):
        try:
            os.remove(PID_FILE)
        except OSError:
            pass
        sys.exit(0)

    signal.signal(signal.SIGTERM, on_exit)
    signal.signal(signal.SIGINT, on_exit)

    # Cleanup old files on startup
    cleanup_old()

    token = get_token()
    last_title = ""
    pending = []  # (grab_at, title, artist, track_id)

    while True:
        try:
            title = pctl("metadata", "xesam:title")
            artist = pctl("metadata", "xesam:artist")
            track_id = get_track_id()

            # Detect track change
            if title and title != last_title:
                last_title = title
                pending.append((time.time() + GRAB_DELAY, title, artist, track_id))

            # Process pending grabs
            now = time.time()
            still_pending = []
            for grab_at, t, a, tid in pending:
                if now >= grab_at:
                    # Re-read track ID in case it wasn't available initially
                    if not tid:
                        tid = get_track_id()
                    path = grab_art(t, a, tid, token)
                    if path:
                        update_symlink(path)
                        signal_waybar()
                else:
                    still_pending.append((grab_at, t, a, tid))
            pending = still_pending

        except Exception:
            pass

        time.sleep(POLL_INTERVAL)


if __name__ == "__main__":
    main()
