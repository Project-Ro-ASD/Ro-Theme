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

    // KSplash aşama numarası. Masaüstü hazır olunca (aşama 6) süreç kendiliğinden çıkar; kapanış animasyonu KWin'de
    // (ro-login-reveal). Bu bileşen yalnız bekleme yüzeyini çizer.
    property int stage: 0

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
}
