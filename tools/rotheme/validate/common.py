"""Denetimlerin ortak yardımcıları: dosya ayrıştırma, SVG sorguları ve renk matematiği."""
from __future__ import annotations

import colorsys
import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path

from ..kconfig import KConfig

HEX = re.compile(r"^#[0-9A-Fa-f]{6}$")
ARC = re.compile(r"[Aa]\s*(-?[0-9.]+)")


def read_text(path: Path) -> tuple[str | None, str | None]:
    try:
        return path.read_text(encoding="utf-8"), None
    except OSError as e:
        return None, f"{path}: okunamadı ({e})"


def read_json(path: Path):
    text, err = read_text(path)
    if err:
        return None, err
    try:
        return json.loads(text), None
    except json.JSONDecodeError as e:
        return None, f"{path}: geçersiz JSON ({e})"


def read_kconfig(path: Path):
    text, err = read_text(path)
    if err:
        return None, err
    return KConfig.parse(text), None


def read_svg(path: Path):
    text, err = read_text(path)
    if err:
        return None, err
    try:
        return ET.fromstring(text), None
    except ET.ParseError as e:
        return None, f"{path}: geçersiz XML ({e})"


def local(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def ids(root: ET.Element) -> set[str]:
    return {el.get("id") for el in root.iter() if el.get("id")}


def by_id(root: ET.Element, element_id: str) -> ET.Element | None:
    for el in root.iter():
        if el.get("id") == element_id:
            return el
    return None


def has_stroke(root: ET.Element) -> bool:
    return any(local(el.tag) == "stroke" or "stroke" in el.attrib for el in root.iter())


def has_hex_fill(root: ET.Element) -> bool:
    return any(HEX.match(el.get("fill", "")) is not None for el in root.iter())


def arc_radii(root: ET.Element, element_id: str) -> list[float]:
    group = by_id(root, element_id)
    if group is None:
        return []
    values = []
    for el in group.iter():
        if local(el.tag) == "path":
            match = ARC.search(el.get("d", ""))
            if match:
                values.append(float(match.group(1)))
    return values


def number_attr(root: ET.Element, element_id: str, name: str) -> float | None:
    el = by_id(root, element_id)
    if el is None or el.get(name) is None:
        return None
    try:
        return float(el.get(name))
    except ValueError:
        return None


def child_shapes(group: ET.Element) -> list[ET.Element]:
    return [el for el in group.iter() if el is not group and local(el.tag) in ("rect", "path")]


# --- renk matematiği (WCAG 2.x, sRGB eşiği 0.03928) ---

def channels(value: str) -> tuple[int, int, int]:
    h = value.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def parse_rgb(value: str) -> tuple[int, int, int]:
    parts = [int(p.strip()) for p in value.split(",")]
    if len(parts) != 3:
        raise ValueError(value)
    return parts[0], parts[1], parts[2]


def luminance(rgb) -> float:
    def channel(c: int) -> float:
        c = c / 255
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (channel(c) for c in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b) -> float:
    la, lb = luminance(a), luminance(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


def hue(value: str) -> float:
    r, g, b = (c / 255 for c in channels(value))
    return colorsys.rgb_to_hls(r, g, b)[0] * 360
