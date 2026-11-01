"""Plasma masaüstü teması ve Aurorae pencere dekorasyonu için SVG üretim yardımcıları."""
from __future__ import annotations

import math
from typing import Iterable

from .tokens import Group, num

EDGE = 32
PARTS = ("topleft", "topright", "bottomleft", "bottomright", "top", "bottom", "left", "right", "center")
GRID_PARTS = ("topleft", "top", "topright", "left", "center", "right", "bottomleft", "bottom", "bottomright")
SCROLLBAR_PARTS = ("topleft", "topright", "bottomleft", "bottomright", "left", "right", "top", "bottom", "center")


def _paint_attrs(
    cls: str | None = None,
    fill: str | None = None,
    opacity: float | str | None = None,
    omit_one: bool = True,
) -> str:
    parts: list[str] = []
    if cls is not None:
        parts.extend((f'class="ColorScheme-{cls}"', 'fill="currentColor"'))
    elif fill is not None:
        parts.append(f'fill="{fill}"')
    if opacity is not None:
        if isinstance(opacity, str):
            parts.append(f'fill-opacity="{opacity}"')
        elif not omit_one or opacity < 1:
            parts.append(f'fill-opacity="{num(opacity)}"')
    return (" " + " ".join(parts)) if parts else ""


def rect(
    x: float | None,
    y: float | None,
    w: float,
    h: float,
    *,
    id: str | None = None,
    rx: float | None = None,
    transform: str | None = None,
    cls: str | None = None,
    fill: str | None = None,
    opacity: float | str | None = None,
    omit_one: bool = True,
    indent: str = "    ",
) -> str:
    attrs: list[str] = []
    if id is not None:
        attrs.append(f'id="{id}"')
    if x is not None:
        attrs.append(f'x="{num(x)}"')
    if y is not None:
        attrs.append(f'y="{num(y)}"')
    attrs.extend((f'width="{num(w)}"', f'height="{num(h)}"'))
    if rx is not None:
        attrs.append(f'rx="{num(rx)}"')
    if transform is not None:
        attrs.append(f'transform="{transform}"')
    return f"{indent}<rect {' '.join(attrs)}{_paint_attrs(cls, fill, opacity, omit_one)}/>"


def circle(
    cx: float,
    cy: float,
    r: float,
    *,
    id: str | None = None,
    cls: str | None = None,
    fill: str | None = None,
    opacity: float | str | None = None,
    omit_one: bool = True,
    indent: str = "    ",
) -> str:
    attrs = ([f'id="{id}"'] if id is not None else []) + [f'cx="{num(cx)}"', f'cy="{num(cy)}"', f'r="{num(r)}"']
    return f"{indent}<circle {' '.join(attrs)}{_paint_attrs(cls, fill, opacity, omit_one)}/>"


def path(
    d: str,
    *,
    rule: str | None = None,
    cls: str | None = None,
    fill: str | None = None,
    opacity: float | str | None = None,
    omit_one: bool = True,
    indent: str = "    ",
) -> str:
    rule_attr = f' fill-rule="{rule}"' if rule else ""
    return f'{indent}<path d="{d}"{rule_attr}{_paint_attrs(cls, fill, opacity, omit_one)}/>'


def quadrant(
    corner: str,
    cx: float,
    cy: float,
    r: float,
    *,
    cls: str | None = None,
    fill: str | None = None,
    opacity: float | str | None = None,
    omit_one: bool = True,
    indent: str = "    ",
) -> str:
    cxs, cys, rs = num(cx), num(cy), num(r)
    table = {
        "topleft": f"M {cxs},{cys} L {num(cx - r)},{cys} A {rs},{rs} 0 0 1 {cxs},{num(cy - r)} Z",
        "topright": f"M {cxs},{cys} L {num(cx + r)},{cys} A {rs},{rs} 0 0 0 {cxs},{num(cy - r)} Z",
        "bottomleft": f"M {cxs},{cys} L {num(cx - r)},{cys} A {rs},{rs} 0 0 0 {cxs},{num(cy + r)} Z",
        "bottomright": f"M {cxs},{cys} L {num(cx + r)},{cys} A {rs},{rs} 0 0 1 {cxs},{num(cy + r)} Z",
    }
    return path(table[corner], cls=cls, fill=fill, opacity=opacity, omit_one=omit_one, indent=indent)


def quadrant_ring(
    corner: str,
    cx: float,
    cy: float,
    r: float,
    bw: float,
    *,
    cls: str | None = None,
    fill: str | None = None,
    opacity: float | str | None = None,
    omit_one: bool = True,
    indent: str = "    ",
) -> str:
    ir = r - bw
    cxs, cys, rs, irs = num(cx), num(cy), num(r), num(ir)
    table = {
        "topleft": f"M {num(cx - r)},{cys} A {rs},{rs} 0 0 1 {cxs},{num(cy - r)} L {cxs},{num(cy - ir)} A {irs},{irs} 0 0 0 {num(cx - ir)},{cys} Z",
        "topright": f"M {num(cx + r)},{cys} A {rs},{rs} 0 0 0 {cxs},{num(cy - r)} L {cxs},{num(cy - ir)} A {irs},{irs} 0 0 1 {num(cx + ir)},{cys} Z",
        "bottomleft": f"M {num(cx - r)},{cys} A {rs},{rs} 0 0 0 {cxs},{num(cy + r)} L {cxs},{num(cy + ir)} A {irs},{irs} 0 0 1 {num(cx - ir)},{cys} Z",
        "bottomright": f"M {num(cx + r)},{cys} A {rs},{rs} 0 0 1 {cxs},{num(cy + r)} L {cxs},{num(cy + ir)} A {irs},{irs} 0 0 0 {num(cx + ir)},{cys} Z",
    }
    return path(table[corner], cls=cls, fill=fill, opacity=opacity, omit_one=omit_one, indent=indent)


