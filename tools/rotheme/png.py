"""Saf Python PNG yazıcı: RGBA görüntüleri zlib + struct ile kodlar.

Görüntü işleme kitaplığı kullanılmaz; Plymouth görselleri 4x4 üst örneklemeyle burada üretilir.
"""
from __future__ import annotations

import struct
import zlib

SIGNATURE = b"\x89PNG\r\n\x1a\n"


def _chunk(kind: bytes, data: bytes) -> bytes:
    return (struct.pack(">I", len(data)) + kind + data
            + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF))


def encode(width: int, height: int, pixels: list[tuple[int, int, int, int]]) -> bytes:
    """RGBA piksel listesini (satır satır) PNG baytlarına çevirir."""
    raw = bytearray()
    for y in range(height):
        raw.append(0)  # filtre: None
        for r, g, b, a in pixels[y * width:(y + 1) * width]:
            raw += bytes((r, g, b, a))
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return (SIGNATURE + _chunk(b"IHDR", ihdr)
            + _chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + _chunk(b"IEND", b""))


def raster(width: int, height: int, color: tuple[int, int, int], inside) -> bytes:
    """4x4 üst örneklemeli raster: `inside(sx, sy)` şeklin içini söyler."""
    pixels = []
    for y in range(height):
        for x in range(width):
            hits = sum(1 for i in range(4) for j in range(4)
                       if inside(x + (i + 0.5) / 4.0, y + (j + 0.5) / 4.0))
            pixels.append((*color, round(255 * hits / 16)) if hits else (0, 0, 0, 0))
    return encode(width, height, pixels)
