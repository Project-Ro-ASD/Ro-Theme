"""`dist/qml/RoTokens.qml` ve `org.ro.theme` modülünün üretilen dosyaları (gereksinimler/13 §5, PSU-05/06)."""
from __future__ import annotations

HEADER = """// SPDX-FileCopyrightText: Project Ro-ASD
// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton
import QtQuick

// Ro tasarım token'ları (QML). ./ro generate tarafından core/tokens'tan ÜRETİLİR, elle düzenlenmez.
// WGT-02: ro-theme paketi bu dosyayı /usr/share/ro-theme/qml/RoTokens.qml olarak kurar. ro-widgets derlenirken
// oradan alır (elle kopyalama yok, TOK-16); widget qmldir: singleton RoTokens 1.0 RoTokens.qml
// PSU-05: aynı içerik org.ro.theme modülünde de kurulur (/usr/share/ro-theme/qml/org/ro/theme/RoTokens.qml);
// paket mimariden bağımsız olduğu için dizin içe aktarımı kullanılır:
//   import "file:///usr/share/ro-theme/qml/org/ro/theme"   ya da QML_IMPORT_PATH=/usr/share/ro-theme/qml ile import org.ro.theme
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


MODULE_DIR = "platform/qml/org/ro/theme"
LOGO_URL = "file:///usr/share/ro-theme/brand/roasd-logo.png"

QMLDIR = """module org.ro.theme
singleton RoTokens 1.0 RoTokens.qml
singleton RoBrand 1.0 RoBrand.qml
DawnScene 1.0 DawnScene.qml
"""

BRAND = """// SPDX-FileCopyrightText: Project Ro-ASD
// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton
import QtQuick

// Ro marka bilgileri (PSU-05). ./ro generate tarafından üretilir, elle düzenlenmez.
// Sürüm VERSION dosyasından gelir; logo ro-theme paketinin kurduğu sabit yoldadır. Renk içermez.
QtObject {
    readonly property string version: "%s"
    readonly property url logo: "%s"
}
"""


def _rotokens(ctx) -> str:
    return HEADER + "QtObject {\n" + "\n".join(_lines(ctx.tokens)) + "\n}\n"


def outputs(ctx) -> dict[str, str]:
    tokens_qml = _rotokens(ctx)
    return {
        "dist/qml/RoTokens.qml": tokens_qml,
        f"{MODULE_DIR}/RoTokens.qml": tokens_qml,
        f"{MODULE_DIR}/RoBrand.qml": BRAND % (ctx.tokens.version, LOGO_URL),
        f"{MODULE_DIR}/qmldir": QMLDIR,
    }
