"""Plasma masaüstü teması (RoLight ve RoDark) 29 SVG üreteci."""
from __future__ import annotations

import math

from .. import manifest, svg
from ..tokens import Group, Tokens, num

FRAME_FILES = (
    "dialogs/background.svg",
    "translucent/dialogs/background.svg",
    "solid/dialogs/background.svg",
    "widgets/background.svg",
    "widgets/translucentbackground.svg",
    "widgets/panel-background.svg",
    "translucent/widgets/panel-background.svg",
    "solid/widgets/panel-background.svg",
    "widgets/tooltip.svg",
    "translucent/widgets/tooltip.svg",
    "solid/widgets/tooltip.svg",
)

FRAME_IDS: tuple[str, ...] = (
    *svg.PARTS,
    "hint-top-margin", "hint-bottom-margin", "hint-left-margin", "hint-right-margin", "hint-stretch-borders",
    *(f"shadow-{p}" for p in svg.PARTS if p != "center"),
    "shadow-hint-top-margin", "shadow-hint-bottom-margin", "shadow-hint-left-margin", "shadow-hint-right-margin",
)


def _prefixed_parts(prefixes: tuple[str, ...], with_hints: tuple[str, ...] = ()) -> tuple[str, ...]:
    ids: list[str] = []
    for p in prefixes:
        ids.extend(f"{p}-{part}" for part in svg.PARTS)
        if p in with_hints:
            ids.extend(f"{p}-hint-{side}-margin" for side in ("top", "bottom", "left", "right"))
    return tuple(ids)


SVG_CONTRACTS: dict[str, tuple[str, ...]] = {
    **{rel: FRAME_IDS for rel in FRAME_FILES},
    "widgets/lineedit.svg": (*_prefixed_parts(("base", "hover", "focus", "focusframe"), ("base", "hover", "focus", "focusframe")), "hint-focus-over-base", "hint-tile-center"),
    "widgets/button.svg": _prefixed_parts(
        ("normal", "hover", "pressed", "focus", "toolbutton-hover", "toolbutton-pressed", "toolbutton-focus", "mask-normal"),
        ("normal", "hover", "pressed", "focus", "toolbutton-hover", "toolbutton-pressed", "toolbutton-focus"),
    ),
    "widgets/viewitem.svg": _prefixed_parts(("normal", "hover", "selected", "selected+hover"), ("normal", "hover", "selected", "selected+hover")),
    "widgets/scrollbar.svg": (*_prefixed_parts(("slider", "mouseover-slider", "background-vertical", "background-horizontal")), "hint-scrollbar-size"),
    "widgets/checkmarks.svg": ("checkbox", "radiobutton"),
    "widgets/radiobutton.svg": ("hint-size", "normal", "shadow", "checked", "symbol", "hover", "focus"),
    "widgets/switch.svg": ("hint-bar-size", *_prefixed_parts(("inactive", "active")), "handle", "handle-hover", "handle-pressed", "handle-focus", "handle-shadow"),
    "widgets/slider.svg": (
        "hint-handle-size", *_prefixed_parts(("groove", "groove-highlight")),
        "horizontal-slider-handle", "horizontal-slider-hover", "horizontal-slider-focus", "horizontal-slider-shadow",
        "vertical-slider-handle", "vertical-slider-hover", "vertical-slider-focus", "vertical-slider-shadow",
    ),
    "widgets/plasmoidheading.svg": _prefixed_parts(("header", "footer")),
    "widgets/tabbar.svg": _prefixed_parts(
        ("north-active-tab", "south-active-tab", "west-active-tab", "east-active-tab"),
        ("north-active-tab", "south-active-tab", "west-active-tab", "east-active-tab"),
    ),
    "widgets/busywidget.svg": ("busywidget", "22-22-busywidget", "16-16-busywidget"),
    "widgets/tasks.svg": (
        *_prefixed_parts(
            tuple(f"{d}{s}" for d in ("", "north-", "west-", "east-") for s in ("normal", "focus", "hover", "minimized", "attention", "progress")),
            ("normal", "north-normal", "west-normal", "east-normal"),
        ),
        "group-expander-top", "group-expander-bottom", "group-expander-left", "group-expander-right",
    ),
    "widgets/bar_meter_horizontal.svg": ("hint-bar-size", *_prefixed_parts(("bar-inactive", "bar-active"))),
    "widgets/bar_meter_vertical.svg": ("hint-bar-size", *_prefixed_parts(("bar-inactive", "bar-active"))),
    "widgets/line.svg": ("horizontal-line", "vertical-line"),
    "widgets/frame.svg": _prefixed_parts(("plain", "raised", "sunken"), ("plain", "raised", "sunken")),
    "widgets/listitem.svg": (*_prefixed_parts(("normal", "hover", "pressed", "section"), ("normal", "hover", "pressed", "section")), "separator"),
    "widgets/arrows.svg": ("down-arrow", "left-arrow", "up-arrow", "right-arrow"),
}
manifest.SVG_CONTRACTS.update(SVG_CONTRACTS)


def _control_doc(colors: Group, r: float, rows: int, body: list[str], *, extra_tasks: bool = False) -> str:
    box = 2 * r + svg.EDGE
    comment = f"Ro control: radius {num(r)}. Generated from core/tokens by scripts/generate-theme.sh."
    return svg.document(box + 60, rows * (box + 8) + 8, comment, body, defs=svg.color_scheme_style(colors, extra_tasks=extra_tasks))


def _hint_margins(prefix: str, hx: float, y0: float, mt: float, mb: float, ml: float, mr: float) -> list[str]:
    return [
        svg.rect(hx, y0, 1, mt, id=f"{prefix}-hint-top-margin", opacity=0, indent="  "),
        svg.rect(hx + 4, y0, 1, mb, id=f"{prefix}-hint-bottom-margin", opacity=0, indent="  "),
        svg.rect(hx + 8, y0, ml, 1, id=f"{prefix}-hint-left-margin", opacity=0, indent="  "),
        svg.rect(hx + 8, y0 + 4, mr, 1, id=f"{prefix}-hint-right-margin", opacity=0, indent="  "),
    ]


