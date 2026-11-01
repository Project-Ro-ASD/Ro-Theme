"""Token'lardan türetilen tüm dosyaların üretimi.

Her alt modül `outputs(ctx) -> dict[str, str | bytes]` fonksiyonu sağlar: depo köküne göre yol -> içerik.
Çatı tüm çıktıları önce bellekte toplar (bir modül hata verirse hiçbir şey yazılmaz), sonra:
- normal modda değişen dosyaları geçici dosya + rename ile atomik yazar,
- `--check` modunda diske dokunmadan depodaki dosyalarla karşılaştırır,
- `--list` modunda yalnız yolları yazar.
"""
from __future__ import annotations

import importlib
import os
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

from .. import ROOT
from .. import tokens as tok

# Sıra önemsiz; her modül kendi dosya ailesinden sorumludur.
MODULES = (
    "colors",        # renk şemaları + desktoptheme colors (gereksinimler/10)
    "xdg",           # /etc/xdg varsayılanları (10)
    "lookandfeel",   # global tema defaults + metadata, desktoptheme metadata/plasmarc (10)
    "desktoptheme",  # 29 SVG x 2 tema (11)
    "aurorae",       # pencere dekorasyonu (12)
    "layout",        # panel düzeni JS x3 (13)
    "qml",           # dist/qml/RoTokens.qml (13)
    "plymouth",      # .plymouth + 4 PNG (14)
    "grub",          # theme.txt (14)
)


@dataclass(frozen=True)
class Context:
    tokens: tok.Tokens
    root: Path

    @property
    def version(self) -> str:
        return self.tokens.version


def collect(ctx: Context, only: tuple[str, ...] = MODULES) -> dict[str, bytes]:
    out: dict[str, bytes] = {}
    for name in only:
        mod = importlib.import_module(f"{__name__}.{name}")
        for rel, content in mod.outputs(ctx).items():
            if rel in out:
                raise RuntimeError(f"{rel} iki modül tarafından üretiliyor ({name})")
            out[rel] = content.encode("utf-8") if isinstance(content, str) else content
    return dict(sorted(out.items()))


def _write_atomic(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.")
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(data)
        os.chmod(tmp, 0o644)
        os.replace(tmp, path)
    except BaseException:
        Path(tmp).unlink(missing_ok=True)
        raise


def run(root: Path = ROOT, outdir: Path | None = None, check: bool = False, list_only: bool = False,
        only: tuple[str, ...] = MODULES) -> int:
    try:
        ctx = Context(tok.load(root), root)
        files = collect(ctx, only)
    except tok.TokenError as e:
        print(f"token hatası: {e}", file=sys.stderr)
        return 1
    if list_only:
        print("\n".join(files))
        return 0
    base = outdir or root
    changed = [rel for rel, data in files.items()
               if not (base / rel).is_file() or (base / rel).read_bytes() != data]
    if check:
        for rel in changed:
            print(f"güncel değil: {rel}", file=sys.stderr)
        print(f"{len(files)} dosya denetlendi, {len(changed)} tanesi güncel değil")
        return 1 if changed else 0
    for rel in changed:
        _write_atomic(base / rel, files[rel])
    print(f"{len(files)} dosya üretildi, {len(changed)} tanesi değişti")
    return 0
