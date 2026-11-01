"""Kurulu ağaç denetimleri: RPM buildroot ya da sistem kurulumu (`--installed KÖK`).

Paketleme, spec metni yerine kurulmuş dosya ağacı üzerinden doğrulanır.
"""
from __future__ import annotations

from pathlib import Path

from .. import manifest
from . import check
from .common import read_kconfig
from .source import _emit


def _dest(root: Path, entry: manifest.Entry) -> Path:
    return root / entry.dest.format(**manifest.DIRS).lstrip("/")


@check("VAL-PKG-01", "packaging", "kurulu ağaç manifest hedefleri", target="installed")
def _(ctx):
    errors = []
    for entry in manifest.INSTALL:
        path = _dest(ctx.root, entry)
        if not path.exists():
            errors.append(f"{path.relative_to(ctx.root)}: kurulu değil")
    yield from _emit(errors, "manifest hedefleri kurulu")


@check("VAL-PKG-02", "packaging", "kurulu ağaç zorunlu paket yolları", target="installed")
def _(ctx):
    errors = [f"{rel}: kurulu dosya yok" for rel in manifest.INSTALLED_REQUIRED
              if not (ctx.root / rel).is_file()]
    yield from _emit(errors, "zorunlu paket yolları kurulu")


@check("VAL-PKG-03", "packaging", "kurulu ağaç kullanıcı evi ve otomatik başlatma izolasyonu",
      target="installed")
def _(ctx):
    errors = []
    for rel in ("etc/xdg/autostart", "home", "root"):
        if (ctx.root / rel).exists():
            errors.append(f"{rel}: kurulu ağaçta olmamalı")
    yield from _emit(errors, "kurulu ağaç yalıtılmış")


@check("VAL-PKG-04", "packaging", "kurulu ağaç yapılandırma dosyaları", target="installed")
def _(ctx):
    errors = []
    for name in manifest.XDG_FILES:
        path = ctx.root / "etc/xdg" / name
        if not path.is_file():
            errors.append(f"etc/xdg/{name}: dosya yok")
            continue
        if path.stat().st_mode & 0o022:
            errors.append(f"etc/xdg/{name}: grup/diğer yazma izni olmamalı")
        cfg, error = read_kconfig(path)
        if error:
            errors.append(error)
        elif not any(cfg.groups.values()):
            errors.append(f"etc/xdg/{name}: boş yapılandırma")
    yield from _emit(errors, "yapılandırma dosyaları doğru")