def _nine_patch_state(
    prefix: str,
    y0: float,
    r: float,
    *,
    fill_cls: str | None = None,
    fill_op: float | None = None,
    overlay_cls: str | None = None,
    overlay_op: float | None = None,
    border_cls: str | None = None,
    border_op: float | None = None,
    bw: float = 1,
    margins: tuple[float, float, float, float] | None = None,
) -> list[str]:
    e = svg.EDGE
    xr, yb = r + e, y0 + r + e
    parts: dict[str, list[str]] = {name: [] for name in svg.PARTS}
    for cls, op in ((fill_cls, fill_op), (overlay_cls, overlay_op)):
        if cls is None:
            continue
        parts["topleft"].append(svg.quadrant("topleft", r, y0 + r, r, cls=cls, opacity=op))
        parts["topright"].append(svg.quadrant("topright", xr, y0 + r, r, cls=cls, opacity=op))
        parts["bottomleft"].append(svg.quadrant("bottomleft", r, yb, r, cls=cls, opacity=op))
        parts["bottomright"].append(svg.quadrant("bottomright", xr, yb, r, cls=cls, opacity=op))
        parts["top"].append(svg.rect(r, y0, e, r, cls=cls, opacity=op))
        parts["bottom"].append(svg.rect(r, yb, e, r, cls=cls, opacity=op))
        parts["left"].append(svg.rect(0, y0 + r, r, e, cls=cls, opacity=op))
        parts["right"].append(svg.rect(xr, y0 + r, r, e, cls=cls, opacity=op))
        parts["center"].append(svg.rect(r, y0 + r, e, e, cls=cls, opacity=op))
    if border_cls is not None:
        parts["topleft"].append(svg.quadrant_ring("topleft", r, y0 + r, r, bw, cls=border_cls, opacity=border_op))
        parts["topright"].append(svg.quadrant_ring("topright", xr, y0 + r, r, bw, cls=border_cls, opacity=border_op))
        parts["bottomleft"].append(svg.quadrant_ring("bottomleft", r, yb, r, bw, cls=border_cls, opacity=border_op))
        parts["bottomright"].append(svg.quadrant_ring("bottomright", xr, yb, r, bw, cls=border_cls, opacity=border_op))
        parts["top"].append(svg.rect(r, y0, e, bw, cls=border_cls, opacity=border_op))
        parts["bottom"].append(svg.rect(r, y0 + 2 * r + e - bw, e, bw, cls=border_cls, opacity=border_op))
        parts["left"].append(svg.rect(0, y0 + r, bw, e, cls=border_cls, opacity=border_op))
        parts["right"].append(svg.rect(2 * r + e - bw, y0 + r, bw, e, cls=border_cls, opacity=border_op))
    out = [svg.group(f"{prefix}-{name}", parts[name]) for name in svg.PARTS]
    if margins is not None:
        out.extend(_hint_margins(prefix, 2 * r + e + 8, y0, *margins))
    return out


def _frame_svg(fill: str, opacity: float, r: float, padding: float, shadow: float, shadow_alpha: float) -> str:
    e, op_str = svg.EDGE, str(float(opacity))
    box = 2 * r + e
    hx, sx, sy, sr = box + 8, box + 48, 48, r + shadow
    defs = svg.shadow_gradients("ro-shadow", sx + sr, sx + sr + e, sy + sr, sy + sr + e, r, shadow, shadow_alpha)
    body = [
        svg.group("topleft", [svg.quadrant("topleft", r, r, r, fill=fill, opacity=op_str)]),
        svg.group("topright", [svg.quadrant("topright", r + e, r, r, fill=fill, opacity=op_str)]),
        svg.group("bottomleft", [svg.quadrant("bottomleft", r, r + e, r, fill=fill, opacity=op_str)]),
        svg.group("bottomright", [svg.quadrant("bottomright", r + e, r + e, r, fill=fill, opacity=op_str)]),
        svg.group("top", [svg.rect(r, 0, e, r, fill=fill, opacity=op_str)]),
        svg.group("bottom", [svg.rect(r, r + e, e, r, fill=fill, opacity=op_str)]),
        svg.group("left", [svg.rect(0, r, r, e, fill=fill, opacity=op_str)]),
        svg.group("right", [svg.rect(r + e, r, r, e, fill=fill, opacity=op_str)]),
        svg.group("center", [svg.rect(r, r, e, e, fill=fill, opacity=op_str)]),
        svg.rect(hx, 0, 1, padding, id="hint-top-margin", opacity=0, indent="  "),
        svg.rect(hx + 4, 0, 1, padding, id="hint-bottom-margin", opacity=0, indent="  "),
        svg.rect(hx + 8, 0, padding, 1, id="hint-left-margin", opacity=0, indent="  "),
        svg.rect(hx + 8, 4, padding, 1, id="hint-right-margin", opacity=0, indent="  "),
        svg.rect(hx, padding + 8, 1, 1, id="hint-stretch-borders", opacity=0, indent="  "),
        svg.rect(sx, sy, sr, sr, id="shadow-topleft", fill="url(#ro-shadow-topleft)", indent="  "),
        svg.rect(sx + sr + e, sy, sr, sr, id="shadow-topright", fill="url(#ro-shadow-topright)", indent="  "),
        svg.rect(sx, sy + sr + e, sr, sr, id="shadow-bottomleft", fill="url(#ro-shadow-bottomleft)", indent="  "),
        svg.rect(sx + sr + e, sy + sr + e, sr, sr, id="shadow-bottomright", fill="url(#ro-shadow-bottomright)", indent="  "),
        svg.rect(sx + sr, sy + r, e, shadow, id="shadow-top", fill="url(#ro-shadow-top)", indent="  "),
        svg.rect(sx + sr, sy + sr + e, e, shadow, id="shadow-bottom", fill="url(#ro-shadow-bottom)", indent="  "),
        svg.rect(sx + r, sy + sr, shadow, e, id="shadow-left", fill="url(#ro-shadow-left)", indent="  "),
        svg.rect(sx + sr + e, sy + sr, shadow, e, id="shadow-right", fill="url(#ro-shadow-right)", indent="  "),
        svg.rect(sx, 8, 1, shadow, id="shadow-hint-top-margin", opacity=0, indent="  "),
        svg.rect(sx + 4, 8, 1, shadow, id="shadow-hint-bottom-margin", opacity=0, indent="  "),
        svg.rect(sx + 8, 8, shadow, 1, id="shadow-hint-left-margin", opacity=0, indent="  "),
        svg.rect(sx + 8, 12, shadow, 1, id="shadow-hint-right-margin", opacity=0, indent="  "),
    ]
    comment = f"Ro surface: radius {num(r)}, padding {num(padding)}. Generated from core/tokens by scripts/generate-theme.sh."
    return svg.document(sx + 2 * sr + e + 8, sy + 2 * sr + e + 8, comment, body, defs=defs)


