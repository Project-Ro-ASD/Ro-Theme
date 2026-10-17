# 3 · Kontroller

## Hazır bileşen kullanın

Ro'da uygulama kontrollerini **Breeze** çizer, renkleri Ro şemasından alır (04 · APP-01). Düğme, kaydırıcı, radyo,
onay kutusu, anahtar, açılır kutu, metin alanı ve sekme için hazır bileşeni kullanın:

| Kontrol | QML | Qt Widgets |
|---|---|---|
| Düğme | `QQC2.Button` | `QPushButton` |
| Kaydırıcı | `QQC2.Slider` | `QSlider` |
| Radyo / onay kutusu | `QQC2.RadioButton` / `QQC2.CheckBox` | `QRadioButton` / `QCheckBox` |
| Anahtar | `QQC2.Switch` | (yok; `QCheckBox`) |
| Açılır kutu | `QQC2.ComboBox` | `QComboBox` |
| Metin alanı | `QQC2.TextField`, `Kirigami.SearchField` | `QLineEdit` |
| Sekme | `QQC2.TabBar` + `QQC2.TabButton` | `QTabWidget` |
| Form | `Kirigami.FormLayout` | `QFormLayout` |

```qml
import QtQuick.Controls as QQC2
QQC2.Slider { from: 0; to: 100; value: 40 }
```

**Elle çizmeyin.** Kaydırıcıyı `Rectangle`'larla (oluk + dolgu + beyaz tutamak) yeniden çizmek; renkleri, odak halkasını,
klavye ve ekran okuyucu davranışını, sağdan sola düzeni ve ölçeği sizin sorumluluğunuza bırakır. Sistem Ayarları
uyarlamasında elle çizilmiş kontroller sabit renklerin en büyük kaynağıydı.

## Kart ve grup

Kart, şemada rolü olmayan bir yüzeydir (bkz. [01 · COL-33](01-renkler.md#rolü-olmayan-yüzeyler-02--col-33)):

```qml
Rectangle {   // içerik kartı
    Kirigami.Theme.colorSet: Kirigami.Theme.View
    color: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor,
                                                   Kirigami.Theme.textColor, RoTokens.opacityMixCard)
    radius: RoTokens.radiusMd
    // Kenar çizgisi ve gölge yok (00 §4.4, 01 · TOK-09): kart zemininden ayrışır.
}
```

Kirigami'nin `Kirigami.Card` / `Kirigami.AbstractCard` bileşenleri de temayı izler; görünümü yeterliyse onları kullanın.

Qt Widgets'ta `QGroupBox`'ı `.qss` ile beyaz karta çevirmeyin (koyu temada bozulur); grup ayrımı için Breeze yeterlidir.

## Hap düğme ve hap sekme

Ro'nun kabuk düğmesi köşesi **8**'dir (03 · PST-23), metin alanı da 8 (03 · PST-22). Bütün düğmeleri `radius: height / 2`
ile hap yapmak:

- düğmeyi yanındaki alanla uyumsuz yapar (giriş ekranında şifre alanı + düğme sorunu bu yüzden çıkmıştı),
- Breeze'in çizdiği diğer uygulamalarla tutarsız görünür,
- Breeze'in kendi QML bileşenlerini kopyalayıp değiştirmeyi gerektirir (bkz. [04](04-yapilmayacaklar.md)).

Hap biçim yalnızca **tek başına duran** öğeler için uygundur: etiket/çip (`Kirigami.Chip`), geri/ileri hap düğmesi
(Dolphin, `Button` renk seti). Sekmeler için `QQC2.TabBar` kullanın; Ro sekme çizgisini tema çizer (03 · PST-25).

Uygulamanızın bir bölümünde gerçekten farklı bir kontrol biçimi gerekiyorsa bunu uygulamada çözmeyin; tema sorumlusuna
iletin. Gerekiyorsa temaya eklenir ve bütün uygulamalar aynı biçimi alır.

## Odak ve klavye

Hazır kontroller klavye odağını Ro'nun odak halkasıyla gösterir. Kendi çizdiğiniz etkileşimli bir öğe varsa
`activeFocus` durumunda `Kirigami.Theme.focusColor` ile görünür bir halka çizin; yalnızca renkle (mavi kenar) ayrım
yapmayın, kalınlık da değişsin.
