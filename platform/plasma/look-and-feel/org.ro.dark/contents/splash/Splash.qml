// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick

Item {
    id: root
    width: 1920
    height: 1080

    // KSplash tarafından aşama bilgisi için doldurulur; animasyonda kullanılmaz
    property int stage: 0

    // Giriş ekranı kapandıktan sonra ani parlama olmasın diye siyahtan yumuşak giriş
    opacity: 0.0
    Component.onCompleted: fadeIn.start()

    NumberAnimation {
        id: fadeIn
        target: root
        property: "opacity"
        from: 0.0
        to: 1.0
        duration: 450
        easing.type: Easing.OutCubic
    }

    // 1) Alt zemin: görsel yüklenene kadar ekranı kaplayan koyu taban rengi
    Rectangle {
        anchors.fill: parent
        color: "#071018"
    }

    // 2) Bulanık arka plan görseli: oturum açılışında görsel süreklilik sağlayan durağan katman
    Image {
        anchors.fill: parent
        source: "wallpaper-blur.jpg"
        fillMode: Image.PreserveAspectCrop
        smooth: true
    }

    // 3) Karartma katmanı: arka plan parlaklığını dengeleyip merkezdeki animasyonu öne çıkarır
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.25
    }

    // 4) Merkez taşıyıcı: animasyon görselinin arkasında kontrast oluşturan yarı saydam yuvarlak kare
    Rectangle {
        anchors.centerIn: parent
        width: 260
        height: 260
        radius: 48
        color: "#80000000"
    }

    // 5) Açılış animasyonu: Plymouth temasındaki kareleri sırayla oynatan merkez görsel
    Image {
        id: throbber
        anchors.centerIn: parent
        width: 192
        height: 192
        smooth: true
        visible: status === Image.Ready

        property int currentFrame: 1
        source: "/usr/share/plymouth/themes/ro-theme/throbber-" + String(currentFrame).padStart(4, "0") + ".png"

        Timer {
            interval: 33
            running: true
            repeat: true
            onTriggered: {
                throbber.currentFrame = (throbber.currentFrame % 86) + 1
            }
        }
    }
}
