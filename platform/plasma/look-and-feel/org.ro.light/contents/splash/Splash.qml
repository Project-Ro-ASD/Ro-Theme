import QtQuick 2.15

// Ro login sonrası geçiş ekranı.
// KDE'nin stok dönen/şişen splash animasyonunu kullanmıyoruz.
// Amaç: giriş yöneticisinden masaüstüne geçerken önce blur bir yüzey göstermek,
// sonra bu yüzeyi yavaşça azaltıp masaüstünü sakin şekilde ortaya çıkarmak.
// Not: KWin başlamadan önce gerçek masaüstü arkasına blur verilemez.
// Bu yüzden burada login wallpaper'ın önceden blur'lanmış hali kullanılır.
// KWin açıldıktan sonra ro-smooth-motion efekti pencere geçişlerini sakinleştirir.
Item {
    id: root
    width: 1920
    height: 1080
    opacity: 1.0
    property int stage: 0
    property bool fadeStarted: false

    function startFade() {
        if (fadeStarted) {
            return
        }

        fadeStarted = true
        fadeOutAnimation.start()
    }

    onStageChanged: {
        if (stage >= 5) {
            startFade()
        }
    }

    Component.onCompleted: fallbackFadeTimer.start()

    Rectangle {
        anchors.fill: parent
        color: "#071018"
    }

    Image {
        anchors.fill: parent
        source: "login-blur.jpg"
        fillMode: Image.PreserveAspectCrop
        opacity: 1.0
        smooth: true
    }

    // İnce karartma katmanı, blur görselin fazla parlak kalmasını engeller.
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.18
    }

    // Küçük nefes efekti; KDE'nin stok animasyonu gibi dikkat çekmez.
    Rectangle {
        id: pulse
        width: 74
        height: 4
        radius: 2
        color: "#92C7CF"
        opacity: 0.42
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.max(70, parent.height * 0.08)

        SequentialAnimation on opacity {
            loops: Animation.Infinite
            NumberAnimation { from: 0.22; to: 0.58; duration: 700; easing.type: Easing.InOutQuad }
            NumberAnimation { from: 0.58; to: 0.22; duration: 700; easing.type: Easing.InOutQuad }
        }
    }

    // Normalde Plasma stage 5'e geldiğinde kapanır; stage sinyali gelmezse takılı kalmasın.
    Timer {
        id: fallbackFadeTimer
        interval: 8000
        repeat: false
        onTriggered: root.startFade()
    }

    SequentialAnimation {
        id: fadeOutAnimation
        running: false
        NumberAnimation {
            target: root
            property: "opacity"
            from: 1.0
            to: 0.0
            duration: 1350
            easing.type: Easing.OutCubic
        }
    }
}
