"""ro system-preview: giriş ekranı ve Plymouth bileşenlerini sistemde dener."""
from __future__ import annotations

import os
import shutil
import sys
from pathlib import Path

from . import ROOT, manifest, sysutil


def _sysroot(env) -> Path:
    return Path(env.get("RO_THEME_SYSROOT") or "/")


def _target(entry: manifest.Entry, env) -> Path:
    return _sysroot(env) / entry.dest.format(**manifest.DIRS).lstrip("/")


def _rpm_owns_files(env) -> bool:
    """ro-theme RPM ile kuruluysa dosyaların sahibi pakettir; önizleme yapılmaz."""
    if not sysutil.which("rpm", env):
        return False
    proc = sysutil.run(["rpm", "-q", manifest.PACKAGE], env)
    if proc is not None and proc.returncode == 0:
        print(f"ro system-preview: {manifest.PACKAGE} RPM ile kurulu; dosyaların sahibi paket. "
              "Önizleme için önce paketi kaldırın.", file=sys.stderr)
        return True
    return False


def _missing_sources() -> list[str]:
    missing = []
    for entry in manifest.PREVIEW_ENTRIES:
        source = ROOT / entry.src
        if source.is_dir():
            if not (source / f"{manifest.PLYMOUTH_THEME}.plymouth").is_file():
                missing.append(entry.src)
        elif not source.is_file():
            missing.append(entry.src)
    return missing


def _plymouth(env, theme: str | None) -> bool:
    tool = sysutil.which("plymouth-set-default-theme", env)
    if not tool:
        print("uyarı: plymouth-set-default-theme bulunamadı; Plymouth etkinleştirmesi atlandı.",
              file=sys.stderr)
        return True
    command = [tool, "-R", theme] if theme else [tool, "--reset", "-R"]
    proc = sysutil.run(command, env, timeout=300)
    if proc is None or proc.returncode != 0:
        detail = "" if proc is None else (proc.stdout + proc.stderr).strip()
        print("ro system-preview: Plymouth teması etkinleştirilemedi", file=sys.stderr)
        if detail:
            print(detail, file=sys.stderr)
        return False
    return True


def _install(env) -> int:
    missing = _missing_sources()
    if missing:
        for src in missing:
            print(f"eksik kaynak: {src}", file=sys.stderr)
        print("Kaynaklar eksik; hiçbir dosya değiştirilmedi.", file=sys.stderr)
        return 1

    try:
        for entry in manifest.PREVIEW_ENTRIES:
            source = ROOT / entry.src
            target = _target(entry, env)
            target.parent.mkdir(parents=True, exist_ok=True)
            if target.is_dir() and not target.is_symlink():
                shutil.rmtree(target)
            elif target.exists() or target.is_symlink():
                target.unlink()
            if source.is_dir():
                shutil.copytree(source, target, symlinks=True)
            else:
                shutil.copy2(source, target)
                os.chmod(target, entry.mode)
    except OSError as e:
        print(f"ro system-preview: kurulum hatası: {e}", file=sys.stderr)
        return 1

    if not _plymouth(env, manifest.PLYMOUTH_THEME):
        return 1
    print("Sistem önizlemesi kuruldu. Denemek için yeniden başlatın.")
    return 0


def _remove(env) -> int:
    if not _plymouth(env, None):
        return 1
    try:
        for entry in manifest.PREVIEW_ENTRIES:
            target = _target(entry, env)
            if target.is_dir() and not target.is_symlink():
                shutil.rmtree(target)
            elif target.exists() or target.is_symlink():
                target.unlink()
    except OSError as e:
        print(f"ro system-preview: kaldırma hatası: {e}", file=sys.stderr)
        return 1
    print("Sistem önizlemesi kaldırıldı; Plymouth varsayılan temasına dönüldü.")
    return 0


def run(remove: bool = False, env=None) -> int:
    env = dict(env or os.environ)
    if os.geteuid() != 0:
        print("ro system-preview: bu komut root olarak çalıştırılmalı.", file=sys.stderr)
        return 1
    if _rpm_owns_files(env):
        return 1
    return _remove(env) if remove else _install(env)


def main(args) -> int:
    return run(remove=bool(getattr(args, "remove", False)))