def _lineedit_svg(t: Tokens, c: Group) -> str:
    r, b = t.radius.sm, t.spacing.borderWidth
    step, fp, hp = 2 * r + svg.EDGE + 8, t.spacing.fieldPadding, t.spacing.sm + t.spacing.xs
    body = [
        *_nine_patch_state("base", 0, r, fill_cls="ViewBackground", fill_op=1, border_cls="Text", border_op=0.5, bw=b, margins=(fp, fp, hp, hp)),
        *_nine_patch_state("hover", step, r, fill_cls="ViewBackground", fill_op=0, border_cls="Text", border_op=0.7, bw=b, margins=(0.001, 0.001, 0.001, 0.001)),
        *_nine_patch_state("focus", 2 * step, r, fill_cls="ViewBackground", fill_op=0, border_cls="ViewFocus", border_op=1, bw=b, margins=(0.001, 0.001, 0.001, 0.001)),
        *_nine_patch_state("focusframe", 3 * step, r, fill_cls="ViewBackground", fill_op=0, border_cls="ViewFocus", border_op=1, bw=2 * b, margins=(2 * b, 2 * b, 2 * b, 2 * b)),
        svg.rect(0, 0, 1, 1, id="hint-focus-over-base", opacity=0, indent="  "),
        svg.rect(0, 0, 1, 1, id="hint-tile-center", opacity=0, indent="  "),
    ]
    return _control_doc(c, r, 4, body)


def _button_svg(t: Tokens, c: Group) -> str:
    r, b = t.radius.sm, t.spacing.borderWidth
    step = 2 * r + svg.EDGE + 8
    m = (t.spacing.xs, t.spacing.xs, t.spacing.sm + t.spacing.xs, t.spacing.sm + t.spacing.xs)
    body = [
        *_nine_patch_state("normal", 0, r, fill_cls="ButtonBackground", fill_op=1, border_cls="ButtonText", border_op=t.opacity.buttonEdge, bw=b, margins=m),
        *_nine_patch_state("hover", step, r, fill_cls="ButtonBackground", fill_op=1, overlay_cls="ButtonText", overlay_op=t.opacity.hover, margins=m),
        *_nine_patch_state("pressed", 2 * step, r, fill_cls="ButtonBackground", fill_op=1, overlay_cls="ButtonText", overlay_op=t.opacity.mixPressed, margins=m),
        *_nine_patch_state("focus", 3 * step, r, fill_cls="ButtonBackground", fill_op=1, border_cls="ButtonFocus", border_op=1, bw=2 * b, margins=m),
        *_nine_patch_state("toolbutton-hover", 4 * step, r, fill_cls="ButtonText", fill_op=t.opacity.hover, margins=m),
        *_nine_patch_state("toolbutton-pressed", 5 * step, r, fill_cls="ButtonText", fill_op=t.opacity.mixPressed, margins=m),
        *_nine_patch_state("toolbutton-focus", 6 * step, r, border_cls="ButtonFocus", border_op=1, bw=2 * b, margins=m),
        *_nine_patch_state("mask-normal", 7 * step, r, fill_cls="ButtonBackground", fill_op=1, margins=(0, 0, 0, 0)),
    ]
    return _control_doc(c, r, 8, body)


def _viewitem_svg(t: Tokens, c: Group) -> str:
    r = t.radius.sm
    step, m = 2 * r + svg.EDGE + 8, (t.spacing.xs, t.spacing.xs, t.spacing.sm, t.spacing.sm)
    states = (("normal", 0.0), ("hover", t.opacity.listCurrent), ("selected", t.opacity.listSelected), ("selected+hover", t.opacity.listSelectedHover))
    body = [line for idx, (p, op) in enumerate(states) for line in _nine_patch_state(p, idx * step, r, fill_cls="Highlight", fill_op=op, margins=m)]
    return _control_doc(c, r, 4, body)


def _scrollbar_svg(t: Tokens, c: Group, theme: str) -> str:
    w = t.spacing.scrollbarWidth
    r, hr = w / 2, t.spacing.scrollbarHandle / 2
    inset, e = r - hr, svg.EDGE
    step = 2 * r + e + 8
    slider_op = t.opacity.scrollbarLight if theme == "light" else t.opacity.scrollbarDark
    hover_op = t.opacity.scrollbarHoverLight if theme == "light" else t.opacity.scrollbarHoverDark
    states = (("slider", "Highlight", slider_op), ("mouseover-slider", "Highlight", hover_op), ("background-vertical", "Text", t.opacity.scrollbarGroove), ("background-horizontal", "Text", t.opacity.scrollbarGroove))
    body: list[str] = []
    for idx, (prefix, cls, op) in enumerate(states):
        y0, xr, yb = idx * step, r + e, idx * step + r + e
        parts = {
            "topleft": [svg.rect(0, y0, r, r, cls="Text", opacity=0), svg.quadrant("topleft", r, y0 + r, hr, cls=cls, opacity=op)],
            "topright": [svg.rect(xr, y0, r, r, cls="Text", opacity=0), svg.quadrant("topright", xr, y0 + r, hr, cls=cls, opacity=op)],
            "bottomleft": [svg.rect(0, yb, r, r, cls="Text", opacity=0), svg.quadrant("bottomleft", r, yb, hr, cls=cls, opacity=op)],
            "bottomright": [svg.rect(xr, yb, r, r, cls="Text", opacity=0), svg.quadrant("bottomright", xr, yb, hr, cls=cls, opacity=op)],
            "left": [svg.rect(0, y0 + r, r, e, cls="Text", opacity=0), svg.rect(inset, y0 + r, hr, e, cls=cls, opacity=op)],
            "right": [svg.rect(xr, y0 + r, r, e, cls="Text", opacity=0), svg.rect(xr, y0 + r, hr, e, cls=cls, opacity=op)],
            "top": [svg.rect(r, y0, e, r, cls="Text", opacity=0), svg.rect(r, y0 + inset, e, hr, cls=cls, opacity=op)],
            "bottom": [svg.rect(r, yb, e, r, cls="Text", opacity=0), svg.rect(r, yb, e, hr, cls=cls, opacity=op)],
            "center": [svg.rect(r, y0 + r, e, e, cls="Text", opacity=0), svg.rect(r, y0 + r, e, e, cls=cls, opacity=op)],
        }
        body.extend(svg.group(f"{prefix}-{name}", parts[name]) for name in svg.SCROLLBAR_PARTS)
    body.append(svg.rect(2 * r + e + 20, 0, w, w, id="hint-scrollbar-size", opacity=0, indent="  "))
    return _control_doc(c, r, 4, body)


