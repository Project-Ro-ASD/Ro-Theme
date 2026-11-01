"""KWin Aurorae pencere dekorasyonu (RoLight ve RoDark) üreteci."""
from __future__ import annotations

from .. import manifest, svg
from .. import tokens as tok
from ..tokens import Group, Tokens, num

BUTTON_STATES = (
    "active-center", "hover-center", "pressed-center", "deactivated-center",
    "inactive-center", "hover-inactive-center", "pressed-inactive-center", "deactivated-inactive-center",
)

GLYPHS = {
    "close": "M 8.5,8.5 15.5,15.5 M 15.5,8.5 8.5,15.5",
    "minimize": "M 8,12.5 H 16",
    "maximize": "M 9.5,8 H 14.5 A 1.5,1.5 0 0 1 16,9.5 V 14.5 A 1.5,1.5 0 0 1 14.5,16 H 9.5 A 1.5,1.5 0 0 1 8,14.5 V 9.5 A 1.5,1.5 0 0 1 9.5,8 Z",
    "restore": "M 10,8 H 15 A 1,1 0 0 1 16,9 V 14 M 8.5,10 H 13 A 1,1 0 0 1 14,11 V 15.5 H 9.5 A 1,1 0 0 1 8.5,14.5 Z",
}


def _metadata_desktop(theme_id: str, name: str, tr_name: str, version: str) -> str:
    return "\n".join((
        "[Desktop Entry]",
        f"Name={name}",
        f"Name[tr]={tr_name}",
        "Comment=Ro Desktop window decoration",
        f"X-KDE-PluginInfo-Name={theme_id}",
        f"X-KDE-PluginInfo-Author={manifest.VENDOR}",
        f"X-KDE-PluginInfo-Version={version}",
        "X-KDE-PluginInfo-License=GPL-3.0-or-later",
    )) + "\n"


def _theme_rc(t: Tokens, c: Group) -> str:
    pad, border, btn = int(t.spacing.windowShadow), int(t.spacing.windowBorder), int(t.spacing.titleButton)
    edge = int(t.spacing.titlebarHeight - t.spacing.titleButton) // 2
    return "\n".join((
        "[General]",
        f"ActiveTextColor={tok.rgb(c.text)}",
        f"InactiveTextColor={tok.rgb(c.textSecondary)}",
        "TitleAlignment=Center",
        "TitleVerticalAlignment=Center",
        "UseTextShadow=false",
        f"Animation={int(t.motion.fastMs)}",
        "",
        "[Layout]",
        f"PaddingTop={pad}",
        f"PaddingBottom={pad}",
        f"PaddingLeft={pad}",
        f"PaddingRight={pad}",
        f"BorderLeft={border}",
        f"BorderRight={border}",
        f"BorderBottom={border}",
        f"TitleEdgeTop={edge}",
        f"TitleEdgeBottom={edge}",
        "TitleEdgeLeft=10",
        "TitleEdgeRight=10",
        f"TitleEdgeTopMaximized={edge}",
        f"TitleEdgeBottomMaximized={edge}",
        "TitleEdgeLeftMaximized=8",
        "TitleEdgeRightMaximized=8",
        "TitleBorderLeft=8",
        "TitleBorderRight=8",
        f"TitleHeight={btn}",
        f"ButtonWidth={btn}",
        f"ButtonHeight={btn}",
        "ButtonSpacing=6",
        "ButtonMarginTop=0",
        "ButtonMarginTopMaximized=0",
        "ExplicitButtonSpacer=8",
    )) + "\n"


