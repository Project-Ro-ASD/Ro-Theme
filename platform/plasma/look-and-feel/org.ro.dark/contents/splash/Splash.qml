import QtQuick 2.15

// Ro login sonrası geçiş ekranı.
// KDE'nin stok dönen/şişen splash animasyonunu kullanmıyoruz.
// Amaç: giriş yöneticisinden masaüstüne geçerken önce blur bir yüzey göstermek,
// sonra masaüstü hazır olunca ksplashqml kendiliğinden kapanır ve kapanışı KWin efekti (ro-login-reveal) oynatır:
// bu yüzey solarak büyür, masaüstü ve panel aynı anda yakınlaşıp yerine oturur.
// Not: KWin başlamadan önce gerçek masaüstü arkasına blur verilemez.
// Bu yüzden burada login wallpaper'ın önceden blur'lanmış hali kullanılır.
Item {
    id: root
    width: 1920
    height: 1080

    // KSplash aşama numarası (1..6). Masaüstü hazır olunca (aşama 6) süreç kendiliğinden çıkar; kapanış animasyonu KWin'de
    // (ro-login-reveal). Bu bileşen yalnız bekleme yüzeyini çizer.
    property int stage: 0

    // Siyahtan yumuşak giriş: giriş ekranı kapandıktan sonraki siyah aralık ani bir parlamayla bitmesin.
    opacity: 0
    Component.onCompleted: fadeIn.start()
    NumberAnimation { id: fadeIn; target: root; property: "opacity"; from: 0; to: 1; duration: 450; easing.type: Easing.OutCubic }

    Rectangle {
        anchors.fill: parent
        color: "#071018"
    }

    // Duvar kağıdı çok yavaş yakınlaşır (GPU ölçeklemesi, hafif); bekleme sırasında yüzey canlı görünür.
    Image {
        anchors.fill: parent
        source: "login-blur.jpg"
        fillMode: Image.PreserveAspectCrop
        smooth: true
        NumberAnimation on scale { from: 1.0; to: 1.05; duration: 6000; easing.type: Easing.OutQuad }
    }

    // İnce karartma katmanı, blur görselin fazla parlak kalmasını engeller.
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.18
    }

    // İlerleme çubuğu: KSplash aşamasıyla dolar, aşama değişmese de nefes alır.
    Rectangle {
        id: track
        width: 240
        height: 4
        radius: 2
        color: "#FFFFFF"
        opacity: 0.16
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.max(70, parent.height * 0.08)
    }

    Rectangle {
        id: fill
        height: track.height
        radius: track.radius
        color: "#92C7CF"
        anchors.left: track.left
        anchors.verticalCenter: track.verticalCenter
        width: track.width * Math.min(1, Math.max(0.1, root.stage / 6))
        Behavior on width { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

        SequentialAnimation on opacity {
            loops: Animation.Infinite
            NumberAnimation { from: 0.55; to: 1.0; duration: 700; easing.type: Easing.InOutQuad }
            NumberAnimation { from: 1.0; to: 0.55; duration: 700; easing.type: Easing.InOutQuad }
        }
    }
}