def _checkmarks_svg(t: Tokens, c: Group) -> str:
    s = t.spacing.indicatorSize
    r, th, rx0 = s / 2, 2 * t.spacing.borderWidth, s + 8
    body = [
        svg.group("checkbox", [
            svg.rect(0, 0, s, s, opacity=0),
            svg.circle(r, r, r, cls="Highlight"),
            svg.pill_segment(0.2875 * s, 0.525 * s, 0.4375 * s, 0.675 * s, th, cls="ViewBackground"),
            svg.pill_segment(0.4375 * s, 0.675 * s, 0.725 * s, 0.3375 * s, th, cls="ViewBackground"),
        ]),
        svg.group("radiobutton", [svg.rect(rx0, 0, s, s, opacity=0), svg.circle(rx0 + r, r, s / 5, cls="Highlight")]),
    ]
    return _control_doc(c, r, 1, body)


def _radiobutton_svg(t: Tokens, c: Group) -> str:
    s, b = t.spacing.indicatorSize, t.spacing.borderWidth
    r, sr, fr, fb = s / 2, 3 * s / 16, (s + 6 * b) / 2, 2 * b
    sd, fd = 2 * sr, 2 * fr
    body = [
        svg.circle(r, r, r, id="hint-size", opacity=0, indent="  "),
        svg.group("normal", [svg.rect(30, 0, s, s, opacity=0), svg.circle(30 + r, r, r, cls="ViewBackground"), svg.ring(30 + r, r, r, b, cls="Text", opacity=t.opacity.indicatorEdge)]),
        svg.group("shadow", [svg.rect(60, 0, s, s, opacity=0)]),
        svg.group("checked", [svg.rect(90, 0, s, s, opacity=0), svg.circle(90 + r, r, r, cls="Highlight")]),
        svg.group("symbol", [svg.rect(120, 0, sd, sd, opacity=0), svg.circle(120 + sr, sr, sr, cls="ViewBackground")]),
        svg.group("hover", [svg.rect(150, 0, s, s, opacity=0), svg.ring(150 + r, r, r, b, cls="Highlight")]),
        svg.group("focus", [svg.rect(180, 0, fd, fd, opacity=0), svg.ring(180 + fr, fr, fr, fb, cls="Highlight")]),
    ]
    return _control_doc(c, r, 2, body)


def _switch_svg(t: Tokens, c: Group) -> str:
    w, h, kr, b = t.spacing.switchWidth, t.spacing.switchHeight, t.spacing.switchKnob / 2, t.spacing.borderWidth
    r = h / 2
    step, fr, fb = 2 * r + svg.EDGE + 8, r + 3 * b, 2 * b
    fd, hx = 2 * fr, 2 * r + svg.EDGE + 40
    kx, ks = hx + w + 8, h + 8
    fx = kx + 3 * ks
    body = [
        *_nine_patch_state("inactive", 0, r, fill_cls="Text", fill_op=t.opacity.switchTrackOff, margins=(0, 0, 0, 0)),
        *_nine_patch_state("active", step, r, fill_cls="Highlight", fill_op=1, margins=(0, 0, 0, 0)),
        svg.rect(hx, 0, w, h, id="hint-bar-size", opacity=0, indent="  "),
        svg.group("handle", [svg.rect(kx, 0, h, h, opacity=0), svg.circle(kx + r, r, kr, cls="ViewBackground")]),
        svg.group("handle-hover", [svg.rect(kx + ks, 0, h, h, opacity=0), svg.circle(kx + ks + r, r, kr, cls="ViewBackground"), svg.ring(kx + ks + r, r, kr, b, cls="Highlight")]),
        svg.group("handle-pressed", [svg.rect(kx + 2 * ks, 0, h, h, opacity=0), svg.circle(kx + 2 * ks + r, r, kr, cls="ViewBackground"), svg.circle(kx + 2 * ks + r, r, kr, cls="Text", opacity=t.opacity.mixPressed)]),
        svg.group("handle-focus", [svg.rect(fx, 0, fd, fd, opacity=0), svg.ring(fx + fr, fr, fr, fb, cls="Highlight")]),
        svg.group("handle-shadow", [svg.rect(fx + fd + 8, 0, h, h, opacity=0)]),
    ]
    return _control_doc(c, r, 3, body)