def ring(
    cx: float,
    cy: float,
    r: float,
    bw: float,
    *,
    cls: str | None = None,
    fill: str | None = None,
    opacity: float | str | None = None,
    omit_one: bool = True,
    indent: str = "    ",
) -> str:
    ir = r - bw
    cys, rs, irs = num(cy), num(r), num(ir)
    ox0, ox1, ix0, ix1 = num(cx - r), num(cx + r), num(cx - ir), num(cx + ir)
    d = (
        f"M {ox0},{cys} A {rs},{rs} 0 1 0 {ox1},{cys} A {rs},{rs} 0 1 0 {ox0},{cys} Z "
        f"M {ix0},{cys} A {irs},{irs} 0 1 0 {ix1},{cys} A {irs},{irs} 0 1 0 {ix0},{cys} Z"
    )
    return path(d, rule="evenodd", cls=cls, fill=fill, opacity=opacity, omit_one=omit_one, indent=indent)


def pill_segment(
    x1: float,
    y1: float,
    x2: float,
    y2: float,
    thickness: float,
    *,
    prefix_transform: str = "",
    cls: str | None = None,
    fill: str | None = None,
    opacity: float | str | None = None,
) -> str:
    dx, dy = x2 - x1, y2 - y1
    length = math.hypot(dx, dy) + thickness
    mx, my = (x1 + x2) / 2, (y1 + y2) / 2
    angle = math.degrees(math.atan2(dy, dx))
    tr = f"{prefix_transform}translate({num(mx)} {num(my)}) rotate({num(angle)})"
    return rect(-length / 2, -thickness / 2, length, thickness, rx=thickness / 2, transform=tr, cls=cls, fill=fill, opacity=opacity)


def shadow_gradients(
    prefix: str,
    cx_left: float,
    cx_right: float,
    cy_top: float,
    cy_bottom: float,
    r: float,
    shadow: float,
    alpha: float,
    suffix: str = "",
) -> list[str]:
    sr = r + shadow
    zero_off = num(max(0.0, r / sr - 0.001))
    rad_stops = f'<stop offset="{zero_off}" stop-color="#000000" stop-opacity="0"/>' + "".join(
        f'<stop offset="{num((r + shadow * (i / 6)) / sr)}" stop-color="#000000" stop-opacity="{num(alpha * ((1 - i / 6) ** 2))}"/>'
        for i in range(7)
    )
    lin_stops = "".join(
        f'<stop offset="{num(i / 6)}" stop-color="#000000" stop-opacity="{num(alpha * ((1 - i / 6) ** 2))}"/>'
        for i in range(7)
    )
    corners = (("topleft", cx_left, cy_top), ("topright", cx_right, cy_top), ("bottomleft", cx_left, cy_bottom), ("bottomright", cx_right, cy_bottom))
    edges = (("top", "0", "1", "0", "0"), ("bottom", "0", "0", "0", "1"), ("left", "1", "0", "0", "0"), ("right", "0", "0", "1", "0"))
    lines = [
        f'    <radialGradient id="{prefix}-{name}{suffix}" gradientUnits="userSpaceOnUse" cx="{num(cx)}" cy="{num(cy)}" r="{num(sr)}">{rad_stops}</radialGradient>'
        for name, cx, cy in corners
    ]
    lines.extend(
        f'    <linearGradient id="{prefix}-{name}{suffix}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{lin_stops}</linearGradient>'
        for name, x1, y1, x2, y2 in edges
    )
    return lines


def color_scheme_style(colors: Group, extra_tasks: bool = False) -> list[str]:
    rows: list[tuple[str, str]] = []
    if extra_tasks:
        rows.extend((("HighlightedText", colors.selectionText), ("NeutralText", colors.neutral), ("PositiveText", colors.positive)))
    rows.extend((
        ("Text", colors.text),
        ("ViewBackground", colors.surface),
        ("ButtonBackground", colors.surfaceAlt),
        ("ButtonText", colors.text),
        ("ViewFocus", colors.accent),
        ("ButtonFocus", colors.accent),
        ("Highlight", colors.accent),
    ))
    return [
        "  <defs>",
        '  <style id="current-color-scheme" type="text/css">',
        *(f"    .ColorScheme-{role} {{ color:{val.lower()}; }}" for role, val in rows),
        "  </style>",
        "  </defs>",
    ]


def group(gid: str, children: Iterable[str], *, transform: str | None = None) -> str:
    tr = f' transform="{transform}"' if transform is not None else ""
    body = list(children)
    return f'  <g id="{gid}"{tr}>\n' + ("\n".join(body) + "\n" if body else "") + "  </g>"


def document(width: float, height: float, comment: str, body: Iterable[str], defs: Iterable[str] | None = None) -> str:
    w_s, h_s = num(width), num(height)
    lines = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{w_s}" height="{h_s}" viewBox="0 0 {w_s} {h_s}">', f"  <!-- {comment} -->"]
    if defs is not None:
        defs_list = list(defs)
        if defs_list and defs_list[0].lstrip().startswith("<defs>"):
            lines.extend(defs_list)
        elif defs_list:
            lines.extend(("  <defs>", *defs_list, "  </defs>"))
    lines.extend(body)
    lines.append("</svg>")
    return "\n".join(lines) + "\n"
