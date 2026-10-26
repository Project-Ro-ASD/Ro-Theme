import QtQuick 2.15

// Ro login sonrası geçiş ekranı.
// KDE'nin stok dönen/şişen splash animasyonunu kullanmıyoruz.
// Amaç: giriş yöneticisinden masaüstüne geçerken önce blur bir yüzey göstermek,
// sonra masaüstü hazır olunca ksplashqml kendiliğinden kapanır ve kapanışı KWin efekti (ro-login-reveal) oynatır:
// splash solar, masaüstü yukarı süzülüp yakınlaşır, panel kendi kenarından kayar.
// Arka plan (SPL-03 C): Ro'nun varsayılan duvar kâğıdının (temanın moduna göre) bulanığı + %25 karartma.
// Not: KWin başlamadan önce gerçek masaüstü arkasına blur verilemez.
// Bu yüzden duvar kâğıdının blur'lanmış hali önceden üretilir (wallpaper-blur.jpg).
// Gösterge (SPL-04b D): Plymouth açılışındaki Ro animasyonu, ekranın ortasında 192 px.
// İlerleme çubuğu yok; kareler ro-theme Plymouth paketinin throbber dizisidir (0001…0086, 33 ms'lik döngü).
Item {
    id: root
    width: 1920
    height: 1080

    // KSplash aşama numarası (1..6). Masaüstü hazır olunca (aşama 6) süreç kendiliğinden çıkar; kapanış animasyonu KWin'de
    // (ro-login-reveal). Yüzey animasyonu aşama ile doldurulmaz; numara yalnız bekleyiş boyunca bilgi olarak taşınır.
    property int stage: 0

    // Siyahtan yumuşak giriş: giriş ekranı kapandıktan sonraki siyah aralık ani bir parlamayla bitmesin.
    opacity: 0
    Component.onCompleted: fadeIn.start()
    NumberAnimation { id: fadeIn; target: root; property: "opacity"; from: 0; to: 1; duration: 450; easing.type: Easing.OutCubic }

    Rectangle {
        anchors.fill: parent
        color: "#071018"
    }

    // Duvar kâğıdı (SPL-03 C): durağan; yakınlaşma yok (SPL-04c B).
    Image {
        anchors.fill: parent
        source: "wallpaper-blur.jpg"
        fillMode: Image.PreserveAspectCrop
        smooth: true
    }

    // İnce karartma katmanı, blur görselin fazla parlak kalmasını engeller.
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.25
    }

    // Logonun arkasında şeffaf siyah yuvarlak kare (SPL-04d E).
    Rectangle { width: 260; height: 260; radius: 48; anchors.centerIn: parent; color: "#80000000" }

    // Ro animasyonu: Plymouth açılışıyla aynı 86 kare, ortada 192 px (SPL-04b D).
    // Kareler ro-theme Plymouth paketiyle /usr/share/plymouth/themes/ro-theme altına kurulur.
    // Kareler bulunamazsa görsel çizilmez, gösterge hiç görünmez.
    Image {
        id: throbber
        property int frame: 1
        width: 192
        height: 192
        anchors.centerIn: parent
        source: "/usr/share/plymouth/themes/ro-theme/throbber-" + ("000" + frame).slice(-4) + ".png"
        smooth: true
        visible: status === Image.Ready

        Timer {
            interval: 33
            running: true
            repeat: true
            onTriggered: throbber.frame = throbber.frame % 86 + 1
        }
    }
}