def _slider_svg(t: Tokens, c: Group) -> str:
    gr, s, b = t.spacing.sliderGroove / 2, t.spacing.sliderHandle, t.spacing.borderWidth
    hr = s / 2
    step, fr, fb = 2 * gr + svg.EDGE + 8, hr + 3 * b, 2 * b
    fd, hx = 2 * fr, 2 * gr + svg.EDGE + 40
    body = [
        *_nine_patch_state("groove", 0, gr, fill_cls="Text", fill_op=t.opacity.sliderGroove, margins=(0, 0, 0, 0)),
        *_nine_patch_state("groove-highlight", step, gr, fill_cls="Highlight", fill_op=1, margins=(0, 0, 0, 0)),
        svg.rect(hx, 0, s, s, id="hint-handle-size", opacity=0, indent="  "),
    ]
    x = hx + s + 8
    for prefix in ("horizontal-slider", "vertical-slider"):
        body.append(svg.group(f"{prefix}-handle", [svg.rect(x, 0, s, s, opacity=0), svg.circle(x + hr, hr, hr, cls="Highlight")]))
        x += s + 8
        body.append(svg.group(f"{prefix}-hover", [svg.rect(x, 0, s, s, opacity=0), svg.circle(x + hr, hr, hr, cls="Highlight"), svg.circle(x + hr, hr, hr, cls="Text", opacity=t.opacity.sliderHover)]))
        x += s + 8
        body.append(svg.group(f"{prefix}-focus", [svg.rect(x, 0, fd, fd, opacity=0), svg.ring(x + fr, fr, fr, fb, cls="Highlight")]))
        x += fd + 8
        body.append(svg.group(f"{prefix}-shadow", [svg.rect(x, 0, s, s, opacity=0)]))
        x += s + 8
    return _control_doc(c, gr, 2, body)


def _plasmoidheading_svg(t: Tokens, c: Group) -> str:
    r, b, op, e = t.spacing.xs, t.spacing.borderWidth, t.opacity.separator, svg.EDGE
    step = 2 * r + e + 8
    body: list[str] = []
    for idx, (prefix, is_header) in enumerate((("header", True), ("footer", False))):
        y0 = idx * step
        coords = {
            "topleft": (0, y0, r, r), "top": (r, y0, e, r), "topright": (r + e, y0, r, r),
            "left": (0, y0 + r, r, e), "center": (r, y0 + r, e, e), "right": (r + e, y0 + r, r, e),
            "bottomleft": (0, y0 + r + e, r, r), "bottom": (r, y0 + r + e, e, r), "bottomright": (r + e, y0 + r + e, r, r),
        }
        line_parts = ("bottomleft", "bottom", "bottomright") if is_header else ("topleft", "top", "topright")
        line_y = (y0 + 2 * r + e - b) if is_header else y0
        for name in svg.GRID_PARTS:
            px, py, pw, ph = coords[name]
            ch = [svg.rect(px, py, pw, ph, opacity=0)]
            if name in line_parts:
                ch.append(svg.rect(px, line_y, pw, b, cls="Text", opacity=op))
            body.append(svg.group(f"{prefix}-{name}", ch))
    return _control_doc(c, r, 2, body)


def _tabbar_svg(t: Tokens, c: Group) -> str:
    r, b, tl, op, e = t.radius.md, t.spacing.borderWidth, t.spacing.tabLine, t.opacity.tabActive, svg.EDGE
    inset, lr = 2 * b, tl / 2
    m, hx = (t.spacing.sm, t.spacing.sm, t.spacing.md, t.spacing.md), 2 * r + e + 8
    cx_l = (r - 2) + lr
    stub_w = r - cx_l
    cx_r = r + e + stub_w
    y0, ly = 0, 2 * r + e - 3 - tl
    body = [
        svg.group("north-active-tab-topleft", [svg.quadrant("topleft", r, y0 + r, r, cls="Highlight", opacity=op)]),
        svg.group("north-active-tab-topright", [svg.quadrant("topright", r + e, y0 + r, r, cls="Highlight", opacity=op)]),
        svg.group("north-active-tab-bottomleft", [
            svg.quadrant("bottomleft", r, y0 + r + e, r, cls="Highlight", opacity=op),
            svg.rect(0, y0 + 2 * r + e, r, inset, opacity=0),
            svg.path(f"M {num(cx_l)},{num(ly)} A {num(lr)},{num(lr)} 0 0 0 {num(cx_l)},{num(ly + tl)} Z", cls="Highlight"),
            svg.rect(cx_l, ly, stub_w, tl, cls="Highlight"),
        ]),
        svg.group("north-active-tab-bottomright", [
            svg.quadrant("bottomright", r + e, y0 + r + e, r, cls="Highlight", opacity=op),
            svg.rect(r + e, y0 + 2 * r + e, r, inset, opacity=0),
            svg.rect(r + e, ly, stub_w, tl, cls="Highlight"),
            svg.path(f"M {num(cx_r)},{num(ly)} A {num(lr)},{num(lr)} 0 0 1 {num(cx_r)},{num(ly + tl)} Z", cls="Highlight"),
        ]),
        svg.group("north-active-tab-top", [svg.rect(r, y0, e, r, cls="Highlight", opacity=op)]),
        svg.group("north-active-tab-bottom", [
            svg.rect(r, y0 + r + e, e, r, cls="Highlight", opacity=op),
            svg.rect(r, y0 + 2 * r + e, e, inset, opacity=0),
            svg.rect(r, ly, e, tl, cls="Highlight"),
        ]),
        svg.group("north-active-tab-left", [svg.rect(0, y0 + r, r, e, cls="Highlight", opacity=op)]),
        svg.group("north-active-tab-right", [svg.rect(r + e, y0 + r, r, e, cls="Highlight", opacity=op)]),
        svg.group("north-active-tab-center", [svg.rect(r, y0 + r, e, e, cls="Highlight", opacity=op)]),
        *_hint_margins("north-active-tab", hx, y0, *m),
    ]
    y0 = 2 * r + e + inset + 8
    by, ly = y0 + inset, y0 + inset + 3
    body.extend([
        svg.group("south-active-tab-topleft", [
            svg.rect(0, y0, r, inset, opacity=0),
            svg.quadrant("topleft", r, by + r, r, cls="Highlight", opacity=op),
            svg.path(f"M {num(cx_l)},{num(ly)} A {num(lr)},{num(lr)} 0 0 0 {num(cx_l)},{num(ly + tl)} Z", cls="Highlight"),
            svg.rect(cx_l, ly, stub_w, tl, cls="Highlight"),
        ]),
        svg.group("south-active-tab-topright", [
            svg.rect(r + e, y0, r, inset, opacity=0),
            svg.quadrant("topright", r + e, by + r, r, cls="Highlight", opacity=op),
            svg.rect(r + e, ly, stub_w, tl, cls="Highlight"),
            svg.path(f"M {num(cx_r)},{num(ly)} A {num(lr)},{num(lr)} 0 0 1 {num(cx_r)},{num(ly + tl)} Z", cls="Highlight"),
        ]),
        svg.group("south-active-tab-bottomleft", [svg.quadrant("bottomleft", r, by + r + e, r, cls="Highlight", opacity=op)]),
        svg.group("south-active-tab-bottomright", [svg.quadrant("bottomright", r + e, by + r + e, r, cls="Highlight", opacity=op)]),
        svg.group("south-active-tab-top", [
            svg.rect(r, y0, e, inset, opacity=0),
            svg.rect(r, by, e, r, cls="Highlight", opacity=op),
            svg.rect(r, ly, e, tl, cls="Highlight"),
        ]),
        svg.group("south-active-tab-bottom", [svg.rect(r, by + r + e, e, r, cls="Highlight", opacity=op)]),
        svg.group("south-active-tab-left", [svg.rect(0, by + r, r, e, cls="Highlight", opacity=op)]),
        svg.group("south-active-tab-right", [svg.rect(r + e, by + r, r, e, cls="Highlight", opacity=op)]),
        svg.group("south-active-tab-center", [svg.rect(r, by + r, e, e, cls="Highlight", opacity=op)]),
        *_hint_margins("south-active-tab", hx, y0, *m),
    ])
    y_west = y0 + 2 * r + e + inset + 8
    body.extend(_nine_patch_state("west-active-tab", y_west, r, fill_cls="Highlight", fill_op=op, margins=m))
    body.extend(_nine_patch_state("east-active-tab", y_west + 2 * r + e + 8, r, fill_cls="Highlight", fill_op=op, margins=m))
    return _control_doc(c, r, 4, body)


