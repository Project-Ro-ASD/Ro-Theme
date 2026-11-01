"""ro apply: Ro Açık/Koyu temayı canlı KDE oturumuna uygular."""
from __future__ import annotations

import os
import shutil
import sys
from pathlib import Path

from . import manifest, sysutil
from .kconfig import KConfig


def _search_dirs(env) -> list[Path]:
    dirs = [sysutil.data_home(env), sysutil.home(env) / ".local/share"] + sysutil.data_dirs(env)
    unique = []
    for d in dirs:
        if d not in unique:
            unique.append(d)
    return unique


def _defaults(package: str, env) -> Path | None:
    for base in _search_dirs(env):
        path = base / "plasma/look-and-feel" / package / "contents/defaults"
        if path.is_file():
            return path
    return None


def _wallpaper(theme: str, env) -> Path | None:
    for base in _search_dirs(env):
        path = base / "ro-theme/wallpapers" / f"{theme}.jpg"
        if path.is_file():
            return path
    return None


def _backup(config_home: Path, names, env) -> Path | None:
    existing = [config_home / n for n in names if (config_home / n).is_file()]
    if not existing:
        return None
    backup = sysutil.backup_dir(config_home / manifest.BACKUP_DIR)
    for path in existing:
        shutil.copy2(path, backup / path.name)
    return backup


def _kwrite(tool: str, file: str, group: str, key: str, value: str, env) -> bool:
    cmd = [tool, "--file", file, *sysutil.group_flags(group), "--key", key, value]
    proc = sysutil.run(cmd, env)
    return proc is not None and proc.returncode == 0


def _delete(tool: str, file: str, group: str, key: str, env) -> None:
    cmd = [tool, "--file", file, *sysutil.group_flags(group), "--key", key, "--delete"]
    sysutil.run(cmd, env)


def _reconfigure(env) -> bool | None:
    for tool in ("qdbus6", "qdbus"):
        if sysutil.which(tool, env):
            proc = sysutil.run([tool, "org.kde.KWin", "/KWin", "reconfigure"], env)
            return proc is not None and proc.returncode == 0
    if sysutil.which("gdbus", env):
        proc = sysutil.run(["gdbus", "call", "--session", "--dest", "org.kde.KWin",
                            "--object-path", "/KWin", "--method", "org.kde.KWin.reconfigure"], env)
        return proc is not None and proc.returncode == 0
    return None


def _refresh_shell(env) -> bool | None:
    for tool in ("qdbus6", "qdbus"):
        if sysutil.which(tool, env):
            proc = sysutil.run([tool, "org.kde.PlasmaShell", "/PlasmaShell",
                                "evaluateScript", ""], env)
            return proc is not None and proc.returncode == 0
    return None


def run(theme: str, env=None, live: bool = False) -> int:
    env = dict(env or os.environ)
    if theme not in manifest.THEMES:
        print(f"ro apply: bilinmeyen tema: {theme}", file=sys.stderr)
        return 2
    package = manifest.THEMES[theme][1]
    defaults = _defaults(package, env)
    if defaults is None:
        print(f"ro apply: {package}: contents/defaults bulunamadı; oturum değiştirilmedi.", file=sys.stderr)
        return 1
    try:
        cfg = KConfig.parse(defaults.read_text(encoding="utf-8"))
    except OSError as e:
        print(f"ro apply: {defaults}: okunamadı ({e}); oturum değiştirilmedi.", file=sys.stderr)
        return 1

    values = {}
    for file, group, key in manifest.APPLY_KEYS:
        value = cfg.get(f"[{file}]{group}", key)
        if value is not None and value.strip():
            values[(file, group, key)] = value
    missing = [f"{file} {group} {key}" for file, group, key in manifest.APPLY_REQUIRED
               if (file, group, key) not in values]
    if missing:
        print("ro apply: contents/defaults içinde zorunlu anahtar eksik: " + ", ".join(missing),
              file=sys.stderr)
        return 1

    failures: list[str] = []
    warnings: list[str] = []
    names = sorted({file for file, _, _ in manifest.APPLY_KEYS})
    backup = _backup(sysutil.config_home(env), names, env)

    scheme = values[("kdeglobals", "[General]", "ColorScheme")]
    tool = sysutil.which("plasma-apply-colorscheme", env)
    if not tool:
        failures.append("plasma-apply-colorscheme bulunamadı")
    else:
        proc = sysutil.run([tool, scheme], env)
        if proc is None or proc.returncode != 0:
            failures.append(f"renk şeması uygulanamadı: {scheme}")

    kwrite = sysutil.which("kwriteconfig6", env)
    if not kwrite:
        failures.append("kwriteconfig6 bulunamadı")
    else:
        for (file, group, key), value in values.items():
            if not _kwrite(kwrite, file, group, key, value, env):
                failures.append(f"{file} {group} {key} yazılamadı")
        for file, groups in manifest.LEGACY_KEYS.items():
            for group, keys in groups.items():
                for key in keys:
                    _delete(kwrite, file, group, key, env)

    wallpaper = _wallpaper(theme, env)
    wallpaper_tool = sysutil.which("plasma-apply-wallpaperimage", env)
    if wallpaper is None:
        failures.append(f"duvar kağıdı bulunamadı: ro-theme/wallpapers/{theme}.jpg")
    elif not wallpaper_tool:
        failures.append("plasma-apply-wallpaperimage bulunamadı")
    else:
        proc = sysutil.run([wallpaper_tool, str(wallpaper)], env)
        if proc is None or proc.returncode != 0:
            failures.append(f"duvar kağıdı uygulanamadı: {wallpaper}")

    state = _reconfigure(env)
    if state is False:
        failures.append("KWin yeniden yapılandırılamadı")
    elif state is None:
        warnings.append("KWin reconfigure için D-Bus aracı bulunamadı")
    if live:
        state = _refresh_shell(env)
        if state is False:
            warnings.append("plasmashell yenilenemedi")
        elif state is None:
            warnings.append("plasmashell yenilemesi için D-Bus aracı bulunamadı")

    if backup:
        print(f"Yedek: {backup}")
    for message in warnings:
        print(f"uyarı: {message}", file=sys.stderr)
    for message in failures:
        print(f"hata: {message}", file=sys.stderr)
    if failures:
        return 1
    print(f"Ro {manifest.THEMES[theme][2]} teması uygulandı.")
    return 0


def main(args) -> int:
    return run(getattr(args, "theme", manifest.DEFAULT_THEME),
               live=bool(getattr(args, "live_plasmashell", False)))
