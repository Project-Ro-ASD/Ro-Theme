#!/usr/bin/env python3
"""Ro-GTK CSS dosyalarını gerçek GTK3/GTK4 ayrıştırıcılarıyla, ekransız denetler."""
import argparse
import os
from pathlib import Path
import subprocess
import sys
import tempfile


# GTK ana sürümleri aynı süreçte yüklenemez; her dosya ayrı süreçte ayrıştırılır.
PROBE = r'''
import sys
version, path = sys.argv[1:]
try:
    import gi
    gi.require_version("Gtk", version)
    from gi.repository import Gtk, GLib
except (ImportError, ValueError) as error:
    print(f"[FAIL] GTK {version}: parser unavailable: {error}", file=sys.stderr)
    sys.exit(2)

errors = []
def report(provider, section, error):
    errors.append(error.message)
    print(f"[FAIL] GTK {version}: {path}: {error.message}", file=sys.stderr)

provider = Gtk.CssProvider()
provider.connect("parsing-error", report)
try:
    provider.load_from_path(path)
except GLib.Error as error:
    if not errors:
        errors.append(error.message)
        print(f"[FAIL] GTK {version}: {path}: {error.message}", file=sys.stderr)
if errors:
    sys.exit(1)
print(f"[OK] GTK {version}: {path}")
'''


def check(root):
    failures = 0
    # GTK init edilmez; ekran, oturum veri yolu ve kullanıcı ayarları gerekmez.
    with tempfile.TemporaryDirectory(prefix="ro-gtk-css-") as temporary:
        env = os.environ.copy()
        for name in ("DISPLAY", "WAYLAND_DISPLAY", "DBUS_SESSION_BUS_ADDRESS"):
            env.pop(name, None)
        env.update(HOME=temporary, XDG_CONFIG_HOME=f"{temporary}/config",
                   XDG_DATA_HOME=f"{temporary}/data", XDG_CACHE_HOME=f"{temporary}/cache",
                   XDG_RUNTIME_DIR=temporary, DBUS_SESSION_BUS_ADDRESS=f"unix:path={temporary}/bus")
        for version in ("3.0", "4.0"):
            path = root / "platform/gtk/Ro-GTK" / f"gtk-{version}" / "gtk.css"
            if not path.is_file():
                print(f"[FAIL] GTK {version}: missing CSS file: {path}", file=sys.stderr)
                failures += 1
                continue
            try:
                result = subprocess.run([sys.executable, "-c", PROBE, version, str(path)],
                                        env=env, timeout=30)
                failures += result.returncode != 0
            except subprocess.TimeoutExpired:
                print(f"[FAIL] GTK {version}: parser timed out: {path}", file=sys.stderr)
                failures += 1
    print(f"GTK CSS validation: {failures} failed check(s)")
    return bool(failures)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Parse Ro-GTK CSS with GTK3 and GTK4 without a display.")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2],
                        help="source tree to check (default: this repository)")
    sys.exit(check(parser.parse_args().root.resolve()))
