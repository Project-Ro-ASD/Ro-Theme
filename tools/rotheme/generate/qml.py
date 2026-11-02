"""`dist/qml/RoTokens.qml` tekil nesnesi (gereksinimler/13 §5)."""
from __future__ import annotations

HEADER = """// SPDX-FileCopyrightText: Project Ro-ASD
// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton
import QtQuick

// Ro tasarım token'ları (QML). ./ro generate tarafından core/tokens'tan ÜRETİLİR, elle düzenlenmez.
// WGT-02: ro-theme paketi bu dosyayı /usr/share/ro-theme/qml/RoTokens.qml olarak kurar. ro-widgets derlenirken
// oradan alır (elle kopyalama yok, TOK-16); widget qmldir: singleton RoTokens 1.0 RoTokens.qml
// Renkler bu dosyada yok: Kirigami.Theme kullan, böylece her renk şemasıyla uyumlu kalır.
// Süreler taban değerdir (ms); Plasma animasyon hızı çarpanını (AnimationDurationFactor) uygulamak widget'ın işidir.
"""


def _key(name: str) -> str:
    return name[0].upper() + name[1:]


def _lines(t) -> list[str]:
    lines = [f"    readonly property real radius{_key(k)}: {v}" for k, v in t.radius.items()]
    s = t.spacing
    lines += [f"    readonly property real space{_key(k)}: {s[k]}" for k in ("xs", "sm", "md", "lg", "xl")]
    lines += [f"    readonly property real borderWidth: {s.borderWidth}",
              f"    readonly property real popupPadding: {s.popupPadding}"]
    lines += [f"    readonly property real opacity{_key(k)}: {v}"
              for k, v in t.opacity.items() if k != "shadow"]
    lines += [f"    readonly property real motion{_key(k)}: {v}"
              for k, v in t.motion.items() if k != "curve"]
    return lines


def outputs(ctx) -> dict[str, str]:
    return {"dist/qml/RoTokens.qml": HEADER + "QtObject {\n" + "\n".join(_lines(ctx.tokens)) + "\n}\n"}
