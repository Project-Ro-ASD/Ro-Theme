"""Küçük ortam yardımcıları: XDG yolları, PATH araması, komut çalıştırma ve SHA-256."""
from __future__ import annotations

import hashlib
import os
import re
import secrets
import shutil
import subprocess
from datetime import datetime
from pathlib import Path


def home(env=None) -> Path:
    return Path((env or os.environ).get("HOME") or Path.home())


def data_home(env=None) -> Path:
    raw = (env or os.environ).get("XDG_DATA_HOME")
    return Path(raw) if raw else home(env) / ".local/share"


def config_home(env=None) -> Path:
    raw = (env or os.environ).get("XDG_CONFIG_HOME")
    return Path(raw) if raw else home(env) / ".config"


def data_dirs(env=None) -> list[Path]:
    raw = (env or os.environ).get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share"
    return [Path(p) for p in raw.split(":") if p]


def which(name: str, env=None) -> str | None:
    return shutil.which(name, path=(env or os.environ).get("PATH"))


def run(cmd, env=None, timeout: int = 20):
    """Komutu çalıştırır; araç PATH'te yoksa None döner."""
    env = dict(env or os.environ)
    if not which(str(cmd[0]), env):
        return None
    try:
        return subprocess.run([str(c) for c in cmd], env=env, capture_output=True,
                              text=True, timeout=timeout, check=False)
    except OSError:
        return None


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def timestamp() -> str:
    return datetime.now().strftime("%Y%m%d-%H%M%S")


def group_flags(group: str) -> list[str]:
    """'[A][B]' -> ['--group', 'A', '--group', 'B'] (KDE araçları iç içe grup ister)."""
    return [part for name in re.findall(r"\[([^\]]*)\]", group) for part in ("--group", name)]


def backup_dir(root: Path, prefix: str = "backup") -> Path:
    """backup-YYYYmmdd-HHMMSS-XXXXXX biçiminde yeni ve boş bir yedek dizini açar."""
    root.mkdir(parents=True, exist_ok=True)
    while True:
        path = root / f"{prefix}-{timestamp()}-{secrets.token_hex(3)}"
        try:
            path.mkdir()
            return path
        except FileExistsError:
            continue
