// SPDX-FileCopyrightText: Project Ro-ASD
// SPDX-License-Identifier: GPL-3.0-or-later
// RoGreeting.qml: Ro kurulum sihirbazı tanıtım sayfası için çok dilli karşılama.
// Yalnız QtQuick kullanır; yazılımsal çizicide de çalışır (efekt/shader yok).
// Boyut sabittir: sözcük değişince kutu büyüyüp küçülmez, yazı aynı taban çizgisinde durur.
import QtQuick

Item {
    id: root

    property bool running: true
    property bool reducedMotion: false
    property color textColor: "white"
    property color accentColor: "#C9A86A"   // şafak altını
    property real fontPixelSize: 72

    // Karşılama sözcükleri (rtl: sağdan sola açılır)
    readonly property var words: [
        { t: "Merhaba" },  { t: "Hello" },     { t: "Hallo" },
        { t: "Bonjour" },  { t: "Hola" },      { t: "Ciao" },
        { t: "Olá" },      { t: "Привет" },    { t: "مرحبا", rtl: true },
        { t: "こんにちは" }, { t: "你好" },      { t: "안녕하세요" },
        { t: "Γεια σας" }, { t: "Salam" }
    ]

    property int idx: 0
    readonly property var cur: words[idx]
    readonly property bool rtl: cur.rtl === true
    property real reveal: 0         // silerek açılma ilerlemesi (0..1)
    property real lift: 6          // dikey süzülme (px)
    property real wordOpacity: 0
    property real maxW: 0           // en geniş sözcüğün genişliği

    // Her yazıda aynı: taban çizgisi ve çizgi konumu yazı tipinden değil punto boyutundan gelir
    readonly property real lineHeight: Math.round(fontPixelSize * 1.5)
    readonly property real textBaseline: Math.round(fontPixelSize * 1.12)

    implicitWidth: maxW + 48
    implicitHeight: lineHeight + 12

    Accessible.role: Accessible.StaticText
    Accessible.name: cur.t

    function showStatic() {
        if (reducedMotion) idx = 0;   // yalnız "Merhaba"
        reveal = 1; lift = 0; wordOpacity = 1;
    }
    onReducedMotionChanged: if (reducedMotion) showStatic()
    Component.onCompleted: if (reducedMotion || !running) showStatic()

    // Görünmez ölçüm: en geniş sözcük, genişliğin sözcükten sözcüğe değişmemesi için
    Repeater {
        model: root.words
        Text {
            visible: false
            text: modelData.t
            font.pixelSize: root.fontPixelSize
            font.weight: Font.Light
            onImplicitWidthChanged: root.maxW = Math.max(root.maxW, implicitWidth)
        }
    }

    Item {
        id: box
        width: root.maxW
        height: root.lineHeight
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.lift
        opacity: root.wordOpacity

        // Yalnız yazının kendi genişliği kadar açılır; kutu sabit kalır
        Item {
            id: wipe
            clip: true
            height: box.height
            width: word.implicitWidth * root.reveal
            x: root.rtl ? word.x + word.implicitWidth - width : word.x

            Text {
                x: word.x - wipe.x
                y: root.textBaseline - baselineOffset
                text: root.cur.t
                color: root.textColor
                font: word.font
            }
        }

        // Ölçü ve konum için görünmez kopya (ortalı)
        Text {
            id: word
            visible: false
            x: (box.width - implicitWidth) / 2
            text: root.cur.t
            font.pixelSize: root.fontPixelSize
            font.weight: Font.Light
        }

        // İnce altın çizgi: sözcükle birlikte uzar, her dilde aynı yükseklikte
        Rectangle {
            height: 2
            width: word.implicitWidth * root.reveal
            y: root.textBaseline + Math.round(root.fontPixelSize * 0.3)
            x: root.rtl ? word.x + word.implicitWidth - width : word.x
            color: root.accentColor
        }
    }

    // aç → bekle → sön → sıradaki sözcük
    SequentialAnimation {
        loops: Animation.Infinite
        running: !root.reducedMotion
        paused: !root.running

        ParallelAnimation {
            NumberAnimation { target: root; property: "reveal"; from: 0; to: 1; duration: 900; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "lift"; from: 6; to: 0; duration: 900; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "wordOpacity"; from: 0; to: 1; duration: 700; easing.type: Easing.OutCubic }
        }
        PauseAnimation { duration: 1800 }
        NumberAnimation { target: root; property: "wordOpacity"; to: 0; duration: 450; easing.type: Easing.InOutQuad }
        ScriptAction { script: root.idx = (root.idx + 1) % root.words.length }
    }
}
