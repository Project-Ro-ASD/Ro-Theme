// SPDX-FileCopyrightText: Project Ro-ASD
// SPDX-License-Identifier: GPL-3.0-or-later
// Ro şafak sahnesi (PSU-06): Ro-Plasma-Setup sayfalarının etkileşimli arka planı; elle yazılır, üretilmez.
import QtQuick
import QtQuick.Shapes

Item {
    id: root
    implicitWidth: 1920
    implicitHeight: 1080

    property real progress: 0
    property bool dark: true
    property real pointerX: 0
    property real pointerY: 0
    property bool highlight: false
    property bool reducedMotion: false

    // ---- Animated internal state ----
    property real _p: progress
    property real _d: dark ? 1.0 : 0.0
    property real _h: highlight ? 1.0 : 0.0
    property real _px: Math.max(-1, Math.min(1, pointerX))
    property real _py: Math.max(-1, Math.min(1, pointerY))

    Behavior on _p { enabled: true; NumberAnimation { duration: root.reducedMotion ? 0 : 900; easing.type: Easing.InOutCubic } }
    Behavior on _d { NumberAnimation { duration: root.reducedMotion ? 0 : 800; easing.type: Easing.InOutCubic } }
    Behavior on _h { NumberAnimation { duration: root.reducedMotion ? 0 : 600; easing.type: Easing.OutCubic } }
    Behavior on _px { NumberAnimation { duration: root.reducedMotion ? 0 : 400; easing.type: Easing.OutQuad } }
    Behavior on _py { NumberAnimation { duration: root.reducedMotion ? 0 : 400; easing.type: Easing.OutQuad } }

    // ---- Helpers ----
    // Metin olarak verilen renkler ("#RRGGBB") önce renk nesnesine çevrilir; yoksa a.r tanımsız kalır.
    function mix(a, b, t) { a = Qt.lighter(a, 1.0); b = Qt.lighter(b, 1.0); return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t,
                                           a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t) }
    function clamp01(v) { return Math.max(0, Math.min(1, v)) }
    // dark/light blend
    function pal(darkC, lightC) { return mix(lightC, darkC, clamp01(_d)) }

    readonly property real p: clamp01(_p)
    readonly property real glow: clamp01(0.55 + 0.45 * p) // base brightness
    readonly property real horizonY: height * 0.62

    // ---- Palette ----
    readonly property color skyTop: pal("#0F1A33", "#DCE6F5")
    readonly property color skyHorizon: mix(pal("#213966", "#B4C3DD"), pal("#3B5A8C", "#F5F6F6"), p)
    readonly property color lightCore: pal("#F2C98A", "#FFE2B0")
    readonly property color lightEdge: pal("#7DA2E8", "#B4C3DD")
    readonly property color gold: "#C9A86A"
    readonly property color hill0: pal("#3E5A86", "#B4BFD0")
    readonly property color hill1: pal("#2C4570", "#9AA9C2")
    readonly property color hill2: pal("#1F3358", "#7F92B2")
    readonly property color hill3: pal("#15233F", "#3059A6")

    // ---- 1. Sky ----
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.skyTop }
            GradientStop { position: 1.0; color: root.skyHorizon }
        }
    }

    // ---- 2. Horizon glow ----
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            id: glowPath
            strokeColor: "transparent"
            strokeWidth: -1
            readonly property real cx: root.width * 0.5
            readonly property real cy: root.horizonY + root.height * 0.10 * (1 - root.p) - root.height * 0.06 * root.p
            readonly property real rx: root.width * (0.28 + 0.27 * root.p)
            readonly property real ry: root.height * (0.20 + 0.15 * root.p)
            readonly property real op: (0.25 + 0.65 * root.p) * (1 + 0.15 * root._h)
            fillGradient: RadialGradient {
                centerX: glowPath.cx; centerY: glowPath.cy
                focalX: centerX; focalY: centerY
                centerRadius: glowPath.rx
                GradientStop { position: 0.0; color: Qt.rgba(root.lightCore.r, root.lightCore.g, root.lightCore.b, Math.min(1, glowPath.op)) }
                GradientStop { position: 0.45; color: Qt.rgba(root.lightCore.r, root.lightCore.g, root.lightCore.b, Math.min(1, glowPath.op) * 0.35) }
                GradientStop { position: 1.0; color: Qt.rgba(root.lightEdge.r, root.lightEdge.g, root.lightEdge.b, 0) }
            }
            // Ellipse via scaled rect: draw a wide rectangle area; gradient radius limits it
            PathMove { x: glowPath.cx - glowPath.rx; y: glowPath.cy - glowPath.rx }
            PathLine { x: glowPath.cx + glowPath.rx; y: glowPath.cy - glowPath.rx }
            PathLine { x: glowPath.cx + glowPath.rx; y: glowPath.cy + glowPath.rx }
            PathLine { x: glowPath.cx - glowPath.rx; y: glowPath.cy + glowPath.rx }
            PathLine { x: glowPath.cx - glowPath.rx; y: glowPath.cy - glowPath.rx }
        }
        // Squash the circular gradient into an ellipse
        transform: Scale {
            origin.x: glowPath.cx
            origin.y: glowPath.cy
            xScale: 1
            yScale: glowPath.ry / glowPath.rx
        }
    }

    // ---- 3. Hill layers ----
    component HillLayer: Shape {
        id: layer
        property color fillColor
        property real baseY: 0.7        // fraction of height
        property real amp: 0.05         // fraction of height
        property real phase: 0
        property real shiftX: 0
        property real shiftY: 0
        property real fillOpacity: 1
        property real lineOpacity: 0.4

        anchors.fill: parent
        anchors.leftMargin: -40
        anchors.rightMargin: -40
        x: shiftX
        y: shiftY
        preferredRendererType: Shape.CurveRenderer

        readonly property real w: width
        readonly property real h: height
        readonly property real by: h * baseY
        readonly property real a: h * amp

        ShapePath {
            fillColor: layer.fillColor
            strokeColor: "transparent"
            strokeWidth: -1
            startX: 0; startY: layer.by
            PathCubic {
                x: layer.w * 0.35; y: layer.by - layer.a * (0.6 + layer.phase)
                control1X: layer.w * 0.12; control1Y: layer.by + layer.a * layer.phase
                control2X: layer.w * 0.22; control2Y: layer.by - layer.a * 1.2
            }
            PathCubic {
                x: layer.w * 0.68; y: layer.by + layer.a * 0.3
                control1X: layer.w * 0.46; control1Y: layer.by + layer.a * 0.1
                control2X: layer.w * 0.56; control2Y: layer.by + layer.a * 0.9
            }
            PathCubic {
                x: layer.w; y: layer.by - layer.a * (0.4 + layer.phase)
                control1X: layer.w * 0.80; control1Y: layer.by - layer.a * 0.7
                control2X: layer.w * 0.90; control2Y: layer.by - layer.a * 1.1
            }
            PathLine { x: layer.w; y: layer.h + 20 }
            PathLine { x: 0; y: layer.h + 20 }
            PathLine { x: 0; y: layer.by }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.rgba(root.gold.r, root.gold.g, root.gold.b, layer.lineOpacity)
            strokeWidth: 1
            startX: 0; startY: layer.by
            PathCubic {
                x: layer.w * 0.35; y: layer.by - layer.a * (0.6 + layer.phase)
                control1X: layer.w * 0.12; control1Y: layer.by + layer.a * layer.phase
                control2X: layer.w * 0.22; control2Y: layer.by - layer.a * 1.2
            }
            PathCubic {
                x: layer.w * 0.68; y: layer.by + layer.a * 0.3
                control1X: layer.w * 0.46; control1Y: layer.by + layer.a * 0.1
                control2X: layer.w * 0.56; control2Y: layer.by + layer.a * 0.9
            }
            PathCubic {
                x: layer.w; y: layer.by - layer.a * (0.4 + layer.phase)
                control1X: layer.w * 0.80; control1Y: layer.by - layer.a * 0.7
                control2X: layer.w * 0.90; control2Y: layer.by - layer.a * 1.1
            }
        }
    }

    HillLayer {
        fillColor: root.hill0
        baseY: 0.66; amp: 0.06; phase: 0.2; lineOpacity: 0.35
        shiftX: root._px * 4; shiftY: root._py * 2
    }
    HillLayer {
        fillColor: root.hill1
        baseY: 0.73; amp: 0.055; phase: 0.5; lineOpacity: 0.40
        shiftX: root._px * 7; shiftY: root._py * 4
    }
    HillLayer {
        fillColor: root.hill2
        baseY: 0.81; amp: 0.05; phase: 0.1; lineOpacity: 0.45
        shiftX: root._px * 10; shiftY: root._py * 7
    }
    HillLayer {
        fillColor: root.hill3
        baseY: 0.89; amp: 0.04; phase: 0.35; lineOpacity: 0.50
        shiftX: root._px * 14; shiftY: root._py * 10
    }

    // ---- 4. Subtle paper texture ----
    Shape {
        anchors.fill: parent
        opacity: 0.03
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.dark ? "#FFFFFF" : "#000000"
            strokeWidth: 1
            fillColor: "transparent"
            PathMultiline {
                paths: {
                    var arr = []
                    for (var y = 3; y < root.height; y += 6)
                        arr.push([Qt.point(0, y), Qt.point(root.width, y)])
                    return arr
                }
            }
        }
    }
}