def _busy_arc_d(x0: float, size: float, arc: float, sweep_deg: float) -> str:
    cx, cy, ro = x0 + size / 2, size / 2, size / 2 - 0.5
    ri, rc = ro - arc, arc / 2
    rad = math.radians(sweep_deg)
    sin_a, cos_a = math.sin(rad), math.cos(rad)
    sx_out, sy_out, sx_in, sy_in = cx, cy - ro, cx, cy - ri
    ex_out, ey_out = cx + ro * sin_a, cy - ro * cos_a
    ex_in, ey_in = cx + ri * sin_a, cy - ri * cos_a
    large = 1 if sweep_deg > 180 else 0
    return (
        f"M {num(sx_out)},{num(sy_out)} A {num(ro)},{num(ro)} 0 {large} 1 {num(ex_out)},{num(ey_out)} "
        f"A {num(rc)},{num(rc)} 0 0 1 {num(ex_in)},{num(ey_in)} A {num(ri)},{num(ri)} 0 {large} 0 {num(sx_in)},{num(sy_in)} "
        f"A {num(rc)},{num(rc)} 0 0 1 {num(sx_out)},{num(sy_out)} Z"
    )


def _busywidget_svg(t: Tokens, c: Group) -> str:
    sweep = t.spacing.busySweep
    specs = (("busywidget", 0, 32, t.spacing.busyArc), ("22-22-busywidget", 40, 22, t.spacing.busyArc22), ("16-16-busywidget", 70, 16, t.spacing.busyArc16))
    body = [svg.group(gid, [svg.rect(x0, 0, size, size, opacity=0), svg.path(_busy_arc_d(x0, size, arc, sweep), cls="Highlight")]) for gid, x0, size, arc in specs]
    return svg.document(94, 32, "Ro busy indicator. Generated from core/tokens by scripts/generate-theme.sh.", body, defs=svg.color_scheme_style(c))


