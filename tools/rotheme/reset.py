"""ro reset-defaults: kullanıcının Ro ayarlarını /etc/xdg varsayılanlarına döndürür."""
from __future__ import annotations

import os
import shutil
import stat
import sys
import tempfile
from pathlib import Path

from . import manifest, sysutil
from .kconfig import HEADER, KConfig, bare_key


class SymlinkError(Exception):
    pass


class ConcurrentChange(Exception):
    pass


def _managed_keys(env) -> dict[str, dict[str, set[str]]]:
    system_xdg = Path((env or os.environ).get("RO_THEME_SYSTEM_XDG") or "/etc/xdg")
    managed: dict[str, dict[str, set[str]]] = {}
    for name in manifest.XDG_FILES:
        path = system_xdg / name
        if not path.is_file():
            continue
        try:
            cfg = KConfig.parse(path.read_text(encoding="utf-8"))
        except OSError:
            continue
        for group, keys in cfg.groups.items():
            if keys:
                managed.setdefault(name, {}).setdefault(group, set()).update(bare_key(k) for k in keys)
    for name, groups in manifest.LEGACY_KEYS.items():
        for group, keys in groups.items():
            managed.setdefault(name, {}).setdefault(group, set()).update(keys)
    return managed


def _filter_text(text: str, managed: dict[str, set[str]]) -> tuple[str, list[tuple[str, str]]]:
    """Yönetilen anahtarları satır satır siler; yorumları ve boş olmayan grupları korur."""
    lines = text.splitlines()
    out: list[str] = []
    removed: list[tuple[str, str]] = []
    index = 0
    while index < len(lines) and not HEADER.match(lines[index].strip()):
        out.append(lines[index])
        index += 1
    while index < len(lines):
        header = lines[index].strip()
        if not HEADER.match(header):
            out.append(lines[index])
            index += 1
            continue
        block = [lines[index]]
        index += 1
        has_key = False
        keys = managed.get(header, set())
        while index < len(lines) and not HEADER.match(lines[index].strip()):
            line = lines[index]
            stripped = line.strip()
            key, sep, _ = stripped.partition("=")
            if sep and not stripped.startswith("#") and bare_key(key) in keys:
                removed.append((header, key.strip()))
                index += 1
                continue
            if sep and not stripped.startswith("#"):
                has_key = True
            block.append(line)
            index += 1
        if has_key:
            out.extend(block)
    return ("\n".join(out).rstrip("\n") + "\n") if out else "", removed


def _prepare(config_home: Path, managed) -> list[dict]:
    entries = []
    for name in manifest.XDG_FILES:
        path = config_home / name
        if not path.exists() and not path.is_symlink():
            continue
        if path.is_symlink():
            raise SymlinkError(f"{path}: expected a regular, non-symlink config file")
        if not path.is_file():
            raise SymlinkError(f"{path}: expected a regular, non-symlink config file")
        text = path.read_text(encoding="utf-8")
        filtered, removed = _filter_text(text, managed.get(name, {}))
        if removed:
            entries.append({"path": path, "name": name, "text": filtered, "removed": removed,
                            "sha": sysutil.sha256(path),
                            "mode": stat.S_IMODE(path.stat().st_mode)})
    return entries


def _atomic_replace(source: Path, target: Path) -> None:
    try:
        os.replace(source, target)
    except OSError:
        sibling = target.with_name(f".{target.name}.ro-tmp")
        shutil.copy2(source, sibling)
        os.replace(sibling, target)


def _reset(env, dry_run: bool) -> int:
    config_home = sysutil.config_home(env)
    try:
        entries = _prepare(config_home, _managed_keys(env))
    except SymlinkError as e:
        print(str(e), file=sys.stderr)
        return 1

    total = sum(len(e["removed"]) for e in entries)
    if dry_run:
        for entry in entries:
            for group, key in entry["removed"]:
                print(f"would reset: {entry['path']} {group} {key}")
        print(f"Ro appearance settings reset to the system defaults: {total} setting(s) would be removed.")
        return 0

    tmpdir = Path(tempfile.mkdtemp(prefix="ro-reset-", dir=env.get("TMPDIR") or None))
    backup = None
    try:
        for entry in entries:
            temp = tmpdir / entry["name"]
            temp.write_text(entry["text"], encoding="utf-8")
            os.chmod(temp, entry["mode"])

        if entries:
            backup = sysutil.backup_dir(config_home / manifest.BACKUP_DIR)
            for entry in entries:
                shutil.copy2(entry["path"], backup / entry["name"])

        for entry in entries:
            if sysutil.sha256(entry["path"]) != entry["sha"]:
                raise ConcurrentChange(f"{entry['path']} changed during reset; stopping.")

        replaced = []
        try:
            for entry in entries:
                _atomic_replace(tmpdir / entry["name"], entry["path"])
                replaced.append(entry)
        except OSError as e:
            for entry in reversed(replaced):
                shutil.copy2(backup / entry["name"], entry["path"])
            print(f"reset hatası: {e}; önceki dosyalar geri yüklendi.", file=sys.stderr)
            return 1
    except ConcurrentChange as e:
        print(str(e), file=sys.stderr)
        return 1
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)

    marker = config_home / manifest.LEGACY_MARKER
    if marker.exists() or marker.is_symlink():
        marker.unlink()
    print(f"Ro appearance settings reset to the system defaults: {total} setting(s) removed from your files.")
    if backup:
        print(f"Backup: {backup}")
    print("Log out and back in to see all changes.")
    return 0


def main(args) -> int:
    if getattr(os, "geteuid", lambda: 1)() == 0:
        print("run this as your own user, not as root.", file=sys.stderr)
        return 2
    for flag in ("all_users", "force"):
        if getattr(args, flag, False):
            name = "--all-users" if flag == "all_users" else "--force"
            print(f"apply-dark-defaults: {name} was removed; the tool only changes the current user's own settings.",
                  file=sys.stderr)
            return 2
    return _reset(dict(os.environ), bool(getattr(args, "dry_run", False)))