def _normal_tile(prefix: str, x0: float, r: float, pad: float, b: float, bg: str, border: str, edge_op: float) -> list[str]:
    e, sr = svg.EDGE, pad + r
    xr, yb = x0 + sr + e, sr + e
    parts = {
        "topleft": [
            svg.rect(x0, 0, sr, sr, fill=f"url(#ro-{prefix}-topleft-shadow)"),
            svg.quadrant("topleft", x0 + sr, sr, r, fill=bg, opacity="1"),
            svg.quadrant_ring("topleft", x0 + sr, sr, r, b, fill=border, opacity=edge_op),
        ],
        "topright": [
            svg.rect(xr, 0, sr, sr, fill=f"url(#ro-{prefix}-topright-shadow)"),
            svg.quadrant("topright", xr, sr, r, fill=bg, opacity="1"),
            svg.quadrant_ring("topright", xr, sr, r, b, fill=border, opacity=edge_op),
        ],
        "bottomleft": [
            svg.rect(x0, yb, sr, sr, fill=f"url(#ro-{prefix}-bottomleft-shadow)"),
            svg.quadrant("bottomleft", x0 + sr, yb, r, fill=bg, opacity="1"),
            svg.quadrant_ring("bottomleft", x0 + sr, yb, r, b, fill=border, opacity=edge_op),
        ],
        "bottomright": [
            svg.rect(xr, yb, sr, sr, fill=f"url(#ro-{prefix}-bottomright-shadow)"),
            svg.quadrant("bottomright", xr, yb, r, fill=bg, opacity="1"),
            svg.quadrant_ring("bottomright", xr, yb, r, b, fill=border, opacity=edge_op),
        ],
        "top": [
            svg.rect(x0 + sr, 0, e, pad, fill=f"url(#ro-{prefix}-top-shadow)"),
            svg.rect(x0 + sr, pad, e, r, fill=bg, opacity="1"),
            svg.rect(x0 + sr, pad, e, b, fill=border, opacity=edge_op),
        ],
        "bottom": [
            svg.rect(x0 + sr, yb + r, e, pad, fill=f"url(#ro-{prefix}-bottom-shadow)"),
            svg.rect(x0 + sr, yb, e, r, fill=bg, opacity="1"),
            svg.rect(x0 + sr, yb + r - b, e, b, fill=border, opacity=edge_op),
        ],
        "left": [
            svg.rect(x0, sr, pad, e, fill=f"url(#ro-{prefix}-left-shadow)"),
            svg.rect(x0 + pad, sr, r, e, fill=bg, opacity="1"),
            svg.rect(x0 + pad, sr, b, e, fill=border, opacity=edge_op),
        ],
        "right": [
            svg.rect(xr + r, sr, pad, e, fill=f"url(#ro-{prefix}-right-shadow)"),
            svg.rect(xr, sr, r, e, fill=bg, opacity="1"),
            svg.rect(xr + r - b, sr, b, e, fill=border, opacity=edge_op),
        ],
        "center": [svg.rect(x0 + sr, sr, e, e, fill=bg, opacity="1")],
    }
    return [svg.group(f"{prefix}-{name}", parts[name]) for name in svg.PARTS]


def _maximized_tile(prefix: str, x0: float, bg: str) -> list[str]:
    e, mr = svg.EDGE, 4
    xr, yb = x0 + mr + e, mr + e
    coords = {
        "topleft": (x0, 0, mr, mr), "topright": (xr, 0, mr, mr),
        "bottomleft": (x0, yb, mr, mr), "bottomright": (xr, yb, mr, mr),
        "top": (x0 + mr, 0, e, mr), "bottom": (x0 + mr, yb, e, mr),
        "left": (x0, mr, mr, e), "right": (xr, mr, mr, e),
    }
    out: list[str] = []
    for name in svg.PARTS:
        if name == "center":
            out.append(svg.group(f"{prefix}-center", [svg.rect(x0 + mr, mr, e, e, fill=bg, opacity="1")]))
        else:
            px, py, pw, ph = coords[name]
            out.append(svg.group(f"{prefix}-{name}", [svg.rect(px, py, pw, ph, opacity=0), svg.rect(px, py, pw, ph, fill=bg, opacity="1")]))
    return out