def _tasks_svg(t: Tokens, c: Group) -> str:
    br, b, tl, e, m_xs = t.radius.sm, t.spacing.borderWidth, t.spacing.taskLine, svg.EDGE, t.spacing.xs
    inset = 2 * b
    r, inner = br + 2 * inset, br + inset
    step = 2 * r + e + 8
    directions = (("", "bottom"), ("north-", "top"), ("west-", "left"), ("east-", "right"))
    states = (
        ("normal", "Text", t.opacity.taskNormal, "Text", t.opacity.taskNormalLine),
        ("focus", "Highlight", t.opacity.taskFocus, "Highlight", 1.0),
        ("hover", "Highlight", t.opacity.taskHover, "Highlight", t.opacity.taskHoverLine),
        ("minimized", "Text", t.opacity.taskMinimized, "Text", t.opacity.taskMinimizedLine),
        ("attention", "NeutralText", t.opacity.taskAttention, "NeutralText", 1.0),
        ("progress", "PositiveText", t.opacity.taskProgress, None, None),
    )
    body: list[str] = []
    row = 0
    for d_prefix, side in directions:
        for s_name, fill_cls, fill_op, line_cls, line_op in states:
            prefix, y0 = f"{d_prefix}{s_name}", row * step
            row += 1
            xr, yb, y_end, x_end = r + e, y0 + r + e, y0 + 2 * r + e, 2 * r + e
            tl_d = f"M {num(r)},{num(y0 + r)} L {num(inset)},{num(y0 + r)} L {num(inset)},{num(y0 + inner)} A {num(br)},{num(br)} 0 0 1 {num(inner)},{num(y0 + inset)} L {num(r)},{num(y0 + inset)} Z"
            tr_d = f"M {num(xr)},{num(y0 + r)} L {num(x_end - inset)},{num(y0 + r)} L {num(x_end - inset)},{num(y0 + inner)} A {num(br)},{num(br)} 0 0 0 {num(xr + inset)},{num(y0 + inset)} L {num(xr)},{num(y0 + inset)} Z"
            bl_d = f"M {num(r)},{num(yb)} L {num(inset)},{num(yb)} L {num(inset)},{num(yb + inset)} A {num(br)},{num(br)} 0 0 0 {num(inner)},{num(y_end - inset)} L {num(r)},{num(y_end - inset)} Z"
            br_d = f"M {num(xr)},{num(yb)} L {num(x_end - inset)},{num(yb)} L {num(x_end - inset)},{num(yb + inset)} A {num(br)},{num(br)} 0 0 1 {num(xr + inset)},{num(y_end - inset)} L {num(xr)},{num(y_end - inset)} Z"
            parts: dict[str, list[str]] = {
                "topleft": [svg.rect(0, y0, r, r, opacity=0), svg.path(tl_d, cls=fill_cls, opacity=fill_op)],
                "top": [svg.rect(r, y0, e, r, opacity=0), svg.rect(r, y0 + inset, e, inner, cls=fill_cls, opacity=fill_op)],
                "topright": [svg.rect(xr, y0, r, r, opacity=0), svg.path(tr_d, cls=fill_cls, opacity=fill_op)],
                "left": [svg.rect(0, y0 + r, r, e, opacity=0), svg.rect(inset, y0 + r, inner, e, cls=fill_cls, opacity=fill_op)],
                "center": [svg.rect(r, y0 + r, e, e, opacity=0), svg.rect(r, y0 + r, e, e, cls=fill_cls, opacity=fill_op)],
                "right": [svg.rect(xr, y0 + r, r, e, opacity=0), svg.rect(xr, y0 + r, inner, e, cls=fill_cls, opacity=fill_op)],
                "bottomleft": [svg.rect(0, yb, r, r, opacity=0), svg.path(bl_d, cls=fill_cls, opacity=fill_op)],
                "bottom": [svg.rect(r, yb, e, r, opacity=0), svg.rect(r, yb, e, inner, cls=fill_cls, opacity=fill_op)],
                "bottomright": [svg.rect(xr, yb, r, r, opacity=0), svg.path(br_d, cls=fill_cls, opacity=fill_op)],
            }
            if line_cls is not None:
                if side == "bottom":
                    ly = y_end - inset - tl
                    parts["bottomleft"].append(svg.rect(inner, ly, inset, tl, cls=line_cls, opacity=line_op))
                    parts["bottom"].append(svg.rect(r, ly, e, tl, cls=line_cls, opacity=line_op))
                    parts["bottomright"].append(svg.rect(xr, ly, inset, tl, cls=line_cls, opacity=line_op))
                elif side == "top":
                    ly = y0 + inset
                    parts["topleft"].append(svg.rect(inner, ly, inset, tl, cls=line_cls, opacity=line_op))
                    parts["top"].append(svg.rect(r, ly, e, tl, cls=line_cls, opacity=line_op))
                    parts["topright"].append(svg.rect(xr, ly, inset, tl, cls=line_cls, opacity=line_op))
                elif side == "left":
                    parts["topleft"].append(svg.rect(inset, y0 + inner, tl, inset, cls=line_cls, opacity=line_op))
                    parts["left"].append(svg.rect(inset, y0 + r, tl, e, cls=line_cls, opacity=line_op))
                    parts["bottomleft"].append(svg.rect(inset, yb, tl, inset, cls=line_cls, opacity=line_op))
                elif side == "right":
                    lx = x_end - inset - tl
                    parts["topright"].append(svg.rect(lx, y0 + inner, tl, inset, cls=line_cls, opacity=line_op))
                    parts["right"].append(svg.rect(lx, y0 + r, tl, e, cls=line_cls, opacity=line_op))
                    parts["bottomright"].append(svg.rect(lx, yb, tl, inset, cls=line_cls, opacity=line_op))
            body.extend(svg.group(f"{prefix}-{name}", parts[name]) for name in svg.GRID_PARTS)
            if s_name == "normal":
                hx = 2 * r + e + 20
                body.extend((
                    svg.rect(hx, y0, 1, m_xs, id=f"{prefix}-hint-top-margin", opacity=0, indent="  "),
                    svg.rect(hx + 4, y0, 1, m_xs, id=f"{prefix}-hint-bottom-margin", opacity=0, indent="  "),
                    svg.rect(hx + 8, y0, m_xs, 1, id=f"{prefix}-hint-left-margin", opacity=0, indent="  "),
                    svg.rect(hx + 12, y0, m_xs, 1, id=f"{prefix}-hint-right-margin", opacity=0, indent="  "),
                ))
    for idx, d in enumerate(("top", "bottom", "left", "right")):
        gy = 24 * step + idx * 15
        body.append(svg.group(f"group-expander-{d}", [
            svg.rect(96, gy, 11, 11, opacity=0),
            svg.circle(101.5, gy + 5.5, 5.5, cls="Highlight"),
            svg.rect(100.75, gy + 2.5, 1.5, 6, cls="HighlightedText"),
            svg.rect(98.5, gy + 4.75, 6, 1.5, cls="HighlightedText"),
        ]))
    return _control_doc(c, r, 24, body, extra_tasks=True)


def _bar_meter_svg(t: Tokens, c: Group) -> str:
    h = t.spacing.progressBar
    r = h / 2
    step, hx = 2 * r + svg.EDGE + 8, 2 * r + svg.EDGE + 40
    body = [
        *_nine_patch_state("bar-inactive", 0, r, fill_cls="Text", fill_op=t.opacity.sliderGroove, margins=(0, 0, 0, 0)),
        *_nine_patch_state("bar-active", step, r, fill_cls="Highlight", fill_op=1, margins=(0, 0, 0, 0)),
        svg.rect(hx, 0, h, h, id="hint-bar-size", opacity=0, indent="  "),
    ]
    return _control_doc(c, r, 2, body)


def _line_svg(t: Tokens, c: Group) -> str:
    b, op = t.spacing.borderWidth, t.opacity.separator
    body = [
        svg.rect(0, 0, svg.EDGE, b, id="horizontal-line", cls="Text", opacity=op, indent="  "),
        svg.rect(svg.EDGE + 8, 0, b, svg.EDGE, id="vertical-line", cls="Text", opacity=op, indent="  "),
    ]
    return _control_doc(c, 16, 1, body)


