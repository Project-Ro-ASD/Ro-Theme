"""ro smoke: canlı oturumda yedek alıp temayı uçtan uca dener."""
from __future__ import annotations

import os
import shutil
import sys
from datetime import datetime
from pathlib import Path

from . import ROOT, manifest, sysutil
from .diagnose import CRASH_NAMES

# Sırayla çalıştırılan komutlar; biri başarısız olursa deneme durur.
STEPS = (
    ("generate --check", ("generate", "--check")),
    ("validate", ("validate",)),
    ("install --local --files-only", ("install", "--local", "--files-only")),
    ("check-runtime layout", ("check-runtime", "layout")),
    ("apply dark", ("apply", "dark")),
    ("diagnose --local", ("diagnose", "--local")),
    ("apply light", ("apply", "light")),
    ("diagnose --local", ("diagnose", "--local")),
    ("apply dark", ("apply", "dark")),
)


def _backup(env) -> tuple[Path, list[str]]:
    """Kullanıcı panel ve KDE ayarlarını ~/.local/share/ro-theme/yedek-<zaman>/ altına kopyalar."""
    config = sysutil.config_home(env)
    names = [name for name in manifest.SMOKE_CONFIG_FILES if (config / name).is_file()]
    backup = sysutil.backup_dir(sysutil.data_home(env) / manifest.BACKUP_DIR, prefix="yedek")
    for name in names:
        shutil.copy2(config / name, backup / name)
    return backup, names


def _run_step(name: str, command: tuple[str, ...], env) -> bool:
    proc = sysutil.run([sys.executable, str(ROOT / "ro"), *command], env, timeout=300)
    if proc is None or proc.returncode != 0:
        print(f"[FAIL] {name}", file=sys.stderr)
        for text in (proc.stdout, proc.stderr) if proc is not None else ("", ""):
            if text.strip():
                print(text.rstrip(), file=sys.stderr)
        return False
    print(f"[OK] {name}")
    return True


def _crashes(start: datetime, env) -> tuple[bool, list[str]]:
    """Başlangıçtan bu yana plasmashell/kwin çökmesi var mı?"""
    if not sysutil.which("coredumpctl", env):
        print("uyarı: coredumpctl bulunamadı; çökme günlüğü denetlenemedi", file=sys.stderr)
        return True, []
    since = start.strftime("%Y-%m-%d %H:%M:%S")
    proc = sysutil.run(["coredumpctl", "list", "--since", since], env)
    if proc is None or proc.returncode != 0:
        print("uyarı: coredumpctl çalıştırılamadı; çökme günlüğü denetlenemedi", file=sys.stderr)
        return True, []
    lines = [line for line in proc.stdout.splitlines() if any(name in line for name in CRASH_NAMES)]
    if not lines:
        print("[OK] çökme denetimi")
        return True, []
    print("[FAIL] çökme denetimi", file=sys.stderr)
    print("\n".join(lines[-20:]), file=sys.stderr)
    return False, lines


def _confirm() -> bool:
    try:
        answer = input("Canlı oturumda tema denenecek. Devam etmek için 'evet' yazın [e/H]: ")
    except (EOFError, KeyboardInterrupt):
        return False
    return answer.strip().lower() in ("e", "evet", "y", "yes")


def run(yes: bool = False, env=None) -> int:
    env = dict(env or os.environ)
    if not yes and not _confirm():
        print("ro smoke: onay verilmedi; hiçbir adım çalıştırılmadı.", file=sys.stderr)
        return 1

    start = datetime.now()
    backup, names = _backup(env)
    print(f"Yedek: {backup}")
    if not names:
        print("uyarı: yedeklenecek KDE ayar dosyası bulunamadı", file=sys.stderr)

    errors = 0
    for name, command in STEPS:
        if not _run_step(name, command, env):
            errors += 1
            break

    healthy, _ = _crashes(start, env)
    if not healthy:
        errors += 1

    print(f"Smoke özeti: {errors} hata; yedek: {backup}")
    if errors:
        print("Geri dönmek için yedekteki dosyaları ~/.config altına kopyalayın.", file=sys.stderr)
    return 1 if errors else 0


def main(args) -> int:
    return run(yes=bool(getattr(args, "yes", False)))
