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
    // Güneş: 0 yok (yalnız ufuk ışığı), 1 tepelerin arkasından doğan disk, 2 disk + yavaş dönen ışınlar
    property int sunStyle: 1
    // Bitiş: güneş yerinden fırlar, sola-yukarı süzülür, büyür, ışık halkası yayar ve hafifçe süzülerek oynar
    property bool finale: false
    // Bitiş çeşidi: 0 sol üste süzülme, 1 yerinde büyüyüp nabız, 2 ışık patlaması, 3 gökte yay çizme, 4 tam gün doğumu
    property int finaleStyle: 1
    // 5 izleyen güneş (fareyi yavaşça izler, dokununca halka), 6 yıldızlar ve kuşlar, 7 parıltı izi.
    // 5–7: güneş büyümez, içeriğin (clearY) altında ve tepelerin hemen üstünde durur; tam ekran ışık yok.
    property real contentBottom: -1
    property bool _leaving: false

    // Çıkışta çağrılır: yıldız/kuş animasyonlarını durdurur, güneşten halka yayar
    function leave() {
        if (_leaving) return;
        _leaving = true;
        if (!reducedMotion)
            leaveRingAnim.restart();
    }
    readonly property bool calm: finaleStyle >= 5
    // Güneşin fareyi gecikmeli izlemesi (5)
    property real _sx: _px
    Behavior on _sx { NumberAnimation { duration: root.reducedMotion ? 0 : 1600; easing.type: Easing.OutCubic } }
    readonly property real pointerAbsX: (pointerX + 1) / 2 * width
    readonly property real pointerAbsY: (pointerY + 1) / 2 * height
    property real _near: 0
    Binding on _near { value: Math.max(0, 1 - Math.hypot(root.pointerAbsX - root.sunX, root.pointerAbsY - root.sunY) / (root.sunR * 6)) }
    Behavior on _near { NumberAnimation { duration: 300 } }
    property real _fin: finale ? 1 : 0
    Behavior on _fin { NumberAnimation { duration: root.reducedMotion ? 0 : (root.finaleStyle === 3 ? 2600 : root.finaleStyle === 0 ? 1600 : 2000)
                                         easing.type: root.finaleStyle === 0 ? Easing.OutBack : root.finaleStyle === 1 ? Easing.OutElastic
                                                    : root.calm ? Easing.OutCubic : Easing.InOutCubic
                                         easing.overshoot: 1.6; easing.amplitude: 1.0; easing.period: 0.55 } }
    // Işık patlaması (2): güneş bir anda bütün ekranı dolduracak kadar büyür, sonra yerine çekilir
    property real _flash: 0
    SequentialAnimation {
        running: root.finale && root.finaleStyle === 2 && !root.reducedMotion
        PauseAnimation { duration: 700 }
        NumberAnimation { target: root; property: "_flash"; from: 0; to: 1; duration: 650; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "_flash"; to: 0; duration: 1600; easing.type: Easing.InOutCubic }
    }
    property real _bob: 0
    SequentialAnimation on _bob {
        running: root.finale && !root.reducedMotion
        loops: Animation.Infinite
        NumberAnimation { to: 1; duration: 2200; easing.type: Easing.InOutSine }
        NumberAnimation { to: -1; duration: 2200; easing.type: Easing.InOutSine }
    }
    // PSU-07 G: sihirbaz ilerledikçe tepeler aşağı iner (0..1, yüksekliğin oranı). clearY ≥ 0 ise en arka tepenin
    // zirvesi bu y'nin (piksel) altında kalır: sayfadaki yazı tepelerle çakışmaz.
    property real hillDrop: 0
    property real clearY: -1

    // ---- Animated internal state ----
    property real _p: progress
    property real _d: dark ? 1.0 : 0.0
    property real _h: highlight ? 1.0 : 0.0
    property real _px: Math.max(-1, Math.min(1, pointerX))
    property real _py: Math.max(-1, Math.min(1, pointerY))
    // En arka tepenin zirvesi yaklaşık yüksekliğin %58'i; clearY'nin altına inmesi için gereken ek iniş
    readonly property real _need: clearY >= 0 && height > 0 ? (clearY + height * 0.04) / height - 0.582 : 0
    // Tam gün doğumu (4): bitişte tepeler ekranın altına çekilir
    property real _drop: Math.max(0, Math.min(0.24, Math.max(hillDrop, _need))) + (finaleStyle === 4 ? 0.14 * Math.max(0, _fin) : 0)
                         + (_leaving ? 0.45 : 0)   // Bitir: tepeler aşağı çekilir, masaüstü belirir
    Behavior on _drop { NumberAnimation { duration: root.reducedMotion ? 0 : 900; easing.type: Easing.InOutCubic } }

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
    readonly property real horizonY: height * (0.62 + _drop)

    // ---- Palette ----
    // 6 gece → gündüz: koyu modda gök en sonda sabah mavisine açılır (beyaz yazı okunur kalacak kadar)
    // 6, açık mod tersi: gündüz başlar, gün batar, alacakaranlıkta biter. Gök koyu yazının okunacağı kadar kararır.
    readonly property bool dusk: finaleStyle === 6 && !dark
    // Gün batımı ilerlemesi (açık mod): adımlarla, bitişte tamamlanır
    readonly property real _dk: clamp01(0.8 * p + 0.2 * Math.min(1, _f))
    readonly property color skyTop: dusk ? mix("#D6E4F7", "#8D98C2", _dk)
                                  : finaleStyle === 6 ? mix(pal("#0B1428", "#DCE6F5"), pal("#2C4A7C", "#E4EEFA"), clamp01(0.35 * p + 0.65 * _f))
                                  : pal("#0F1A33", "#DCE6F5")
    // Koyu modda sayfalarla ufka hafif mor-pembe şafak ısısı girer, bitişte gündüz rengine döner
    readonly property color skyHorizon: dusk ? mix(mix("#F2F5F8", "#F7DCC4", clamp01(_dk * 1.6)), "#E9B9A0", clamp01(_dk * 2 - 1))
                                      : finaleStyle === 6 ? mix(mix(mix(pal("#213966", "#B4C3DD"), pal("#4A4A78", "#D6DDE8"), clamp01(p * 2)),
                                                                    pal("#6A5A80", "#F5F6F6"), clamp01(p * 2 - 1)),
                                                                pal("#3B5A8C", "#F5F6F6"), clamp01(_f))
                                      : mix(mix(pal("#213966", "#B4C3DD"), pal("#3B5A8C", "#F5F6F6"), p),
                                            pal("#7A86A8", "#FFF4E2"), finaleStyle === 4 ? 0.6 * clamp01(_fin) : 0)
    // Üst yarı beyaz yazı için koyu kalır; şafak ısısı ufukta toplanır
    readonly property color skyMid: !dusk && finaleStyle === 6 ? mix(skyTop, skyHorizon, 0.35)
                                  : mix(skyTop, skyHorizon, 0.55)
    // Tepe sırtı ışığı: koyu modda gün doğumunda, açık modda gün batımında (tepe arkasında söner)
    readonly property real _rim: dusk ? clamp01((_dk - 0.3) / 0.6) * clamp01((1 - _dk) / 0.1)
                               : finaleStyle === 6 ? clamp01(_f) : 0
    readonly property color _rimColor: dusk ? "#FFB98A" : "#FFD9A0"
    readonly property color lightCore: dusk ? mix("#FFE2B0", "#F4A46E", _dk) : pal("#F2C98A", "#FFE2B0")
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
            GradientStop { position: 0.55; color: root.skyMid }
            GradientStop { position: 1.0; color: root.skyHorizon }
        }
    }

    // ---- 1b. Gece (6, koyu): yıldızlar, ay ve kayan yıldız. Sabah yaklaştıkça hepsi söner ----
    readonly property real night: finaleStyle === 6 && dark ? (1 - 0.8 * p) * (1 - Math.min(1, _f)) : 0
    // Yıldızlar üç ortak parıltı evresi kullanır (her yıldıza ayrı animasyon yok)
    property real _tw0: 0.6
    property real _tw1: 0.6
    property real _tw2: 0.6
    component Twinkle: SequentialAnimation {
        property string prop
        property int ms
        loops: Animation.Infinite
        running: (root.night > 0.02 || root.dusk && root._dk > 0.5) && !root.reducedMotion
        NumberAnimation { target: root; property: prop; to: 1; duration: ms; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: prop; to: 0.3; duration: ms * 1.3; easing.type: Easing.InOutSine }
    }
    Twinkle { prop: "_tw0"; ms: 1500 }
    Twinkle { prop: "_tw1"; ms: 2100 }
    Twinkle { prop: "_tw2"; ms: 2700 }
    Item {
        id: sky
        anchors.fill: parent
        visible: root.finaleStyle === 6
        // Işık parçacığı: dışa kayıp söner, bitince kendini siler
        Component {
            id: sparkComp
            Rectangle {
                id: sp
                property real x0
                property real y0
                property real dx
                property real dy
                property int dur: 700
                width: 3; height: 3; radius: 1.5
                color: root.dusk ? "#FFF4E0" : "#FFFFFF"
                x: x0 - width / 2; y: y0 - height / 2
                opacity: 0.9
                ParallelAnimation {
                    running: true
                    NumberAnimation { target: sp; property: "x"; to: sp.x0 - sp.width / 2 + sp.dx; duration: sp.dur; easing.type: Easing.OutCubic }
                    NumberAnimation { target: sp; property: "y"; to: sp.y0 - sp.height / 2 + sp.dy; duration: sp.dur; easing.type: Easing.OutCubic }
                    NumberAnimation { target: sp; property: "opacity"; to: 0; duration: sp.dur; easing.type: Easing.InQuad }
                    onFinished: sp.destroy()
                }
            }
        }
        // 6 parçacık saç (azaltılmış harekette yok)
        function burst(cx, cy) {
            if (root.reducedMotion) return;
            for (let i = 0; i < 6; i++) {
                const a = (i + Math.random() * 0.6) / 6 * Math.PI * 2;
                const d = 16 + Math.random() * 14;
                sparkComp.createObject(sky, { x0: cx, y0: cy, dx: Math.cos(a) * d, dy: Math.sin(a) * d, dur: 600 + Math.random() * 300 });
            }
        }
        // Dokunma: önce 28 px içindeki en yakın görünür yıldız, yoksa ay. Vurulduysa true
        function tapAt(px, py) {
            let best = -1, bd = 28;
            for (let i = 0; i < stars.count; i++) {
                const s = stars.itemAt(i);
                if (!s || s.opacity < 0.05) continue;
                const d = Math.hypot(px - s.x - s.width / 2, py - s.y - s.height / 2);
                if (d < bd) { bd = d; best = i }
            }
            if (best >= 0) {
                const s = stars.itemAt(best);
                s.flash();
                burst(s.x + s.width / 2, s.y + s.height / 2);
                return true;
            }
            const c = moon.mapToItem(root, moon.r, moon.r);
            if (moon.opacity > 0.05 && (!root.dusk || moon._rise > 0.4)
                    && Math.hypot(px - c.x, py - c.y) < Math.max(28, moon.r * 1.6)) {
                moon.poke();
                return true;
            }
            return false;
        }
        Repeater {
            id: stars
            model: 54
            Rectangle {
                id: star
                required property int index
                // Dokunma parlaması: 0→1→0 (1.2 sn); hareketi azaltta kısa
                property real hit: 0
                function flash() { hitAnim.restart() }
                SequentialAnimation {
                    id: hitAnim
                    NumberAnimation { target: star; property: "hit"; to: 1; duration: root.reducedMotion ? 120 : 480; easing.type: Easing.OutCubic }
                    NumberAnimation { target: star; property: "hit"; to: 0; duration: root.reducedMotion ? 180 : 720; easing.type: Easing.InOutSine }
                }
                readonly property real rx: ((index * 7919) % 1000) / 1000
                readonly property real ry: ((index * 104729) % 1000) / 1000
                x: rx * root.width; y: ry * ry * root.height * 0.55
                width: 1.5 + (index % 3) * 0.8; height: width; radius: width / 2
                color: index % 9 === 0 ? "#FFE9C4" : "#FFFFFF"
                readonly property real tw: index % 3 === 0 ? root._tw0 : index % 3 === 1 ? root._tw1 : root._tw2
                readonly property real near: Math.max(0, 1 - Math.hypot(root.pointerAbsX - x, root.pointerAbsY - y) / 180)
                // Koyuda gece yıldızları sabah söner; açıkta alacakaranlıkta ilk yıldızlar yalnız göğün üstünde belirir
                opacity: Math.min(1, (behindText ? 0.2 : 1) * (0.25 + 0.6 * tw + 0.5 * near + hit) * (root.dusk ? 0.7 * root.clamp01(root._dk * 2 - 1) * (y < root.height * 0.3 ? 1 : 0) : root.night))
                visible: opacity > 0.01
                // Yazı sütununun arkasındaki yıldızlar çok sönük (okunurluk)
                readonly property bool behindText: x > root.width * 0.3 && x < root.width * 0.7 && y > root.height * 0.08
                                                   && (root.contentBottom < 0 || y < root.contentBottom + 20)
                scale: (1 + 1.2 * near) * (root.reducedMotion ? 1 : 1 + 1.4 * hit)
            }
        }
        // Ay: sağ üstte hilal; sabah oldukça batar ve söner
        Item {
            id: moon
            readonly property real r: root.height * 0.032
            // Koyu: sağ üstteki ay batar. Açık: ay tepelerin arkasından doğar
            readonly property real _rise: root.clamp01((root._dk - 0.3) / 0.7)
            x: root.width * (root.dusk ? 0.86 : 0.8) - r
            y: root.dusk ? root.height * (0.66 + root._drop) + r - (root.height * (0.5 + root._drop) + r) * _rise - r
                         : root.height * (0.14 + 0.35 * root.p) - r
            width: r * 2; height: r * 2
            opacity: root.dusk ? 1 : Math.max(0, 1 - 1.4 * root.p) * (root.dark ? 1 : 0)
            // Dokunma etkisi: hale 1.5 sn genişleyip söner, ay hafifçe sallanır
            property real _halo: 0
            function poke() {
                haloAnim.restart();
                if (!root.reducedMotion) wobble.restart();
            }
            NumberAnimation { id: haloAnim; target: moon; property: "_halo"; from: 0; to: 1
                              duration: root.reducedMotion ? 400 : 1500; easing.type: Easing.OutQuad }
            SequentialAnimation {
                id: wobble
                NumberAnimation { target: moon; property: "rotation"; to: -8; duration: 250; easing.type: Easing.OutSine }
                NumberAnimation { target: moon; property: "rotation"; to: 6; duration: 500; easing.type: Easing.InOutSine }
                NumberAnimation { target: moon; property: "rotation"; to: 0; duration: 450; easing.type: Easing.InOutSine }
            }
            Rectangle {
                anchors.centerIn: parent
                width: moon.r * 4; height: width; radius: width / 2
                color: "#F4EBD8"
                visible: moon._halo > 0 && moon._halo < 1
                // Açık gök üstünde hale biraz daha görünür
                opacity: (1 - moon._halo) * (root.dusk ? 0.38 : 0.24)
                scale: root.reducedMotion ? 1 : 0.6 + moon._halo
            }
            // Hilal tek parça çizilir (örten disk yok; gök rengi değişse de iz kalmaz)
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: "transparent"; strokeWidth: -1
                    fillColor: "#F4EBD8"
                    startX: moon.r; startY: 0
                    PathArc { x: moon.r; y: moon.r * 2; radiusX: moon.r; radiusY: moon.r; direction: PathArc.Counterclockwise }
                    PathArc { x: moon.r; y: 0; radiusX: moon.r * (root.dusk ? 1.7 : 1.25); radiusY: radiusX; direction: PathArc.Clockwise }
                }
            }
        }
        // Kayan yıldız: ara ara kendiliğinden; göğe tıklayınca da tıklanan yerden
        Rectangle {
            id: shoot
            property real t: 1
            property real sx: 0
            property real sy: 0
            visible: t < 1
            width: root.width * 0.12; height: 2; radius: 1
            transformOrigin: Item.Right
            rotation: 18
            x: sx + t * root.width * 0.25 - width; y: sy + t * root.width * 0.25 * 0.32
            opacity: Math.sin(Math.PI * t)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: "#FFFFFF" }
            }
            NumberAnimation { id: shootAnim; target: shoot; property: "t"; from: 0; to: 1; duration: 900; easing.type: Easing.InQuad }
            function fire(px, py) { sx = px; sy = py; shootAnim.restart() }
        }
        Timer {
            interval: 7000; repeat: true; running: root.night > 0.3 && !root.reducedMotion
            onTriggered: shoot.fire(root.width * (0.15 + Math.random() * 0.5), root.height * (0.05 + Math.random() * 0.2))
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
            // Işık ufukta kalır, yukarı çıkıp yazının arkasına geçmez
            readonly property real cy: root.horizonY + root.height * 0.10 * (1 - root.p) + root.height * 0.02 * root.p
            readonly property real rx: root.width * (0.28 + 0.27 * root.p)
            readonly property real ry: root.height * (0.18 + 0.08 * root.p)
            // Son adımda bile yazı okunur kalsın diye ışığın en yüksek yoğunluğu sınırlı
            readonly property real op: (0.25 + 0.42 * root.p) * (1 + 0.15 * root._h)
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

    // ---- 2b. Güneş: ilk adımda tepelerin arkasında, ilerledikçe doğar ----
    readonly property real _sunR0: height * 0.055
    // Bitişten önceki yeri: tepelerin arkasından adım adım doğar
    readonly property real _baseY: height * (0.66 + _drop) + _sunR0 * (1.3 - 2.6 * p)
    function _bez(a, b, c, t) { return (1 - t) * (1 - t) * a + 2 * (1 - t) * t * b + t * t * c }
    readonly property real _f: Math.max(0, _fin)
    readonly property real sunR: _sunR0 * (finaleStyle === 0 ? 1 + 0.7 * _fin + 0.04 * _bob * _fin
                                         : finaleStyle === 1 ? 1 + 1.5 * _fin + 0.08 * _bob * _f
                                         : finaleStyle === 2 ? 1 + 0.9 * _f
                                         : finaleStyle === 3 ? 1 + 1.0 * _f + 0.04 * _bob * _f
                                         : calm ? 1 + 0.15 * _f
                                         : 1 + 1.3 * _f + 0.05 * _bob * _f)
    // 5–7 son yeri: tepelerin hemen üstü, ama içeriğin en az iki güneş boyu altında (yazı güneşin önünde kalmaz)
    readonly property real _calmY: Math.max(height * (0.66 + _drop) - _sunR0 * 1.2,
                                            contentBottom >= 0 ? contentBottom + _sunR0 * 2.2 : 0)
    readonly property real sunX: dusk ? width * (0.13 + 0.07 * _dk)
                               : finaleStyle === 0 ? width * (0.5 - 0.29 * _fin) + _bob * 10 * _fin
                               : finaleStyle === 3 ? _bez(width * 0.5, width * 0.12, width * 0.76, clamp01(_fin)) + _bob * 8 * _f
                               : finaleStyle === 5 ? width * (0.5 + 0.22 * _sx * _f)
                               : calm ? width * 0.5 + _bob * 6 * _f
                               : width * 0.5
    readonly property real sunY: dusk ? height * 0.2 + (height * (0.66 + _drop) + _sunR0 * 1.8 - height * 0.2) * _dk * _dk
                               : finaleStyle === 0 ? _baseY * (1 - _fin) + height * 0.24 * _fin + _bob * 12 * _fin
                               : finaleStyle === 3 ? _bez(_baseY, -height * 0.05, height * 0.25, clamp01(_fin)) + _bob * 10 * _f
                               : calm ? _baseY + (_calmY - _baseY) * _f + _bob * 5 * _f
                               : finaleStyle === 1 ? _baseY + (height * 0.30 - _baseY) * clamp01(_fin)
                               : finaleStyle === 2 ? _baseY + (height * 0.36 - _baseY) * _f + _bob * 6 * _f
                               : _baseY + (height * 0.34 - _baseY) * _f + _bob * 6 * _f
    readonly property color sunCore: dusk ? mix("#FFF8EA", "#FFC48A", _dk) : pal("#FFF3D6", "#FFF8EA")

    component Disc: Shape {
        id: disc
        property real r
        property color inner
        property color outer
        property real mid: 0.6
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"; strokeWidth: -1
            fillGradient: RadialGradient {
                centerX: root.sunX; centerY: root.sunY; focalX: centerX; focalY: centerY
                centerRadius: disc.r
                GradientStop { position: 0.0; color: disc.inner }
                GradientStop { position: disc.mid; color: disc.inner }
                GradientStop { position: 1.0; color: disc.outer }
            }
            PathAngleArc { centerX: root.sunX; centerY: root.sunY; radiusX: disc.r; radiusY: disc.r; startAngle: 0; sweepAngle: 360 }
        }
    }
    Item {
        anchors.fill: parent
        visible: root.sunStyle > 0
        opacity: root.dusk ? 1 : 0.35 + 0.65 * root.p
        // Işınlar (stil 2): ince, uzun, çok düşük opaklık; yavaşça döner
        Shape {
            id: rays
            visible: root.sunStyle === 2 || root.finaleStyle === 4 && root._f > 0.01
            opacity: root.sunStyle === 2 ? 1 : root._f
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            property real turn: 0
            NumberAnimation on turn { from: 0; to: 360; duration: 120000; loops: Animation.Infinite; running: rays.visible && !root.reducedMotion }
            ShapePath {
                strokeColor: "transparent"; strokeWidth: -1
                fillGradient: RadialGradient {
                    centerX: root.sunX; centerY: root.sunY; focalX: centerX; focalY: centerY
                    centerRadius: root.sunR * 9
                    GradientStop { position: 0.0; color: Qt.rgba(root.lightCore.r, root.lightCore.g, root.lightCore.b, 0.22) }
                    GradientStop { position: 1.0; color: Qt.rgba(root.lightCore.r, root.lightCore.g, root.lightCore.b, 0) }
                }
                PathMultiline {
                    paths: {
                        const out = [], n = 14, L = root.sunR * 9, w = 2.2 * Math.PI / 180;
                        for (let i = 0; i < n; i++) {
                            const a = (rays.turn + i * 360 / n) * Math.PI / 180;
                            out.push([Qt.point(root.sunX, root.sunY),
                                      Qt.point(root.sunX + L * Math.cos(a - w), root.sunY + L * Math.sin(a - w)),
                                      Qt.point(root.sunX + L * Math.cos(a + w), root.sunY + L * Math.sin(a + w)),
                                      Qt.point(root.sunX, root.sunY)]);
                        }
                        return out;
                    }
                }
            }
        }
        // Bitiş: güneşten yayılan ışık halkaları (her 3,2 sn'de bir, yavaşça söner)
        Repeater {
            model: 2
            Shape {
                id: ring
                required property int index
                anchors.fill: parent
                visible: root._fin > 0.01 && !root.calm
                preferredRendererType: Shape.CurveRenderer
                property real t: 0
                SequentialAnimation on t {
                    running: root.finale && !root.reducedMotion
                    loops: Animation.Infinite
                    PauseAnimation { duration: 900 + ring.index * 1600 }
                    NumberAnimation { from: 0; to: 1; duration: 2400; easing.type: Easing.OutCubic }
                    PauseAnimation { duration: 800 - ring.index * 800 + 1600 * (1 - ring.index) }
                }
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Qt.rgba(root.lightCore.r, root.lightCore.g, root.lightCore.b, 0.55 * Math.min(1, ring.t * 8) * (1 - ring.t) * Math.min(1, root._f))
                    strokeWidth: 2 + 3 * (1 - ring.t)
                    PathAngleArc { centerX: root.sunX; centerY: root.sunY
                                   radiusX: root.sunR * (1.1 + 4.5 * ring.t); radiusY: radiusX; startAngle: 0; sweepAngle: 360 }
                }
            }
        }
        // Hale ve disk. Fare güneşe yaklaştıkça hale biraz parlar (koyu modda sınırlı: göz kamaşmasın)
        Disc { r: root.sunR * (3.2 + 0.6 * Math.min(1, root._f) + 0.3 * root._bob * root._f); mid: 0.0
               inner: Qt.rgba(root.lightCore.r, root.lightCore.g, root.lightCore.b,
                              (root.dark ? 0.22 : 0.30) + (root.calm ? 0.14 * root._near * root._f : 0))
               outer: Qt.rgba(root.lightCore.r, root.lightCore.g, root.lightCore.b, 0) }
        // Işık patlaması: ekranı dolduran sıcak ışık, sonra çekilir
        Disc { visible: root._flash > 0.001; r: root.sunR * (1 + 22 * root._flash); mid: 0.25
               inner: Qt.rgba(root.sunCore.r, root.sunCore.g, root.sunCore.b, 0.85 * root._flash)
               outer: Qt.rgba(root.lightCore.r, root.lightCore.g, root.lightCore.b, 0) }
        Disc { r: root.sunR; mid: 0.82; inner: root.sunCore
               outer: Qt.rgba(root.lightCore.r, root.lightCore.g, root.lightCore.b, 0.85) }
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
        property real rim: 0            // sırt ışık gücü (0..1)
        property color rimColor: "#FFD9A0"

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
        readonly property real _rimH: 4
        readonly property real _sunLX: root.sunX - layer.x
        readonly property real _rimSpan: layer.w * 0.42
        readonly property color _rimZero: Qt.rgba(layer.rimColor.r, layer.rimColor.g, layer.rimColor.b, 0)

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
        // Sırt eğrisi boyunca sabit 4 px ışık şeridi (yalnız gradyan ve renk canlanır)
        ShapePath {
            strokeColor: "transparent"
            strokeWidth: -1
            fillGradient: LinearGradient {
                x1: layer._sunLX - layer._rimSpan; y1: 0
                x2: layer._sunLX + layer._rimSpan; y2: 0
                GradientStop { position: 0.0; color: layer._rimZero }
                GradientStop { position: 0.25; color: Qt.rgba(layer.rimColor.r, layer.rimColor.g, layer.rimColor.b, layer.rim * 0.4) }
                GradientStop { position: 0.5; color: Qt.rgba(layer.rimColor.r, layer.rimColor.g, layer.rimColor.b, layer.rim) }
                GradientStop { position: 0.75; color: Qt.rgba(layer.rimColor.r, layer.rimColor.g, layer.rimColor.b, layer.rim * 0.4) }
                GradientStop { position: 1.0; color: layer._rimZero }
            }
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
            PathLine { x: layer.w; y: layer.by - layer.a * (0.4 + layer.phase) + layer._rimH }
            PathCubic {
                x: layer.w * 0.68; y: layer.by + layer.a * 0.3 + layer._rimH
                control1X: layer.w * 0.90; control1Y: layer.by - layer.a * 1.1 + layer._rimH
                control2X: layer.w * 0.80; control2Y: layer.by - layer.a * 0.7 + layer._rimH
            }
            PathCubic {
                x: layer.w * 0.35; y: layer.by - layer.a * (0.6 + layer.phase) + layer._rimH
                control1X: layer.w * 0.56; control1Y: layer.by + layer.a * 0.9 + layer._rimH
                control2X: layer.w * 0.46; control2Y: layer.by + layer.a * 0.1 + layer._rimH
            }
            PathCubic {
                x: 0; y: layer.by + layer._rimH
                control1X: layer.w * 0.22; control1Y: layer.by - layer.a * 1.2 + layer._rimH
                control2X: layer.w * 0.12; control2Y: layer.by + layer.a * layer.phase + layer._rimH
            }
            PathLine { x: 0; y: layer.by }
        }
    }

    HillLayer {
        fillColor: root.hill0
        baseY: 0.66 + root._drop * 1.0; amp: 0.06; phase: 0.2; lineOpacity: 0.35
        shiftX: root._px * 4; shiftY: root._py * 2
        rim: root._rim * 0.9; rimColor: root._rimColor
    }
    HillLayer {
        fillColor: root.hill1
        baseY: 0.73 + root._drop * 0.85; amp: 0.055; phase: 0.5; lineOpacity: 0.40
        shiftX: root._px * 7; shiftY: root._py * 4
        rim: root._rim * 0.6; rimColor: root._rimColor
    }
    HillLayer {
        fillColor: root.hill2
        baseY: 0.81 + root._drop * 0.7; amp: 0.05; phase: 0.1; lineOpacity: 0.45
        shiftX: root._px * 10; shiftY: root._py * 7
        rim: root._rim * 0.35; rimColor: root._rimColor
    }
    HillLayer {
        fillColor: root.hill3
        baseY: 0.89 + root._drop * 0.55; amp: 0.04; phase: 0.35; lineOpacity: 0.50
        shiftX: root._px * 14; shiftY: root._py * 10
        rim: root._rim * 0.2; rimColor: root._rimColor
    }

    // ---- 3b. Kuşlar (6): güneş doğunca küçük bir sürü süzülerek geçer (yazının altındaki bantta) ----
    // Kuş: iki ince kanat dikdörtgeni; kanat çırpma yalnız döndürme (yol yeniden çizilmez, ucuz)
    // Kanat: omuzdan sağa uzanan iki parça (kol + uç tüyleri). Yollar sabit (yalnız s'ye bağlı),
    // çırpma yalnız döndürmeyle olur: her karede yeniden çizim yok.
    component Wing: Item {
        id: wing
        property real s: 14
        property real arm: 0     // kol açısı (derece, + aşağı)
        property real hand: 0    // uç parçanın kola göre açısı
        property color ink
        rotation: arm
        Shape {   // kol: kalın, ön kenarı kavisli
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1; fillColor: wing.ink
                startX: 0; startY: -0.07 * wing.s
                PathQuad { controlX: 0.26 * wing.s; controlY: -0.14 * wing.s; x: 0.5 * wing.s; y: -0.06 * wing.s }
                PathLine { x: 0.5 * wing.s; y: 0.05 * wing.s }
                PathQuad { controlX: 0.25 * wing.s; controlY: 0.11 * wing.s; x: 0; y: 0.09 * wing.s }
            }
        }
        Item {    // el: kolun ucundan döner, arka kenarında tüy dişleri
            x: 0.48 * wing.s
            rotation: wing.hand
            Shape {
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: -1; fillColor: wing.ink
                    startX: 0; startY: -0.06 * wing.s
                    PathQuad { controlX: 0.32 * wing.s; controlY: -0.1 * wing.s; x: 0.64 * wing.s; y: 0.03 * wing.s }
                    PathLine { x: 0.52 * wing.s; y: 0.045 * wing.s }
                    PathLine { x: 0.47 * wing.s; y: 0.025 * wing.s }
                    PathLine { x: 0.4 * wing.s; y: 0.065 * wing.s }
                    PathLine { x: 0.34 * wing.s; y: 0.04 * wing.s }
                    PathLine { x: 0.26 * wing.s; y: 0.08 * wing.s }
                    PathLine { x: 0.19 * wing.s; y: 0.055 * wing.s }
                    PathLine { x: 0.1 * wing.s; y: 0.085 * wing.s }
                    PathLine { x: 0; y: 0.06 * wing.s }
                }
            }
        }
    }
    component Bird: Item {
        id: bird
        property real s: 14
        property real phase: 0
        readonly property real a: flock.wing + phase
        readonly property real flap: 0.5 + 0.5 * Math.sin(a)                // 1 = kanatlar yukarıda
        readonly property real arm: 18 - 52 * flap                           // aşağı (+18°) ile yukarı (−34°) arası
        readonly property real hand: -6 + 22 * Math.cos(a)                  // uç, kolun gerisinden gelir (kırılan martı kanadı)
        // Saydam değil: parçalar üst üste binince koyu ek yeri çıkmasın
        readonly property color ink: root.dark ? "#C9D3E6" : "#2B3550"
        width: s * 2.4; height: s * 1.4
        Item {
            id: shoulder
            x: bird.width / 2; y: bird.height / 2
            // gövde çırpışla hafifçe iner kalkar
            transform: Translate { y: (bird.flap - 0.5) * 0.12 * bird.s }
            Wing { s: bird.s; ink: bird.ink; arm: bird.arm; hand: bird.hand }
            Wing { s: bird.s; ink: bird.ink; arm: bird.arm; hand: bird.hand
                transform: Scale { xScale: -1 } }
            Shape {   // gövde: baş öne-yukarı, kısa çatal kuyruk aşağıda
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: -1; fillColor: bird.ink
                    startX: 0; startY: -0.2 * bird.s
                    PathQuad { controlX: 0.1 * bird.s; controlY: -0.19 * bird.s; x: 0.09 * bird.s; y: -0.06 * bird.s }
                    PathQuad { controlX: 0.09 * bird.s; controlY: 0.12 * bird.s; x: 0.06 * bird.s; y: 0.2 * bird.s }
                    PathLine { x: 0.1 * bird.s; y: 0.3 * bird.s }
                    PathLine { x: 0; y: 0.24 * bird.s }
                    PathLine { x: -0.1 * bird.s; y: 0.3 * bird.s }
                    PathLine { x: -0.06 * bird.s; y: 0.2 * bird.s }
                    PathQuad { controlX: -0.09 * bird.s; controlY: 0.12 * bird.s; x: -0.09 * bird.s; y: -0.06 * bird.s }
                    PathQuad { controlX: -0.1 * bird.s; controlY: -0.19 * bird.s; x: 0; y: -0.2 * bird.s }
                }
            }
        }
    }
    Item {
        id: flock
        visible: root.finaleStyle === 6 && root._f > 0.5
        // Hareketi azalt: sürü göğün sol yarısında durağan, kanatlar açık
        property real t: root.reducedMotion ? 0.3 : 0
        property real wing: root.reducedMotion ? 1.2 : 0
        NumberAnimation on wing { from: 0; to: Math.PI * 2; duration: 760; loops: Animation.Infinite; running: flock.visible && !root.reducedMotion }
        readonly property real bandY: root.contentBottom >= 0 ? (root.contentBottom + root.sunY) / 2 - root.sunR : root.height * 0.45
        SequentialAnimation on t {
            loops: Animation.Infinite; running: flock.visible && !root.reducedMotion
            PauseAnimation { duration: 600 }
            NumberAnimation { from: 0; to: 1; duration: 16000; easing.type: Easing.Linear }
            PauseAnimation { duration: 5000 }
        }
        Repeater {
            model: [[0, 0, 22], [-60, -28, 18], [-92, 22, 16], [-140, -10, 14], [-190, 32, 13]]
            Bird {
                required property var modelData
                s: modelData[2]
                phase: modelData[0] * 0.05
                x: -200 + flock.t * (root.width + 400) + modelData[0]
                y: flock.bandY + modelData[1] + Math.sin(flock.t * 18 + modelData[0]) * 4
            }
        }
    }

    // ---- 3c. Parıltı (7): fare son sayfada iz bırakır; güneşin çevresinde ara ara küçük ışıltılar ----
    Component {
        id: sparkle
        Shape {
            id: sp
            property real size: 8
            property real life: 0
            property real cx: 0
            property real cy: 0
            x: cx - size
            y: cy - size - 18 * life
            width: size * 2; height: size * 2
            opacity: (1 - life) * (root.dark ? 0.8 : 0.9)
            scale: 0.4 + 0.8 * Math.sin(Math.PI * Math.min(1, life * 1.4))
            rotation: life * 90
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"; strokeWidth: -1
                fillColor: Qt.rgba(root.lightCore.r, root.lightCore.g, root.lightCore.b, 1)
                startX: sp.size; startY: 0
                PathQuad { x: sp.size * 2; y: sp.size; controlX: sp.size * 1.15; controlY: sp.size * 0.85 }
                PathQuad { x: sp.size; y: sp.size * 2; controlX: sp.size * 1.15; controlY: sp.size * 1.15 }
                PathQuad { x: 0; y: sp.size; controlX: sp.size * 0.85; controlY: sp.size * 1.15 }
                PathQuad { x: sp.size; y: 0; controlX: sp.size * 0.85; controlY: sp.size * 0.85 }
            }
            NumberAnimation on life { from: 0; to: 1; duration: 1100; easing.type: Easing.OutQuad
                                      onFinished: sp.destroy() }
        }
    }
    Item {
        id: sparkles
        anchors.fill: parent
        readonly property bool on: root.finaleStyle === 7 && root._f > 0.5 && !root.reducedMotion
        function spawn(cx, cy, size) {
            if (children.length > 40) return;
            sparkle.createObject(sparkles, { size: size, cx: cx, cy: cy });
        }
        property real lastX: -1; property real lastY: -1
        Timer {   // fare izi: hareket varsa her 70 ms'de bir
            interval: 70; repeat: true; running: sparkles.on
            onTriggered: {
                const x = root.pointerAbsX, y = root.pointerAbsY;
                if (Math.hypot(x - sparkles.lastX, y - sparkles.lastY) > 12) sparkles.spawn(x + (Math.random() - 0.5) * 14, y + (Math.random() - 0.5) * 14, 7 + Math.random() * 7);
                sparkles.lastX = x; sparkles.lastY = y;
            }
        }
        Timer {   // güneşin çevresinde
            interval: 420; repeat: true; running: sparkles.on
            onTriggered: {
                const a = Math.random() * Math.PI * 2, d = root.sunR * (1.4 + Math.random() * 1.8);
                sparkles.spawn(root.sunX + Math.cos(a) * d, root.sunY + Math.sin(a) * d * 0.8, 6 + Math.random() * 7);
            }
        }
    }

    // ---- 3d. Güneşe dokununca halka (5, 7) ----
    Shape {
        id: tapRing
        anchors.fill: parent
        property real t: 1
        visible: t < 1
        preferredRendererType: Shape.CurveRenderer
        NumberAnimation { id: tapAnim; target: tapRing; property: "t"; from: 0; to: 1; duration: 1400; easing.type: Easing.OutCubic }
        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.rgba(root.lightCore.r, root.lightCore.g, root.lightCore.b, 0.6 * (1 - tapRing.t))
            strokeWidth: 3 * (1 - tapRing.t) + 1
            PathAngleArc { centerX: root.sunX; centerY: root.sunY; radiusX: root.sunR * (1.1 + 3.5 * tapRing.t); radiusY: radiusX; sweepAngle: 360 }
        }
    }
    // Önce yıldız/ay vuruşu; vurulmadıysa yalnız koyuda kayan yıldız (tek işleyici → yarış yok)
    TapHandler {
        enabled: root.finaleStyle === 6 && (root.night > 0.02 || root.dusk && root._dk > 0.5)
        onTapped: (ev) => {
            if (sky.tapAt(ev.position.x, ev.position.y)) return;
            if (!root.dusk && root.night > 0.3 && ev.position.y < root.height * 0.6)
                shoot.fire(ev.position.x, ev.position.y)
        }
    }
    TapHandler {
        enabled: root.calm && root._f > 0.5
        onTapped: (ev) => {
            const q = ev.position;
            if (Math.hypot(q.x - root.sunX, q.y - root.sunY) < root.sunR * 2.2) {
                tapAnim.restart();
                if (root.finaleStyle === 7) for (let i = 0; i < 10; i++) {
                    const a = i / 10 * Math.PI * 2;
                    sparkles.spawn(root.sunX + Math.cos(a) * root.sunR * 1.8, root.sunY + Math.sin(a) * root.sunR * 1.8, 6);
                }
            }
        }
    }

    // ---- 3e. Çıkış ışık halkası (sabit geometri, yalnız scale + opacity) ----
    Shape {
        id: leaveRing
        width: 200
        height: 200
        x: root.sunX - width / 2
        y: root.sunY - height / 2
        transformOrigin: Item.Center
        opacity: 0
        scale: root.sunR / 96
        visible: opacity > 0
        preferredRendererType: Shape.CurveRenderer

        ParallelAnimation {
            id: leaveRingAnim
            NumberAnimation {
                target: leaveRing
                property: "scale"
                from: root.sunR / 96
                to: root.sunR * 6 / 96
                duration: 1500
                easing.type: Easing.OutCubic
            }
            SequentialAnimation {
                NumberAnimation { target: leaveRing; property: "opacity"; from: 0; to: 0.75; duration: 120; easing.type: Easing.OutQuad }
                NumberAnimation { target: leaveRing; property: "opacity"; from: 0.75; to: 0; duration: 1380; easing.type: Easing.OutQuad }
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.lightCore
            strokeWidth: 1
            PathAngleArc { centerX: 100; centerY: 100; radiusX: 96; radiusY: 96; sweepAngle: 360 }
        }
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
