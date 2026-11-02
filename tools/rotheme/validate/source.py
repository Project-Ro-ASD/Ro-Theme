"""Kaynak ağacı denetimleri: belgeler, token'lar, Plasma/KWin dosyaları ve SVG sözleşmeleri."""
from __future__ import annotations

import gzip
import math
import re
import struct
import xml.etree.ElementTree as ET

from .. import manifest
from .. import tokens as tok
from ..kconfig import bare_key
from . import check, fail, ok
from .common import (ARC, arc_radii, by_id, channels, child_shapes, contrast, has_hex_fill, has_stroke,
                     hue, ids, local, number_attr, parse_rgb, read_json, read_kconfig, read_svg, read_text)

PARTS = ("topleft", "top", "topright", "left", "center", "right", "bottomleft", "bottom", "bottomright")
ROOT_FILES = ("VERSION", "README.md", "LICENSE", "packaging/ro-theme.spec", "assets/README.md",
              "docs/release-build.md", "packaging/README.md", "platform/README.md",
              "platform/plasma/README.md", "tools/README.md")
TOKEN_FILES = ("colors.light.json", "colors.dark.json", "radius.json", "spacing.json",
               "opacity.json", "motion.json", "fonts.json")


def _emit(errors, success):
    if errors:
        for error in errors:
            yield fail(error)
    else:
        yield ok(success)


def _tokens(ctx):
    if "tokens" not in ctx.cache:
        try:
            ctx.cache["tokens"] = tok.load(ctx.root)
        except tok.TokenError as e:
            ctx.cache["tokens"] = e
    value = ctx.cache["tokens"]
    if isinstance(value, Exception):
        raise value
    return value


def _json(ctx, name):
    return read_json(ctx.root / manifest.TOKEN_DIR / name)


def _color(data, *keys):
    value = data
    for key in keys:
        if not isinstance(value, dict) or key not in value:
            return None
        value = value[key]
    return value if isinstance(value, str) and re.fullmatch(r"#[0-9A-Fa-f]{6}", value) else None