def _frame_control_svg(t: Tokens, c: Group) -> str:
    r, b = t.radius.sm, t.spacing.borderWidth
    step, m = 2 * r + svg.EDGE + 8, (t.spacing.sm, t.spacing.sm, t.spacing.sm, t.spacing.sm)
    body = [
        line
        for idx, p in enumerate(("plain", "raised", "sunken"))
        for line in _nine_patch_state(p, idx * step, r, fill_cls="Text", fill_op=0, border_cls="Text", border_op=t.opacity.frameEdge, bw=b, margins=m)
    ]
    return _control_doc(c, r, 3, body)


def _listitem_svg(t: Tokens, c: Group) -> str:
    r, b = t.radius.sm, t.spacing.borderWidth
    step, m = 2 * r + svg.EDGE + 8, (t.spacing.xs, t.spacing.xs, t.spacing.sm, t.spacing.sm)
    states = (("normal", "Text", 0.0), ("hover", "Highlight", t.opacity.listCurrent), ("pressed", "Highlight", t.opacity.listSelected), ("section", "Text", t.opacity.listSection))
    body = [line for idx, (p, cls, op) in enumerate(states) for line in _nine_patch_state(p, idx * step, r, fill_cls=cls, fill_op=op, margins=m)]
    body.append(svg.rect(0, 4 * step, svg.EDGE, b, id="separator", cls="Text", opacity=t.opacity.separator, indent="  "))
    return _control_doc(c, r, 5, body)


def _arrows_svg(t: Tokens, c: Group) -> str:
    s = t.spacing.arrowSize
    r, th, arm = s / 2, 1.5 * t.spacing.borderWidth, 0.21875 * s
    y_top, y_bot = r - arm / 2, r + arm / 2
    dirs = (("down-arrow", 0), ("left-arrow", 90), ("up-arrow", 180), ("right-arrow", 270))
    body: list[str] = []
    for idx, (gid, deg) in enumerate(dirs):
        x0, cx = idx * (s + 8), idx * (s + 8) + r
        rot = f"rotate({deg} {num(cx)} {num(r)}) "
        body.append(svg.group(gid, [
            svg.rect(x0, 0, s, s, opacity=0),
            svg.pill_segment(cx - arm, y_top, cx, y_bot, th, prefix_transform=rot, cls="Text"),
            svg.pill_segment(cx, y_bot, cx + arm, y_top, th, prefix_transform=rot, cls="Text"),
        ]))
    return _control_doc(c, r, 1, body)


def _theme_svgs(t: Tokens, theme: str) -> dict[str, str]:
    c = t.colors(theme)
    glass, solid, sh_alpha = t.opacity.glass, t.opacity.get("solid", 1.0), t.opacity.popupShadow
    dialog_glass = _frame_svg(c.surface, glass, t.radius.popup, t.spacing.popupPadding, t.spacing.popupShadow, sh_alpha)
    dialog_solid = _frame_svg(c.surface, solid, t.radius.popup, t.spacing.popupPadding, t.spacing.popupShadow, sh_alpha)
    widget_glass = _frame_svg(c.surface, glass, t.radius.widget, t.spacing.popupPadding, t.spacing.popupShadow, sh_alpha)
    panel_glass = _frame_svg(c.surface, glass, t.radius.panel, t.spacing.xs, t.spacing.panelShadow, sh_alpha)
    panel_solid = _frame_svg(c.surface, solid, t.radius.panel, t.spacing.xs, t.spacing.panelShadow, sh_alpha)
    tooltip = _frame_svg(c.surfaceAlt, solid, t.radius.sm, t.spacing.sm, t.spacing.panelShadow, sh_alpha)
    bar_meter = _bar_meter_svg(t, c)
    return {
        "dialogs/background.svg": dialog_glass,
        "translucent/dialogs/background.svg": dialog_glass,
        "solid/dialogs/background.svg": dialog_solid,
        "widgets/background.svg": widget_glass,
        "widgets/translucentbackground.svg": widget_glass,
        "widgets/panel-background.svg": panel_glass,
        "translucent/widgets/panel-background.svg": panel_glass,
        "solid/widgets/panel-background.svg": panel_solid,
        "widgets/tooltip.svg": tooltip,
        "translucent/widgets/tooltip.svg": tooltip,
        "solid/widgets/tooltip.svg": tooltip,
        "widgets/lineedit.svg": _lineedit_svg(t, c),
        "widgets/button.svg": _button_svg(t, c),
        "widgets/viewitem.svg": _viewitem_svg(t, c),
        "widgets/scrollbar.svg": _scrollbar_svg(t, c, theme),
        "widgets/checkmarks.svg": _checkmarks_svg(t, c),
        "widgets/radiobutton.svg": _radiobutton_svg(t, c),
        "widgets/switch.svg": _switch_svg(t, c),
        "widgets/slider.svg": _slider_svg(t, c),
        "widgets/plasmoidheading.svg": _plasmoidheading_svg(t, c),
        "widgets/tabbar.svg": _tabbar_svg(t, c),
        "widgets/busywidget.svg": _busywidget_svg(t, c),
        "widgets/tasks.svg": _tasks_svg(t, c),
        "widgets/bar_meter_horizontal.svg": bar_meter,
        "widgets/bar_meter_vertical.svg": bar_meter,
        "widgets/line.svg": _line_svg(t, c),
        "widgets/frame.svg": _frame_control_svg(t, c),
        "widgets/listitem.svg": _listitem_svg(t, c),
        "widgets/arrows.svg": _arrows_svg(t, c),
    }


def outputs(ctx) -> dict[str, str | bytes]:
    """Her iki tema (RoLight, RoDark) için 29'ar masaüstü teması SVG dosyasını üretir."""
    out: dict[str, str | bytes] = {}
    for theme, (theme_id, _, _, _) in manifest.THEMES.items():
        base = f"platform/plasma/desktoptheme/{theme_id}"
        for rel, content in _theme_svgs(ctx.tokens, theme).items():
            out[f"{base}/{rel}"] = content
    return out