def _decoration_svg(t: Tokens, c: Group) -> str:
    r, border, b, pad, alpha, e = t.radius.window, t.spacing.windowBorder, t.spacing.borderWidth, t.spacing.windowShadow, t.opacity.windowShadow, svg.EDGE
    sr = pad + r
    tile_step, max_step = 2 * sr + e + 8, 2 * 4 + e + 8
    x_act, x_inact, x_max, x_max_inact = 0, tile_step, 2 * tile_step, 2 * tile_step + max_step
    defs = [
        *svg.shadow_gradients("ro-decoration", x_act + sr, x_act + sr + e, sr, sr + e, r, pad, alpha, suffix="-shadow"),
        *svg.shadow_gradients("ro-decoration-inactive", x_inact + sr, x_inact + sr + e, sr, sr + e, r, pad, 0.6 * alpha, suffix="-shadow"),
    ]
    body = [
        *_normal_tile("decoration", x_act, r, pad, b, c.bg, c.border, 0.22),
        *_normal_tile("decoration-inactive", x_inact, r, pad, b, c.bg, c.border, 0.12),
        *_maximized_tile("decoration-maximized", x_max, c.bg),
        *_maximized_tile("decoration-maximized-inactive", x_max_inact, c.bg),
    ]
    comment = f"Ro window decoration: radius {num(r)}, border {num(border)}. Generated by scripts/generate-theme.sh."
    return svg.document(x_max_inact + max_step, 2 * sr + e, comment, body, defs=defs)


def _button_svg(t: Tokens, c: Group, kind: str) -> str:
    rx, glyph, is_close = t.radius.titleButton, GLYPHS[kind], kind == "close"
    hover_bg = c.negative if is_close else c.text
    hover_bg_op = "1" if is_close else num(t.opacity.hover)
    hover_fg = c.selectionText if is_close else c.text
    press_bg = c.negative if is_close else c.text
    press_bg_op = "0.8" if is_close else "0.24"
    press_fg = c.selectionText if is_close else c.text
    state_styles = {
        "active-center": (c.text, "0", c.textSecondary, "1"),
        "hover-center": (hover_bg, hover_bg_op, hover_fg, "1"),
        "pressed-center": (press_bg, press_bg_op, press_fg, "1"),
        "deactivated-center": (c.text, "0", c.textSecondary, "0.35"),
        "inactive-center": (c.text, "0", c.textSecondary, "1"),
        "hover-inactive-center": (hover_bg, hover_bg_op, hover_fg, "1"),
        "pressed-inactive-center": (press_bg, press_bg_op, press_fg, "1"),
        "deactivated-inactive-center": (c.text, "0", c.textSecondary, "0.25"),
    }
    body = [
        svg.group(
            state,
            [
                svg.rect(None, None, 24, 24, opacity=0),
                svg.rect(1, 1, 22, 22, rx=rx, fill=bg_col, opacity=bg_op),
                f'    <path d="{glyph}" fill="none" stroke="{fg_col}" stroke-opacity="{fg_op}" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>',
            ],
            transform=f"translate({idx * 28},0)",
        )
        for idx, (state, (bg_col, bg_op, fg_col, fg_op)) in enumerate((s, state_styles[s]) for s in BUTTON_STATES)
    ]
    return svg.document(224, 24, f"Ro window button: {kind}. Generated by scripts/generate-theme.sh.", body)


def outputs(ctx) -> dict[str, str | bytes]:
    """RoLight ve RoDark için 7'şer Aurorae pencere dekorasyonu dosyasını üretir."""
    t = ctx.tokens
    if t.spacing.windowBorder < 0.3 * t.radius.window:
        raise tok.TokenError(f"spacing.json: windowBorder ({t.spacing.windowBorder}) >= 0.3 * radius.window ({t.radius.window}) olmalı")
    out: dict[str, str | bytes] = {}
    for theme, (theme_id, _, name, tr_name) in manifest.THEMES.items():
        c = t.colors(theme)
        base = f"platform/kwin/aurorae/{theme_id}"
        out[f"{base}/metadata.desktop"] = _metadata_desktop(theme_id, name, tr_name, ctx.version)
        out[f"{base}/{theme_id}rc"] = _theme_rc(t, c)
        out[f"{base}/decoration.svg"] = _decoration_svg(t, c)
        for kind in ("close", "minimize", "maximize", "restore"):
            out[f"{base}/{kind}.svg"] = _button_svg(t, c, kind)
    return out