def _float(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _check_ratio(errors, label, foreground, background, minimum):
    if foreground is None or background is None:
        errors.append(f"{label}: renk anahtarı yok")
        return
    ratio = contrast(channels(foreground), channels(background))
    if ratio < minimum:
        errors.append(f"{label}: kontrast {ratio:.2f} < {minimum}")


@check("VAL-PRJ-01", "project", "kök dosyaları mevcut")
def _(ctx):
    errors = [f"{rel}: dosya yok" for rel in ROOT_FILES if not (ctx.root / rel).is_file()]
    yield from _emit(errors, "kök dosyaları mevcut")


@check("VAL-PRJ-02", "project", "lisans tanımları mevcut")
def _(ctx):
    files = ("LICENSES/CC-BY-SA-4.0.txt", "LICENSES/ASSETS.md")
    errors = [f"{rel}: dosya yok" for rel in files if not (ctx.root / rel).is_file()]
    yield from _emit(errors, "lisans tanımları mevcut")


@check("VAL-TOK-01", "tokens", "belirteç JSON sözdizimi")
def _(ctx):
    errors = []
    for name in TOKEN_FILES:
        _, error = _json(ctx, name)
        if error:
            errors.append(error)
    yield from _emit(errors, "belirteç JSON dosyaları geçerli")


@check("VAL-TOK-02", "tokens", "kurumsal renk değerleri")
def _(ctx):
    data, error = _json(ctx, "colors.light.json")
    if error:
        yield fail(error)
        return
    errors = []
    for key, expected in (("navy", "#213966"), ("ink", "#2B2D2F")):
        actual = _color(data, "brand", key)
        if actual is None or actual.upper() != expected:
            errors.append(f"colors.light.json: brand.{key} {expected} olmalı (şu an {actual})")
    yield from _emit(errors, "kurumsal renkler doğru")


@check("VAL-TOK-03", "tokens", "WCAG kontrast oranları")
def _(ctx):
    errors = []
    for mode in ("light", "dark"):
        data, error = _json(ctx, f"colors.{mode}.json")
        if error:
            errors.append(error)
            continue
        for key in ("text", "textSecondary", "accent", "link", "negative", "neutral", "positive"):
            for background in ("bg", "surface"):
                _check_ratio(errors, f"{mode}: {key}/{background}",
                             _color(data, key), _color(data, background), 4.5)
        _check_ratio(errors, f"{mode}: selectionText/accent",
                     _color(data, "selectionText"), _color(data, "accent"), 4.5)
        for key in tok.SELECTION_KEYS:
            _check_ratio(errors, f"{mode}: selection.{key}/accent",
                         _color(data, "selection", key), _color(data, "accent"), 4.5)
        for background in ("bg", "surface"):
            _check_ratio(errors, f"{mode}: controlBorder/{background}",
                         _color(data, "controlBorder"), _color(data, background), 3.0)
    yield from _emit(errors, "kontrast oranları yeterli")


@check("VAL-TOK-04", "tokens", "anlamsal renk ayrışması")
def _(ctx):
    errors = []
    keys = ("negative", "neutral", "positive", "link", "visited", "text")
    for mode in ("light", "dark"):
        data, error = _json(ctx, f"colors.{mode}.json")
        if error:
            errors.append(error)
            continue
        values = [(_color(data, key) or "").upper() for key in keys]
        if len(set(values)) != len(values):
            errors.append(f"colors.{mode}.json: {', '.join(keys)} birbirinden farklı olmalı")
    yield from _emit(errors, "anlamsal renkler ayrışık")


@check("VAL-TOK-05", "tokens", "vurgu rengi ton açısı")
def _(ctx):
    errors = []
    for mode in ("light", "dark"):
        data, error = _json(ctx, f"colors.{mode}.json")
        if error:
            errors.append(error)
            continue
        accent = _color(data, "accent")
        if accent is None:
            errors.append(f"colors.{mode}.json: accent yok")
            continue
        value = hue(accent)
        if not 213 <= value <= 225:
            errors.append(f"colors.{mode}.json: accent tonu {value:.1f}° (213-225 olmalı)")
    yield from _emit(errors, "vurgu tonu aralıkta")


@check("VAL-TOK-06", "tokens", "nötr gri yüzey dengesi")
def _(ctx):
    errors = []
    for mode in ("light", "dark"):
        data, error = _json(ctx, f"colors.{mode}.json")
        if error:
            errors.append(error)
            continue
        for key in ("bg", "surface", "surfaceAlt", "border"):
            value = _color(data, key)
            if value is None:
                errors.append(f"colors.{mode}.json: {key} yok")
                continue
            spread = max(channels(value)) - min(channels(value))
            if spread > 12:
                errors.append(f"colors.{mode}.json: {key} kanal farkı {spread} > 12")
    yield from _emit(errors, "yüzeyler nötr gri")


@check("VAL-TOK-07", "tokens", "eski belirteçlerin temizliği")
def _(ctx):
    errors = []
    if (ctx.root / manifest.TOKEN_DIR / "palettes").exists():
        errors.append("core/tokens/palettes dizini kaldırılmalı")
    legacy = {"radius.json": ("dock",),
              "spacing.json": ("dockHeight", "dockIconSize", "shadowSize"),
              "opacity.json": ("shadow",)}
    for name, keys in legacy.items():
        data, error = _json(ctx, name)
        if error:
            errors.append(error)
            continue
        errors += [f"{name}: eski '{key}' anahtarı kaldırılmalı" for key in keys if key in data]
    yield from _emit(errors, "eski belirteç yok")


@check("VAL-TOK-08", "tokens", "geometri ve sınır ilişkileri")
def _(ctx):
    errors = []
    data = {}
    for name in ("radius.json", "spacing.json", "opacity.json"):
        data[name], error = _json(ctx, name)
        if error:
            errors.append(error)
    if errors:
        yield from _emit(errors, "geometri kuralları sağlanıyor")
        return

    required = {
        "radius.json": ("sm", "popup", "md", "window", "widget", "panel"),
        "spacing.json": ("popupPadding", "windowBorder", "borderWidth", "panelHeight"),
        "opacity.json": ("hover",),
    }
    for name, keys in required.items():
        for key in keys:
            value = data[name].get(key)
            if not tok.is_number(value) or value <= 0:
                errors.append(f"{name}: '{key}' pozitif sonlu sayı olmalı")

    radius, spacing, opacity = data["radius.json"], data["spacing.json"], data["opacity.json"]
    if not errors:
        upper = radius["popup"] - spacing["popupPadding"] / 2
        for key in ("sm", "md"):
            if not radius["sm"] <= radius[key] <= upper:
                errors.append(f"radius.{key} [{radius['sm']}, {upper}] aralığında olmalı")
        if spacing["popupPadding"] < 0.3 * radius["popup"]:
            errors.append("spacing.popupPadding >= 0.3 * radius.popup olmalı")
        if spacing["windowBorder"] < 0.3 * radius["window"]:
            errors.append("spacing.windowBorder >= 0.3 * radius.window olmalı")
        if spacing["borderWidth"] >= min(radius["popup"], radius["widget"], radius["panel"], radius["window"]):
            errors.append("spacing.borderWidth tüm köşe yarıçaplarından küçük olmalı")
        if not 0.08 <= opacity["hover"] <= 0.14:
            errors.append("opacity.hover [0.08, 0.14] aralığında olmalı")
    yield from _emit(errors, "geometri kuralları sağlanıyor")


@check("VAL-DST-01", "dist", "QML singleton doğrulaması")
def _(ctx):
    text, error = read_text(ctx.root / "dist/qml/RoTokens.qml")
    if error:
        yield fail(error)
        return
    errors = []
    if not re.search(r"^\s*pragma\s+Singleton\b", text, re.M):
        errors.append("RoTokens.qml: 'pragma Singleton' yok")
    if not re.search(r"^\s*import\s+QtQuick\b", text, re.M):
        errors.append("RoTokens.qml: 'import QtQuick' yok")
    if not re.search(r"\bQtObject\s*\{", text):
        errors.append("RoTokens.qml: kök eleman QtObject olmalı")
    if re.search(r"dock", text, re.I):
        errors.append("RoTokens.qml: 'dock' kelimesi geçmemeli")
    try:
        tokens = _tokens(ctx)
    except tok.TokenError as e:
        errors.append(f"belirteçler okunamadı: {e}")
        tokens = None
    if tokens is not None:
        names = [f"radius{key[0].upper()}{key[1:]}" for key in tokens.radius]
        names += [f"space{key[0].upper()}{key[1:]}" for key in ("xs", "sm", "md", "lg", "xl")]
        names += ["borderWidth", "popupPadding"]
        names += [f"opacity{key[0].upper()}{key[1:]}" for key in tokens.opacity if key != "shadow"]
        names += [f"motion{key[0].upper()}{key[1:]}" for key in tokens.motion
                  if key != "curve" and tok.is_number(tokens.motion[key])]
        for name in names:
            if not re.search(rf"readonly\s+property\s+real\s+{re.escape(name)}\b", text):
                errors.append(f"RoTokens.qml: '{name}' readonly property real olarak yok")
    yield from _emit(errors, "QML singleton geçerli")


@check("VAL-SCH-01", "plasma", "şema başlık ve dosya bütünlüğü")
def _(ctx):
    errors = []
    for mode in ("light", "dark"):
        theme = manifest.THEMES[mode][0]
        path = ctx.root / manifest.COLOR_SCHEMES / f"{theme}.colors"
        cfg, error = read_kconfig(path)
        if error:
            errors.append(error)
            continue
        if cfg.get("[General]", "ColorScheme") != theme:
            errors.append(f"{path.name}: [General] ColorScheme={theme} olmalı")
        for group, keys in cfg.groups.items():
            for key in keys:
                if bare_key(key) in ("Wallpaper", "Image"):
                    errors.append(f"{path.name}: {group} içinde {key} anahtarı olmamalı")
    yield from _emit(errors, "renk şemaları bütün")


@check("VAL-SCH-02", "plasma", "şema renk kontrastı")
def _(ctx):
    errors = []
    for mode in ("light", "dark"):
        theme = manifest.THEMES[mode][0]
        path = ctx.root / manifest.COLOR_SCHEMES / f"{theme}.colors"
        cfg, error = read_kconfig(path)
        if error:
            errors.append(error)
            continue
        for group, keys in cfg.groups.items():
            if not group.startswith("[Colors:"):
                continue
            backgrounds = []
            for name in ("BackgroundNormal", "BackgroundAlternate"):
                try:
                    backgrounds.append(parse_rgb(keys[name]))
                except (KeyError, ValueError):
                    errors.append(f"{path.name}: {group} {name} eksik/geçersiz")
            if len(backgrounds) != 2:
                continue
            for key, value in keys.items():
                if not key.startswith("Foreground"):
                    continue
                try:
                    foreground = parse_rgb(value)
                except ValueError:
                    errors.append(f"{path.name}: {group} {key} geçersiz RGB")
                    continue
                for background in backgrounds:
                    ratio = contrast(foreground, background)
                    if ratio < 4.5:
                        errors.append(f"{path.name}: {group} {key} kontrast {ratio:.2f} < 4.5")
    yield from _emit(errors, "şema kontrastları yeterli")


@check("VAL-SCH-03", "plasma", "seçim rengi değişmezliği")
def _(ctx):
    errors = []
    for mode in ("light", "dark"):
        theme = manifest.THEMES[mode][0]
        path = ctx.root / manifest.COLOR_SCHEMES / f"{theme}.colors"
        cfg, error = read_kconfig(path)
        if error:
            errors.append(error)
        elif (cfg.get("[ColorEffects:Inactive]", "ChangeSelectionColor") or "").lower() != "false":
            errors.append(f"{path.name}: ChangeSelectionColor=false olmalı")
    yield from _emit(errors, "seçim rengi sabit")


@check("VAL-SCH-04", "plasma", "alternatif satır ayrımı")
def _(ctx):
    errors = []
    for mode in ("light", "dark"):
        theme = manifest.THEMES[mode][0]
        path = ctx.root / manifest.COLOR_SCHEMES / f"{theme}.colors"
        cfg, error = read_kconfig(path)
        if error:
            errors.append(error)
            continue
        normal = cfg.get("[Colors:View]", "BackgroundNormal")
        alternate = cfg.get("[Colors:View]", "BackgroundAlternate")
        if not normal or not alternate or normal == alternate:
            errors.append(f"{path.name}: [Colors:View] alternatif satır renkleri farklı ve dolu olmalı")
    yield from _emit(errors, "alternatif satırlar ayrışık")


@check("VAL-SCH-05", "plasma", "tamamlayıcı yüzey rengi")
def _(ctx):
    path = ctx.root / manifest.COLOR_SCHEMES / "RoLight.colors"
    cfg, error = read_kconfig(path)
    if error:
        yield fail(error)
        return
    value = cfg.get("[Colors:Complementary]", "BackgroundNormal")
    try:
        actual = parse_rgb(value or "")
    except ValueError:
        actual = None
    errors = [] if actual == (43, 45, 47) else [f"{path.name}: [Colors:Complementary] BackgroundNormal 43,45,47 olmalı"]
    yield from _emit(errors, "tamamlayıcı yüzey koyu temayla aynı")


@check("VAL-DT-01", "plasma", "masaüstü teması paket metaverisi")
def _(ctx):
    errors = []
    try:
        version = (ctx.root / "VERSION").read_text(encoding="utf-8").strip()
    except OSError as e:
        yield fail(f"VERSION: okunamadı ({e})")
        return
    for mode in ("light", "dark"):
        theme = manifest.THEMES[mode][0]
        path = ctx.root / manifest.theme_dir(mode) / "metadata.json"
        data, error = read_json(path)
        if error:
            errors.append(error)
            continue
        plugin = data.get("KPlugin", {})
        if plugin.get("Id") != theme:
            errors.append(f"{path}: KPlugin.Id={theme} olmalı")
        if str(plugin.get("Version")) != version:
            errors.append(f"{path}: KPlugin.Version {version} olmalı")
        if plugin.get("License") != "GPL-3.0-or-later":
            errors.append(f"{path}: KPlugin.License GPL-3.0-or-later olmalı")
    yield from _emit(errors, "masaüstü teması metaverisi doğru")


@check("VAL-DT-02", "plasma", "masaüstü teması yapılandırma dosyaları")
def _(ctx):
    errors = []
    for mode in ("light", "dark"):
        theme = manifest.THEMES[mode][0]
        theme_path = ctx.root / manifest.theme_dir(mode)
        scheme = ctx.root / manifest.COLOR_SCHEMES / f"{theme}.colors"
        colors = theme_path / "colors"
        try:
            if scheme.read_bytes() != colors.read_bytes():
                errors.append(f"{colors}: renk şemasıyla birebir aynı olmalı")
        except OSError as e:
            errors.append(f"{colors}: okunamadı ({e})")
        cfg, error = read_kconfig(theme_path / "plasmarc")
        if error:
            errors.append(error)
            continue
        if (cfg.get("[AdaptiveTransparency]", "enabled") or "").lower() != "true":
            errors.append(f"{theme_path}/plasmarc: [AdaptiveTransparency] enabled=true olmalı")
        if (cfg.get("[ContrastEffect]", "enabled") or "").lower() != "true":
            errors.append(f"{theme_path}/plasmarc: [ContrastEffect] enabled=true olmalı")
        if "[Wallpaper]" in cfg.groups:
            errors.append(f"{theme_path}/plasmarc: [Wallpaper] grubu olmamalı")
    yield from _emit(errors, "masaüstü teması yapılandırması doğru")


@check("VAL-DT-03", "plasma", "eski uyumluluk temasının yokluğu")
def _(ctx):
    path = ctx.root / manifest.DESKTOPTHEME / "Ro"
    yield from _emit([f"{path}: eski uyumluluk teması kaldırılmalı"] if path.exists() else [],
                     "eski uyumluluk teması yok")


def _theme_svg(ctx, mode, rel):
    return read_svg(ctx.root / manifest.theme_dir(mode) / rel)


@check("VAL-SVG-01", "plasma", "SVG yüzey kuralı")
def _(ctx):
    targets = ("dialogs/background.svg", "translucent/dialogs/background.svg", "solid/dialogs/background.svg",
               "widgets/background.svg", "widgets/translucentbackground.svg", "widgets/panel-background.svg",
               "translucent/widgets/panel-background.svg", "solid/widgets/panel-background.svg")
    errors = []
    for mode in ("light", "dark"):
        for rel in targets:
            root, error = _theme_svg(ctx, mode, rel)
            if error:
                errors.append(error)
                continue
            center = by_id(root, "center")
            label = f"{manifest.theme_dir(mode)}/{rel}"
            if center is None or local(center.tag) != "g":
                errors.append(f"{label}: <g id=\"center\"> yok")
            if any(local(el.tag) == "rect" and el.get("id") == "center" for el in root.iter()):
                errors.append(f"{label}: <rect id=\"center\"> kullanılmamalı")
            if has_stroke(root):
                errors.append(f"{label}: stroke yasak")
    yield from _emit(errors, "yüzey SVG'leri kurala uygun")


@check("VAL-SVG-02", "plasma", "SVG cam saydamlığı")
def _(ctx):
    try:
        glass = float(_tokens(ctx).opacity["glass"])
    except (tok.TokenError, KeyError) as e:
        yield fail(f"opacity.glass okunamadı: {e}")
        return
    targets = ("dialogs/background.svg", "widgets/panel-background.svg", "widgets/background.svg")
    errors = []
    for mode in ("light", "dark"):
        for rel in targets:
            root, error = _theme_svg(ctx, mode, rel)
            if error:
                errors.append(error)
                continue
            center = by_id(root, "center")
            label = f"{manifest.theme_dir(mode)}/{rel}"
            values = [v for v in (_float(el.get("fill-opacity"))
                                for el in (center.iter() if center is not None else ())) if v is not None]
            if not values:
                errors.append(f"{label}: yüzey fill-opacity değeri yok")
            elif any(abs(value - glass) > 1e-9 for value in values):
                errors.append(f"{label}: yüzey fill-opacity opacity.glass ({glass}) olmalı")
    yield from _emit(errors, "cam saydamlığı doğru")


@check("VAL-SVG-03", "plasma", "SVG çerçeve kuralı (9 parça)")
def _(ctx):
    targets = ("dialogs/background.svg", "widgets/tooltip.svg", "widgets/panel-background.svg",
               "widgets/translucentbackground.svg", "widgets/background.svg")
    shadows = tuple(f"shadow-{part}" for part in PARTS if part != "center")
    errors = []
    for mode in ("light", "dark"):
        for rel in targets:
            root, error = _theme_svg(ctx, mode, rel)
            if error:
                errors.append(error)
                continue
            label = f"{manifest.theme_dir(mode)}/{rel}"
            topleft = by_id(root, "topleft")
            if topleft is None or local(topleft.tag) != "g":
                errors.append(f"{label}: <g id=\"topleft\"> yok")
            if not any(ARC.search(el.get("d", "")) for el in root.iter() if local(el.tag) == "path"):
                errors.append(f"{label}: yay komutu (A) yok")
            if by_id(root, "hint-top-margin") is None:
                errors.append(f"{label}: hint-top-margin yok")
            missing = [name for name in shadows if by_id(root, name) is None]
            if missing:
                errors.append(f"{label}: gölge parçaları eksik: {', '.join(missing)}")
            for part in PARTS:
                if part == "center":
                    continue
                group = by_id(root, part)
                if group is None:
                    errors.append(f"{label}: {part} parçası yok")
                elif len(child_shapes(group)) > 1:
                    errors.append(f"{label}: {part} en fazla bir rect/path içermeli")
    yield from _emit(errors, "çerçeve SVG'leri kurala uygun")


@check("VAL-SVG-04", "plasma", "SVG kontrol elemanları kuralı")
def _(ctx):
    targets = ("widgets/lineedit.svg", "widgets/button.svg", "widgets/viewitem.svg")
    errors = []
    for mode in ("light", "dark"):
        for rel in targets:
            root, error = _theme_svg(ctx, mode, rel)
            if error:
                errors.append(error)
                continue
            label = f"{manifest.theme_dir(mode)}/{rel}"
            if has_stroke(root):
                errors.append(f"{label}: stroke yasak")
            if has_hex_fill(root):
                errors.append(f"{label}: hex fill yasak (ColorScheme-* kullanılmalı)")
            if by_id(root, "current-color-scheme") is None:
                errors.append(f"{label}: current-color-scheme stil bloğu yok")
            found = ids(root)
            prefixes = sorted(item[:-len("-topleft")] for item in found if item.endswith("-topleft"))
            if not prefixes:
                errors.append(f"{label}: durum öneki bulunamadı")
            for prefix in prefixes:
                missing = [f"{prefix}-{part}" for part in PARTS if f"{prefix}-{part}" not in found]
                if missing:
                    errors.append(f"{label}: {prefix} için eksik parçalar: {', '.join(missing)}")
                if not prefix.startswith("mask-") and prefix != "focusframe" \
                        and f"{prefix}-hint-top-margin" not in found:
                    errors.append(f"{label}: {prefix}-hint-top-margin yok")
    yield from _emit(errors, "kontrol SVG'leri kurala uygun")


@check("VAL-SVG-05", "plasma", "metin kutusu ve buton geometri uyumu")
def _(ctx):
    try:
        spacing = _tokens(ctx).spacing
        field_padding = float(spacing["fieldPadding"])
        border = float(spacing["borderWidth"])
    except (tok.TokenError, KeyError) as e:
        yield fail(f"geometri belirteçleri okunamadı: {e}")
        return
    errors = []
    for mode in ("light", "dark"):
        lineedit, error = _theme_svg(ctx, mode, "widgets/lineedit.svg")
        if error:
            errors.append(error)
            continue
        button, error = _theme_svg(ctx, mode, "widgets/button.svg")
        if error:
            errors.append(error)
            continue
        label = manifest.theme_dir(mode)
        line_arcs = arc_radii(lineedit, "base-topleft")
        button_arcs = arc_radii(button, "normal-topleft")
        if not line_arcs or not button_arcs:
            errors.append(f"{label}: topleft yay yarıçapı okunamadı")
        elif abs(line_arcs[0] - button_arcs[0]) > 1e-9:
            errors.append(f"{label}: lineedit base-topleft ({line_arcs[0]}) != button normal-topleft ({button_arcs[0]})")
        height = number_attr(lineedit, "base-hint-top-margin", "height")
        if height is None or abs(height - field_padding) > 1e-9:
            errors.append(f"{label}: base-hint-top-margin yüksekliği spacing.fieldPadding ({field_padding}) olmalı")
        for prefix in ("hover", "focus"):
            for side in ("top", "bottom"):
                value = number_attr(lineedit, f"{prefix}-hint-{side}-margin", "height")
                if value is None or value >= 1.0:
                    errors.append(f"{label}: {prefix}-hint-{side}-margin 1.0'dan küçük olmalı")
            for side in ("left", "right"):
                value = number_attr(lineedit, f"{prefix}-hint-{side}-margin", "width")
                if value is None or value >= 1.0:
                    errors.append(f"{label}: {prefix}-hint-{side}-margin 1.0'dan küçük olmalı")
        limit = 2 * border
        for side in ("top", "bottom"):
            value = number_attr(lineedit, f"focusframe-hint-{side}-margin", "height")
            if value is None or value > limit + 1e-9:
                errors.append(f"{label}: focusframe-hint-{side}-margin <= {limit} olmalı")
        for side in ("left", "right"):
            value = number_attr(lineedit, f"focusframe-hint-{side}-margin", "width")
            if value is None or value > limit + 1e-9:
                errors.append(f"{label}: focusframe-hint-{side}-margin <= {limit} olmalı")
    yield from _emit(errors, "metin kutusu ve buton geometrisi uyumlu")


@check("VAL-SVG-06", "plasma", "kaydırma çubuğu kuralı")
def _(ctx):
    prefixes = ("slider", "mouseover-slider", "background-vertical", "background-horizontal")
    errors = []
    for mode in ("light", "dark"):
        root, error = _theme_svg(ctx, mode, "widgets/scrollbar.svg")
        if error:
            errors.append(error)
            continue
        label = f"{manifest.theme_dir(mode)}/widgets/scrollbar.svg"
        if has_stroke(root):
            errors.append(f"{label}: stroke yasak")
        if has_hex_fill(root):
            errors.append(f"{label}: hex fill yasak")
        found = ids(root)
        if "hint-scrollbar-size" not in found:
            errors.append(f"{label}: hint-scrollbar-size yok")
        for prefix in prefixes:
            missing = [f"{prefix}-{part}" for part in PARTS if f"{prefix}-{part}" not in found]
            if missing:
                errors.append(f"{label}: {prefix} eksik parçalar: {', '.join(missing)}")
    yield from _emit(errors, "kaydırma çubuğu kurala uygun")


@check("VAL-SVG-07", "plasma", "SVG kimlik sözleşmesi")
def _(ctx):
    errors = []
    for mode in ("light", "dark"):
        for rel, contract in manifest.SVG_CONTRACTS.items():
            root, error = _theme_svg(ctx, mode, rel)
            if error:
                errors.append(error)
                continue
            label = f"{manifest.theme_dir(mode)}/{rel}"
            missing = [name for name in contract if name not in ids(root)]
            if missing:
                errors.append(f"{label}: eksik kimlikler: {', '.join(missing)}")
            if rel in manifest.SVG_CONTROL_FILES:
                if has_stroke(root):
                    errors.append(f"{label}: stroke yasak")
                if has_hex_fill(root):
                    errors.append(f"{label}: hex fill yasak")
    yield from _emit(errors, "SVG kimlik sözleşmeleri eksiksiz")


@check("VAL-SVG-08", "plasma", "buton odak kafesi KSvg düzeltmesi")
def _(ctx):
    errors = []
    for mode in ("light", "dark"):
        root, error = _theme_svg(ctx, mode, "widgets/button.svg")
        if error:
            errors.append(error)
            continue
        label = f"{manifest.theme_dir(mode)}/widgets/button.svg"
        group = by_id(root, "toolbutton-focus-center")
        if group is None:
            errors.append(f"{label}: toolbutton-focus-center yok")
            continue
        transparent = any(_float(el.get("fill-opacity")) == 0
                          for el in group.iter() if el is not group)
        if not transparent:
            errors.append(f"{label}: toolbutton-focus-center saydam dolgu içermeli")
    yield from _emit(errors, "buton odak kafesi dolu")


@check("VAL-AUR-01", "aurorae", "Aurorae metaveri ve yapılandırma")
def _(ctx):
    try:
        shadow = float(_tokens(ctx).spacing["windowShadow"])
    except (tok.TokenError, KeyError) as e:
        yield fail(f"spacing.windowShadow okunamadı: {e}")
        return
    errors = []
    for mode in ("light", "dark"):
        theme = manifest.THEMES[mode][0]
        path = ctx.root / manifest.aurorae_dir(mode)
        cfg, error = read_kconfig(path / "metadata.desktop")
        if error:
            errors.append(error)
        else:
            if cfg.get("[Desktop Entry]", "X-KDE-PluginInfo-Name") != theme:
                errors.append(f"{path}/metadata.desktop: X-KDE-PluginInfo-Name={theme} olmalı")
            if not cfg.get("[Desktop Entry]", "Name[tr]"):
                errors.append(f"{path}/metadata.desktop: Name[tr] tanımlı olmalı")
        cfg, error = read_kconfig(path / f"{theme}rc")
        if error:
            errors.append(error)
            continue
        for key in ("PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight"):
            value = cfg.get("[Layout]", key)
            try:
                ok_value = float(value or "nan")
            except ValueError:
                ok_value = math.nan
            if not math.isfinite(ok_value) or abs(ok_value - shadow) > 1e-9:
                errors.append(f"{path}/{theme}rc: [Layout] {key}={shadow} olmalı")
        if "BorderLeftMaximized" in cfg.groups.get("[Layout]", {}):
            errors.append(f"{path}/{theme}rc: BorderLeftMaximized olmamalı")
    yield from _emit(errors, "Aurorae yapılandırması doğru")


@check("VAL-AUR-02", "aurorae", "Aurorae dekorasyon vektörleri")
def _(ctx):
    required = ("ro-decoration-topleft-shadow", "decoration-topleft", "decoration-inactive-topleft",
                "decoration-maximized-topleft", "decoration-maximized-inactive-topleft")
    errors = []
    for mode in ("light", "dark"):
        root, error = read_svg(ctx.root / manifest.aurorae_dir(mode) / "decoration.svg")
        if error:
            errors.append(error)
            continue
        label = f"{manifest.aurorae_dir(mode)}/decoration.svg"
        found = ids(root)
        missing = [name for name in required if name not in found]
        if missing:
            errors.append(f"{label}: eksik kimlikler: {', '.join(missing)}")
        forbidden = [name for name in found if name.startswith("ro-decoration-maximized") and "shadow" in name]
        if forbidden:
            errors.append(f"{label}: büyütülmüş gölge kimlikleri olmamalı: {', '.join(forbidden)}")
    yield from _emit(errors, "dekorasyon vektörleri doğru")


@check("VAL-AUR-03", "aurorae", "Aurorae pencere butonları")
def _(ctx):
    errors = []
    for mode in ("light", "dark"):
        path = ctx.root / manifest.aurorae_dir(mode)
        for name in ("close.svg", "minimize.svg", "maximize.svg", "restore.svg"):
            root, error = read_svg(path / name)
            if error:
                errors.append(error)
                continue
            center = by_id(root, "active-center")
            if center is None or local(center.tag) != "g":
                errors.append(f"{path}/{name}: <g id=\"active-center\"> yok")
            if name == "close.svg" and not any("rx" in el.attrib for el in root.iter()):
                errors.append(f"{path}/{name}: yuvarlatılmış kare için rx özniteliği yok")
    yield from _emit(errors, "pencere butonları doğru")


@check("VAL-GLO-01", "plasma", "global tema paket varlığı")
def _(ctx):
    required = ("metadata.json", "contents/defaults", "contents/splash/Splash.qml", "contents/splash/login.jpg",
                "contents/splash/wallpaper-blur.jpg", "contents/lockscreen/assets/login.jpg",
                "contents/previews/preview.png", "contents/previews/fullscreenpreview.jpg")
    errors = []
    for mode in ("light", "dark"):
        path = ctx.root / manifest.look_dir(mode)
        for rel in required:
            if not (path / rel).is_file():
                errors.append(f"{manifest.look_dir(mode)}/{rel}: dosya yok")
        data, error = read_json(path / "metadata.json")
        if error:
            errors.append(error)
        else:
            name = data.get("Name[tr]") or data.get("KPlugin", {}).get("Name[tr]")
            if not name:
                errors.append(f"{manifest.look_dir(mode)}/metadata.json: Name[tr] tanımlı olmalı")
        text, error = read_text(path / "contents/splash/Splash.qml")
        if error:
            errors.append(error)
        else:
            if not re.search(r"property\s+int\s+stage\b", text):
                errors.append(f"{manifest.look_dir(mode)}/contents/splash/Splash.qml: property int stage yok")
            if re.search(r"#30c7e0", text, re.I):
                errors.append(f"{manifest.look_dir(mode)}/contents/splash/Splash.qml: eski #30C7E0 rengi olmamalı")
    yield from _emit(errors, "global tema paketleri bütün")


@check("VAL-GLO-02", "plasma", "kilit ekranı güvenlik kuralı")
def _(ctx):
    errors = []
    found_any = False
    for mode in ("light", "dark"):
        path = ctx.root / manifest.look_dir(mode)
        if path.is_dir():
            found_any = True
        lock = path / "contents/lockscreen/LockScreen.qml"
        if lock.exists():
            errors.append(f"{lock}: özel kilit ekranı yasak")
    if not found_any:
        errors.append("platform/plasma/look-and-feel: global tema dizinleri yok")
    yield from _emit(errors, "özel kilit ekranı yok")


@check("VAL-GLO-03", "plasma", "global tema varsayılanları")
def _(ctx):
    errors = []
    for mode in ("light", "dark"):
        theme = manifest.THEMES[mode][0]
        path = ctx.root / manifest.look_dir(mode) / "contents/defaults"
        cfg, error = read_kconfig(path)
        if error:
            errors.append(error)
            continue
        label = f"{manifest.look_dir(mode)}/contents/defaults"
        if cfg.get("[ksplashrc][KSplash]", "Engine") != "KSplashQML":
            errors.append(f"{label}: [ksplashrc][KSplash] Engine=KSplashQML olmalı")
        if cfg.get("[ksplashrc][KSplash]", "Theme") != manifest.THEMES[mode][1]:
            errors.append(f"{label}: [ksplashrc][KSplash] Theme={manifest.THEMES[mode][1]} olmalı")
        if cfg.get("[kdeglobals][General]", "ColorScheme") != theme:
            errors.append(f"{label}: [kdeglobals][General] ColorScheme={theme} olmalı")
        if "[kdeglobals][KDE]" in cfg.groups:
            for key in ("ColorScheme", "LookAndFeelPackage"):
                if key in cfg.groups["[kdeglobals][KDE]"]:
                    errors.append(f"{label}: [kdeglobals][KDE] {key} olmamalı")
        if cfg.get("[kwinrc][org.kde.kdecoration2]", "library") != manifest.AURORAE_LIBRARY:
            errors.append(f"{label}: kwinrc library={manifest.AURORAE_LIBRARY} olmalı")
        if cfg.get("[kwinrc][org.kde.kdecoration2]", "theme") != manifest.aurorae_theme(mode):
            errors.append(f"{label}: kwinrc theme={manifest.aurorae_theme(mode)} olmalı")
        if "[kwinrc][Plugins]" in cfg.groups:
            errors.append(f"{label}: [kwinrc][Plugins] grubu olmamalı")
    yield from _emit(errors, "global tema varsayılanları doğru")


@check("VAL-GLO-04", "plasma", "panel düzen komut dosyaları")
def _(ctx):
    try:
        panel_height = float(_tokens(ctx).spacing["panelHeight"])
    except (tok.TokenError, KeyError) as e:
        yield fail(f"spacing.panelHeight okunamadı: {e}")
        return
    errors = []
    layouts = [ctx.root / manifest.look_dir(mode) / "contents/layouts/org.kde.plasma.desktop-layout.js"
               for mode in ("light", "dark")]
    template = ctx.root / manifest.LAYOUT_TEMPLATES / "org.ro.desktop/contents/layout.js"
    for path in layouts + [template]:
        text, error = read_text(path)
        if error:
            errors.append(error)
            continue
        label = str(path.relative_to(ctx.root))
        match = re.search(r"\bbar\.height\s*=\s*([0-9.]+)", text)
        if not match or abs(float(match.group(1)) - panel_height) > 1e-9:
            errors.append(f"{label}: bar.height={panel_height:g} olmalı")
        if path == template and ".remove(" in text:
            errors.append(f"{label}: panel kaldırma (.remove()) yasak")
        if "org.kde.plasma.icontasks" not in text:
            errors.append(f"{label}: org.kde.plasma.icontasks tanımı yok")
        if "reverseIconOrder" not in text:
            errors.append(f"{label}: reverseIconOrder tanımı yok")
        if "google-chrome" in text:
            errors.append(f"{label}: google-chrome referansı olmamalı")
        if re.search(r"userDataPath\s*\(\s*\)\s*\+\s*[\"']/ro-theme[\"']", text):
            errors.append(f"{label}: eski userDataPath() + \"/ro-theme\" çağrısı olmamalı")
    for path in layouts:
        text, error = read_text(path)
        if error:
            continue
        label = str(path.relative_to(ctx.root))
        for needle in ("org.ro.launcher", "org.kde.plasma.kickoff"):
            if needle not in text:
                errors.append(f"{label}: {needle} kontrolü/yedeği yok")
    yield from _emit(errors, "panel düzenleri doğru")


@check("VAL-GLO-05", "plasma", "eski global tema uyumluluğu")
def _(ctx):
    path = ctx.root / manifest.LOOKANDFEEL / "org.ro.global"
    yield from _emit([f"{path}: eski global tema kaldırılmalı"] if path.exists() else [],
                     "eski global tema yok")


@check("VAL-XDG-01", "xdg", "XDG dosya varlığı")
def _(ctx):
    errors = [f"{manifest.XDG_DIR}/{name}: dosya yok" for name in manifest.XDG_FILES
              if not (ctx.root / manifest.XDG_DIR / name).is_file()]
    yield from _emit(errors, "XDG dosyaları mevcut")


def _split_group(name):
    parts = re.findall(r"\[([^\]]+)\]", name)
    if len(parts) < 2:
        return None
    return parts[0], "[" + "][".join(parts[1:]) + "]"


@check("VAL-XDG-02", "xdg", "SYS-05 birebir eşleşme ilkesi")
def _(ctx):
    xdg = {}
    for name in manifest.XDG_FILES:
        cfg, error = read_kconfig(ctx.root / manifest.XDG_DIR / name)
        if error:
            xdg[name] = None
        else:
            xdg[name] = cfg
    exceptions = {"kdeglobals": {"ColorScheme", "Theme"}, "kwinrc": {"theme"},
                  "plasmarc": {"name"}, "ksplashrc": {"Theme"}}
    errors = []
    for mode in ("light", "dark"):
        path = ctx.root / manifest.look_dir(mode) / "contents/defaults"
        cfg, error = read_kconfig(path)
        if error:
            errors.append(error)
            continue
        for group, keys in cfg.groups.items():
            split = _split_group(group)
            if split is None:
                continue
            name, target_group = split
            target = xdg.get(name)
            if target is None:
                continue
            for key, value in keys.items():
                if key not in target.groups.get(target_group, {}):
                    continue
                if mode == "light" and bare_key(key) in exceptions.get(name, set()):
                    continue
                if target.groups[target_group][key] != value:
                    errors.append(f"{manifest.look_dir(mode)}/contents/defaults: {group} {key} "
                                  f"XDG {name} ile aynı olmalı")
    yield from _emit(errors, "global tema ve XDG değerleri eşleşiyor")


def _font_ok(value):
    return isinstance(value, str) and len(value.split(",")) == 19


@check("VAL-XDG-03", "xdg", "yazı tipi sözleşmesi")
def _(ctx):
    try:
        fonts = _tokens(ctx).fonts
        roles = {"font": "general", "fixed": "fixed", "smallestReadableFont": "small",
                 "toolBarFont": "toolbar", "menuFont": "menu"}
        expected = {key: tok.font_string(fonts[role]) for key, role in roles.items()}
        active = tok.font_string(fonts["windowTitle"])
        rendering = fonts["rendering"]
        xft = {"XftAntialias": "true" if rendering["antialias"] else "false",
               "XftHintStyle": str(rendering["hintStyle"]), "XftSubPixel": str(rendering["subPixel"])}
    except (tok.TokenError, KeyError) as e:
        yield fail(f"fonts belirteçleri okunamadı: {e}")
        return
    errors = []
    for mode in ("light", "dark"):
        path = ctx.root / manifest.look_dir(mode) / "contents/defaults"
        cfg, error = read_kconfig(path)
        if error:
            errors.append(error)
            continue
        label = f"{manifest.look_dir(mode)}/contents/defaults"
        for key, value in expected.items():
            actual = cfg.get("[kdeglobals][General]", key)
            if actual != value:
                errors.append(f"{label}: [kdeglobals][General] {key} fonts.json ile eşleşmeli")
            if not _font_ok(actual):
                errors.append(f"{label}: {key} 19 alanlı QFont dizgisi olmalı")
    kde, error = read_kconfig(ctx.root / manifest.XDG_DIR / "kdeglobals")
    if error:
        errors.append(error)
    else:
        actual = kde.get("[WM]", "activeFont")
        if actual != active:
            errors.append("XDG kdeglobals: [WM] activeFont fonts.windowTitle ile eşleşmeli")
        if not _font_ok(actual):
            errors.append("XDG kdeglobals: activeFont 19 alanlı QFont dizgisi olmalı")
        for key in roles:
            if key in kde.groups.get("[General]", {}):
                errors.append(f"XDG kdeglobals: [General] {key} sistemde tanımlanmamalı")
        for key, value in xft.items():
            actual = kde.get("[General]", key)
            if actual != value:
                errors.append(f"XDG kdeglobals: [General] {key}={value} olmalı")
    kcm, error = read_kconfig(ctx.root / manifest.XDG_DIR / "kcmfonts")
    if error:
        errors.append(error)
    elif kcm.get("[General]", "forceFontDPI") != "0":
        errors.append("XDG kcmfonts: [General] forceFontDPI=0 olmalı")
    yield from _emit(errors, "yazı tipi sözleşmesi doğru")


@check("VAL-XDG-04", "xdg", "pencere ve kilit ekranı tercihleri")
def _(ctx):
    errors = []
    kwin, error = read_kconfig(ctx.root / manifest.XDG_DIR / "kwinrc")
    if error:
        errors.append(error)
    else:
        if kwin.get("[org.kde.kdecoration2]", "ButtonsOnRight") != "IAX":
            errors.append("XDG kwinrc: ButtonsOnRight=IAX olmalı")
        if kwin.get("[org.kde.kdecoration2]", "ButtonsOnLeft") != "M":
            errors.append("XDG kwinrc: ButtonsOnLeft=M olmalı")
    lock, error = read_kconfig(ctx.root / manifest.XDG_DIR / "kscreenlockerrc")
    if error:
        errors.append(error)
    else:
        values = {key: value for keys in lock.groups.values() for key, value in keys.items()}
        if values.get("WallpaperPlugin") != "org.kde.image":
            errors.append("XDG kscreenlockerrc: WallpaperPlugin=org.kde.image olmalı")
        if (values.get("Blur") or "").lower() != "false":
            errors.append("XDG kscreenlockerrc: Blur=false olmalı")
        image = "/usr/share/plasma/look-and-feel/org.ro.dark/contents/lockscreen/assets/login.jpg"
        if values.get("Image") != f"file://{image}":
            errors.append(f"XDG kscreenlockerrc: Image=file://{image} olmalı")
    breeze, error = read_kconfig(ctx.root / manifest.XDG_DIR / "breezerc")
    if error:
        errors.append(error)
    else:
        if (breeze.get("[Style]", "ViewDrawTreeBranchLines") or "").lower() != "false":
            errors.append("XDG breezerc: [Style] ViewDrawTreeBranchLines=false olmalı")
        if breeze.get("[Style]", "MenuOpacity") != "60":
            errors.append("XDG breezerc: [Style] MenuOpacity=60 olmalı")
    kde, error = read_kconfig(ctx.root / manifest.XDG_DIR / "kdeglobals")
    if error:
        errors.append(error)
    elif (kde.get("[KDE]", "ShowIconsOnPushButtons") or "").lower() != "false":
        errors.append("XDG kdeglobals: [KDE] ShowIconsOnPushButtons=false olmalı")
    yield from _emit(errors, "pencere ve kilit ekranı tercihleri doğru")


def _config_files(root):
    paths = [root / manifest.XDG_DIR / name for name in manifest.XDG_FILES]
    for base in (root / "platform",):
        if not base.is_dir():
            continue
        for path in base.rglob("*"):
            if not path.is_file() or path.suffix in (".svg", ".json", ".js", ".png", ".jpg", ".pf2", ".svgz"):
                continue
            if path.name in manifest.XDG_FILES or path.name in ("plasmarc", "defaults") \
                    or path.name.endswith((".conf", ".desktop", "rc")):
                paths.append(path)
    return sorted(set(paths))


@check("VAL-XDG-05", "xdg", "eski efektlerin yokluğu")
def _(ctx):
    errors = []
    for path in _config_files(ctx.root):
        cfg, error = read_kconfig(path)
        if error:
            continue
        label = str(path.relative_to(ctx.root))
        for group, keys in cfg.groups.items():
            for key in keys:
                bare = bare_key(key)
                if bare.startswith("kwin4_effect_") or bare.startswith("ro-smooth-motion"):
                    errors.append(f"{label}: {group} {key} eski efekt anahtarı olmamalı")
        if path.name == "kwinrc" and "[Plugins]" in cfg.groups:
            keys = cfg.groups["[Plugins]"]
            if set(keys) != {"ro-login-revealEnabled"} or (keys.get("ro-login-revealEnabled") or "").lower() != "true":
                errors.append(f"{label}: [Plugins] yalnız ro-login-revealEnabled=true içermeli")
    yield from _emit(errors, "eski efektler yok")


@check("VAL-PLY-01", "plymouth", "Plasma giriş yapılandırması")
def _(ctx):
    errors = []
    cfg, error = read_kconfig(ctx.root / manifest.PLASMALOGIN_FILE)
    if error:
        errors.append(error)
    else:
        values = {key: value for keys in cfg.groups.values() for key, value in keys.items()}
        if values.get("WallpaperPluginId") != "org.kde.image":
            errors.append("20-ro-theme.conf: WallpaperPluginId=org.kde.image olmalı")
        if values.get("Image") != "file:///usr/share/ro-theme/wallpapers/login.jpg":
            errors.append("20-ro-theme.conf: Image=file:///usr/share/ro-theme/wallpapers/login.jpg olmalı")
    if not (ctx.root / manifest.WALLPAPERS / "loginv2.jpg").is_file():
        errors.append("assets/wallpapers/loginv2.jpg: dosya yok")
    if (ctx.root / "platform/sddm").exists():
        errors.append("platform/sddm: dizin olmamalı")
    yield from _emit(errors, "giriş yapılandırması doğru")


@check("VAL-PLY-02", "plymouth", "Plymouth tema yapılandırması")
def _(ctx):
    try:
        dark = _tokens(ctx).dark
        expected = {
            "BackgroundStartColor": "0x" + dark["bootBackground"].lstrip("#").lower(),
            "BackgroundEndColor": "0x" + dark["bootBackground"].lstrip("#").lower(),
            "ProgressBarBackgroundColor": "0x" + dark["surfaceAlt"].lstrip("#").lower(),
            "ProgressBarForegroundColor": "0x" + dark["accent"].lstrip("#").lower(),
        }
    except (tok.TokenError, KeyError) as e:
        yield fail(f"Plymouth renk belirteçleri okunamadı: {e}")
        return
    path = ctx.root / manifest.PLYMOUTH_DIR / "ro-theme.plymouth"
    cfg, error = read_kconfig(path)
    if error:
        yield fail(error)
        return
    values = {key: value for keys in cfg.groups.values() for key, value in keys.items()}
    errors = []
    if values.get("ModuleName") != "two-step":
        errors.append(f"{path}: ModuleName=two-step olmalı")
    if (values.get("UseFirmwareBackground") or "").lower() != "true":
        errors.append(f"{path}: UseFirmwareBackground=true olmalı")
    for key, value in expected.items():
        if values.get(key) != value:
            errors.append(f"{path}: {key}={value} olmalı")
    yield from _emit(errors, "Plymouth yapılandırması doğru")


def _png_size(path):
    data = path.read_bytes()[:24]
    if len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        return None
    return struct.unpack(">II", data[16:24])


@check("VAL-PLY-03", "plymouth", "Plymouth kareleri ve varlık boyutları")
def _(ctx):
    path = ctx.root / manifest.PLYMOUTH_DIR
    if not path.is_dir():
        yield fail(f"{manifest.PLYMOUTH_DIR}: dizin yok")
        return
    errors = []
    for index in range(1, 87):
        frame = path / f"throbber-{index:04d}.png"
        if not frame.is_file():
            errors.append(f"{frame.name}: dosya yok")
            continue
        size = _png_size(frame)
        if size != (192, 192):
            errors.append(f"{frame.name}: 192x192 PNG olmalı (şu an {size})")
    for name in ("entry.png", "bullet.png", "lock.png", "capslock.png"):
        if not (path / name).is_file():
            errors.append(f"{name}: dosya yok")
    total = sum(item.stat().st_size for item in path.iterdir() if item.is_file())
    if total > 2 * 1024 * 1024:
        errors.append(f"{manifest.PLYMOUTH_DIR}: toplam boyut {total} > 2 MiB")
    yield from _emit(errors, "Plymouth kareleri ve boyutları doğru")


@check("VAL-GRB-01", "grub", "GRUB tema bütünlüğü")
def _(ctx):
    path = ctx.root / manifest.GRUB_DIR
    theme = path / "theme.txt"
    text, error = read_text(theme)
    if error:
        yield fail(error)
        return
    errors = []
    references = []
    for line in text.splitlines():
        match = re.match(r"^\s*([A-Za-z0-9_-]+)\s*[:=]\s*\"([^\"]*)\"\s*$", line)
        if not match:
            continue
        key, value = match.groups()
        if key in ("desktop-image", "file") or key.endswith("pixmap_style"):
            references.append((key, value))
        if "color" in key and not re.fullmatch(r"#[0-9A-Fa-f]{6}", value):
            errors.append(f"{theme.name}: {key} geçerli #RRGGBB değil ({value})")
    for key, value in references:
        if any(char in value for char in "*?["):
            matches = list(path.glob(value))
        else:
            matches = [path / value] if (path / value).is_file() else []
        if not matches:
            errors.append(f"{theme.name}: {key} görseli bulunamadı ({value})")
    yield from _emit(errors, "GRUB teması bütün")


@check("VAL-AST-01", "assets", "varlık bütünlüğü ve sembolik bağlar")
def _(ctx):
    errors = []
    for name in ("platform", "assets", "core", "dist"):
        base = ctx.root / name
        if not base.is_dir():
            continue
        for path in sorted(base.rglob("*")):
            label = str(path.relative_to(ctx.root))
            if path.is_symlink():
                try:
                    target = path.resolve(strict=True)
                    if not target.is_relative_to(ctx.root.resolve()):
                        errors.append(f"{label}: sembolik bağ depo dışına çıkıyor")
                except (OSError, RuntimeError) as e:
                    errors.append(f"{label}: kırık sembolik bağ ({e})")
                continue
            if not path.is_file() or path.suffix not in (".svg", ".svgz"):
                continue
            try:
                data = path.read_bytes()
                root = ET.fromstring(gzip.decompress(data) if path.suffix == ".svgz" else data)
                if local(root.tag) != "svg":
                    errors.append(f"{label}: kök eleman <svg> olmalı")
            except (OSError, EOFError, ET.ParseError) as e:
                errors.append(f"{label}: geçersiz SVG/XML ({e})")
    index = ctx.root / manifest.ICONS_DIR / "index.theme"
    cfg, error = read_kconfig(index)
    if error:
        errors.append(error)
    else:
        if cfg.get("[Icon Theme]", "Inherits") != "Papirus-Dark":
            errors.append(f"{index}: Inherits=Papirus-Dark olmalı")
        for key in ("Directories", "ScaledDirectories"):
            for directory in (cfg.get("[Icon Theme]", key) or "").split(","):
                directory = directory.strip()
                if not directory:
                    continue
                if not (index.parent / directory).is_dir():
                    errors.append(f"{index}: {directory} dizini yok")
                if f"[{directory}]" not in cfg.groups:
                    errors.append(f"{index}: [{directory}] INI bölümü yok")
    yield from _emit(errors, "varlıklar bütün")


@check("VAL-AST-02", "assets", "yasaklı genel ikonların yokluğu")
def _(ctx):
    forbidden = {"audio-x-generic.svg", "video-x-generic.svg", "image-x-generic.svg", "text-x-generic.svg"}
    base = ctx.root / manifest.ICONS_DIR
    found = [str(path.relative_to(ctx.root)) for path in base.rglob("*") if path.name in forbidden] \
        if base.is_dir() else []
    yield from _emit([f"{rel}: yasaklı genel ikon" for rel in found], "yasaklı genel ikon yok")


@check("VAL-AST-03", "assets", "imleç ve tarayıcı yapılandırması")
def _(ctx):
    errors = []
    cursor = ctx.root / manifest.CURSOR_DIR
    if not (cursor / "index.theme").is_file():
        errors.append(f"{manifest.CURSOR_DIR}/index.theme: dosya yok")
    text, error = read_text(ctx.root / manifest.FIREFOX_FILE)
    if error:
        errors.append(error)
    else:
        prefs = set(re.findall(r"pref\s*\(\s*\"([^\"]+)\"", text))
        for name in ("ui.accentcolor", "ui.accentcolortext"):
            if name not in prefs:
                errors.append(f"{manifest.FIREFOX_FILE}: {name} tercihi yok")
    yield from _emit(errors, "imleç ve tarayıcı yapılandırması doğru")


@check("VAL-AST-04", "assets", "KWin efekti")
def _(ctx):
    path = ctx.root / manifest.KWIN_EFFECTS_DIR / manifest.KWIN_EFFECT
    errors = []
    if not (path / "metadata.json").is_file():
        errors.append(f"{path}/metadata.json: dosya yok")
    main = path / "contents/code/main.js"
    text, error = read_text(main)
    if error:
        errors.append(error)
    else:
        if not re.search(r"windowClass", text):
            errors.append(f"{main}: pencere sınıfı denetimi yok")
        if "ksplashqml" not in text:
            errors.append(f"{main}: ksplashqml denetimi yok")
    yield from _emit(errors, "KWin efekti doğru")


@check("VAL-FRS-01", "freshness", "belirteç ve üretim senkronizasyonu")
def _(ctx):
    if not ctx.freshness:
        return
    from .. import generate
    try:
        tokens = _tokens(ctx)
        files = generate.collect(generate.Context(tokens, ctx.root))
    except Exception as e:  # üreteç henüz tamamlanmamış olabilir
        yield fail(f"üretim çalıştırılamadı: {e}")
        return
    errors = []
    for rel, data in files.items():
        path = ctx.root / rel
        try:
            if path.read_bytes() != data:
                errors.append(f"{rel}: belirteçlerden üretilen içerikle aynı değil")
        except OSError:
            errors.append(f"{rel}: üretilmiş dosya yok")
    yield from _emit(errors, "üretilmiş dosyalar güncel")
