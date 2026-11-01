#!/usr/bin/env python3
"""GRUB temasının seçili satır hapı ve Ro simgeleri (platform/grub/ro). Elle çalıştırılır; çıktılar depoya girer, derlemede gerekmez.
Gerekir: Pillow, numpy. Renkler core/tokens/colors.dark.json'dan. Kullanım: scripts/make-grub-assets.py

- select_*.png: seçili satırın 9 dilimi, yarı saydam vurgu dolgusu ve ince vurgu kenarı (menüde panel yok).
- item_*.png: seçili olmayan satırların tamamen saydam 9 dilimi (satır aralığı seçimle değişmesin).
- icons/ro.png (+ fedora, gnu-linux, linux): Ro logosunun (assets/brand/roasd-logo.png) yayları, yazısız.
- icons/recovery.png (+ advanced): can simidi (halka motifi).
Arka plan (bg.jpg) yapay zekâ üretimidir; kaynağı ve istemi Ro-Theme-Docs 24'te. Windows ve UEFI simgeleri elle çizilmiştir."""
import json, math
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

root = Path(__file__).resolve().parent.parent
out = root / 'platform/grub/ro'
acc = tuple(int(json.load(open(root / 'core/tokens/colors.dark.json'))['accent'].lstrip('#')[i:i + 2], 16) for i in (0, 2, 4))

# --- seçili satır hapı: köşe 8 px, 4x süper örnekleme ---
N, S = 8, 4
fill, edge = acc + (56,), acc + (150,)
sz = 3 * N * S
def mask(inset, r):
    m = Image.new('L', (sz, sz), 0)
    ImageDraw.Draw(m).rounded_rectangle((inset, inset, sz - 1 - inset, sz - 1 - inset), radius=r, fill=255)
    return m
img = Image.new('RGBA', (sz, sz), (0, 0, 0, 0))
img.paste(Image.new('RGBA', (sz, sz), edge), (0, 0), mask(0, N * S))
img.paste(Image.new('RGBA', (sz, sz), fill), (0, 0), mask(S, N * S - S))
img = img.resize((3 * N, 3 * N), Image.LANCZOS)
for k, (x, y) in {'nw': (0, 0), 'n': (1, 0), 'ne': (2, 0), 'w': (0, 1), 'c': (1, 1), 'e': (2, 1), 'sw': (0, 2), 's': (1, 2), 'se': (2, 2)}.items():
    img.crop((x * N, y * N, (x + 1) * N, (y + 1) * N)).save(out / f'select_{k}.png')

# --- Seçili olmayan satırlar için aynı ölçüde saydam dilimler ---
# gfxmenu seçili satırın içeriğini hap dilimlerinin kalınlığı kadar kaydırır; seçili olmayanlara da aynı ölçüde saydam bir çerçeve verilince
# bütün satırlar aynı kaydırmayı alır ve seçim değişince satır aralıkları oynamaz.
blank = Image.new('RGBA', (N, N), (0, 0, 0, 0))
for k in ('nw', 'n', 'ne', 'w', 'c', 'e', 'sw', 's', 'se'):
    blank.save(out / f'item_{k}.png')

# --- Ro simgesi: logonun yayları ---
logo = Image.open(root / 'assets/brand/roasd-logo.png').convert('RGBA'); a = np.array(logo)
gri = (np.abs(a[..., 0].astype(int) - a[..., 2].astype(int)) < 18) & (a[..., 3] > 0); a[gri, 3] = 0
arc = Image.fromarray(a); arc = arc.crop(arc.getchannel('A').getbbox())
s = max(arc.size); sq = Image.new('RGBA', (s, s), (0, 0, 0, 0)); sq.paste(arc, ((s - arc.width) // 2, (s - arc.height) // 2))
al = sq.getchannel('A').filter(ImageFilter.MaxFilter(2 * (s // 55) + 1))
ro = np.zeros((s, s, 4), np.uint8); ro[..., :3] = acc; ro[..., 3] = np.array(al)
ro = Image.fromarray(ro).resize((48, 48), Image.LANCZOS)
for n in ('ro', 'fedora', 'gnu-linux', 'linux'):
    ro.save(out / 'icons' / f'{n}.png')

# --- kurtarma: can simidi ---
SS = 8; M = 48 * SS; im = Image.new('RGBA', (M, M), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
c = M / 2; Ro_, Ri = 21 * SS, 14 * SS; col = (237, 238, 240, 255)
d.ellipse((c - Ro_, c - Ro_, c + Ro_, c + Ro_), fill=col)
d.ellipse((c - Ri, c - Ri, c + Ri, c + Ri), fill=(0, 0, 0, 0))
cut = Image.new('L', (M, M), 0); dc = ImageDraw.Draw(cut)
for k in range(4):
    ang = math.radians(45 + 90 * k); x, y = c + math.cos(ang) * 17.5 * SS, c + math.sin(ang) * 17.5 * SS
    dc.ellipse((x - 4 * SS, y - 4 * SS, x + 4 * SS, y + 4 * SS), fill=255)
alpha = np.array(im.getchannel('A')).astype(int); alpha[np.array(cut) > 0] = 0
im.putalpha(Image.fromarray(alpha.astype(np.uint8)))
buoy = im.resize((48, 48), Image.LANCZOS)
for n in ('recovery', 'advanced'):
    buoy.save(out / 'icons' / f'{n}.png')
print('platform/grub/ro güncellendi')
