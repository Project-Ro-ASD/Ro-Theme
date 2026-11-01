"""Tasarım token'larını yükler, şemayı doğrular ve ortak dönüşümleri sağlar.

Token'lar `core/tokens/*.json` dosyalarından gelir. Üreteçler değerlere `Tokens` üzerinden erişir;
eksik bir anahtar, hangi dosyada olduğunu söyleyen `TokenError` ile sonuçlanır.
"""
from __future__ import annotations

import json
import math
from dataclasses import dataclass
from pathlib import Path

from . import ROOT, version

THEMES = ("light", "dark")

# Şema: dosya -> zorunlu anahtarlar. Ayrıntılar: gereksinimler/02-tokens.md
COLOR_KEYS = (
    "bg", "bgAlt", "surface", "surfaceAlt", "border", "controlBorder", "text", "textSecondary",
    "accent", "accentHover", "selectionText", "link", "visited", "negative", "neutral", "positive",
)
SELECTION_KEYS = ("inactive", "link", "visited", "negative", "neutral", "positive")
FONT_ROLES = ("general", "fixed", "small", "toolbar", "menu", "windowTitle", "panelClock")
FONT_FIELDS = ("family", "pointSize", "weight", "styleName")
NUMERIC_FILES = ("radius", "spacing", "opacity", "motion")


class TokenError(ValueError):
    """Token dosyası eksik, bozuk ya da şemaya uymuyor."""


class Group(dict):
    """Anahtar yoksa dosya adını da söyleyen sözlük."""

    def __init__(self, source: str, data: dict):
        super().__init__(data)
        self.source = source

    def __missing__(self, key):
        raise TokenError(f"{self.source}: '{key}' anahtarı yok")

    def __getattr__(self, key):
        try:
            return self[key]
        except TokenError as e:
            raise AttributeError(str(e)) from None


@dataclass(frozen=True)
class Tokens:
    light: Group
    dark: Group
    radius: Group
    spacing: Group
    opacity: Group
    motion: Group
    fonts: Group
    version: str

    def colors(self, theme: str) -> Group:
        return self.light if theme == "light" else self.dark


def _read(path: Path) -> dict:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise TokenError(f"{path.name}: dosya yok") from None
    except json.JSONDecodeError as e:
        raise TokenError(f"{path.name}: geçersiz JSON ({e})") from None
    if not isinstance(data, dict):
        raise TokenError(f"{path.name}: kök bir nesne olmalı")
    return data


def _wrap(source: str, data: dict) -> Group:
    return Group(source, {k: _wrap(f"{source}.{k}", v) if isinstance(v, dict) else v for k, v in data.items()})


def is_hex(value) -> bool:
    return isinstance(value, str) and len(value) == 7 and value[0] == "#" and all(
        c in "0123456789abcdefABCDEF" for c in value[1:])


def is_number(value) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def schema_errors(t: Tokens) -> list[str]:
    """Şema hatalarının listesi (boşsa token'lar geçerli)."""
    errs = []
    for theme in THEMES:
        c = t.colors(theme)
        src = f"colors.{theme}.json"
        for k in COLOR_KEYS:
            if not is_hex(c.get(k)):
                errs.append(f"{src}: '{k}' #RRGGBB biçiminde olmalı")
        sel = c.get("selection")
        if not isinstance(sel, dict):
            errs.append(f"{src}: 'selection' nesnesi yok")
        else:
            errs += [f"{src}: 'selection.{k}' #RRGGBB olmalı" for k in SELECTION_KEYS if not is_hex(sel.get(k))]
        if "glass" in c:
            errs.append(f"{src}: 'glass' saklanmaz, üreteç hesaplar")
    if not is_hex(t.dark.get("bootBackground")):
        errs.append("colors.dark.json: 'bootBackground' #RRGGBB olmalı")
    for name in NUMERIC_FILES:
        grp = getattr(t, name)
        for k, v in grp.items():
            if name == "motion" and k == "curve":
                if not isinstance(v, str):
                    errs.append("motion.json: 'curve' metin olmalı")
            elif not is_number(v):
                errs.append(f"{name}.json: '{k}' sayı olmalı")
    for role in FONT_ROLES:
        f = t.fonts.get(role)
        if not isinstance(f, dict):
            errs.append(f"fonts.json: '{role}' yok")
            continue
        errs += [f"fonts.json: '{role}.{k}' yok" for k in FONT_FIELDS if k not in f]
    return errs


def load(root: Path = ROOT) -> Tokens:
    """Token'ları yükler ve şemayı doğrular; hata varsa TokenError fırlatır."""
    d = root / "core" / "tokens"
    t = Tokens(
        light=_wrap("colors.light.json", _read(d / "colors.light.json")),
        dark=_wrap("colors.dark.json", _read(d / "colors.dark.json")),
        radius=_wrap("radius.json", _read(d / "radius.json")),
        spacing=_wrap("spacing.json", _read(d / "spacing.json")),
        opacity=_wrap("opacity.json", _read(d / "opacity.json")),
        motion=_wrap("motion.json", _read(d / "motion.json")),
        fonts=_wrap("fonts.json", _read(d / "fonts.json")),
        version=version(root),
    )
    errs = schema_errors(t)
    if errs:
        raise TokenError("; ".join(errs))
    return t


# --- Dönüşümler (1.1.16 ile birebir uyum için kurallar: gereksinimler/02-tokens.md §2) ---

def channels(hex_color: str) -> tuple[int, int, int]:
    h = hex_color.lstrip("#")
    if len(h) != 6:
        raise TokenError(f"geçersiz renk: {hex_color}")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def rgb(hex_color: str) -> str:
    """'#213966' -> '33,57,102' (KDE renk biçimi)."""
    return ",".join(str(c) for c in channels(hex_color))


def mix(a: str, b: str, k: float) -> str:
    """a*k + b*(1-k), kanal kanal; Python round (yarımda çifte) ve büyük harf hex."""
    ca, cb = channels(a), channels(b)
    return "#" + "".join(f"{round(x * k + y * (1 - k)):02X}" for x, y in zip(ca, cb))


def num(value: float) -> str:
    """SVG sayısı: en çok 4 ondalık, sondaki sıfırlar ve nokta atılır."""
    s = f"{value:.4f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def font_string(font: dict) -> str:
    """Qt 6 QFont::toString biçiminde 19 alanlı yazı tipi dizgisi."""
    fields = [font["family"], str(font["pointSize"]), "-1", "5", str(font["weight"]),
              *["0"] * 10, "1", font["styleName"], "0", "0"]
    return ",".join(fields)
