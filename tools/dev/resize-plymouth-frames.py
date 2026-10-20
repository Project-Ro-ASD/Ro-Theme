#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Plymouth animasyon karelerini (throbber-NNNN.png) yeni bir kare boyutuna ölçekler.

Kullanım: tools/dev/resize-plymouth-frames.py <kaynak-klasör> <hedef-boyut> [hedef-klasör]
Kaynak kareler kare ve RGBA olmalı. Ölçekleme önceden çarpılmış alfa ile yapılır (kenarda koyu/açık halo olmaz).
İlk 320 px kareler git geçmişinde: fa435f6 (platform/plymouth/ro-theme). Two-step modülü görselleri ölçeklemez
(yalnız yüksek DPI'da tam sayı katı), bu yüzden boyut kare dosyalarının kendisidir (PLY-05).
"""
import sys
from pathlib import Path

from PIL import Image


def main(src, size, dst=None):
    src, dst, size = Path(src), Path(dst or src), int(size)
    dst.mkdir(parents=True, exist_ok=True)
    frames = sorted(src.glob("throbber-*.png"))
    if not frames:
        sys.exit(f"{src}: throbber-*.png bulunamadı")
    for f in frames:
        im = Image.open(f).convert("RGBA")
        if im.width != im.height:
            sys.exit(f"{f.name}: kare değil ({im.size})")
        out = im.convert("RGBa").resize((size, size), Image.LANCZOS).convert("RGBA")
        out.save(dst / f.name, optimize=True)
    print(f"{len(frames)} kare {size}×{size} px")


if __name__ == "__main__":
    if len(sys.argv) not in (3, 4):
        sys.exit(__doc__)
    main(*sys.argv[1:])
