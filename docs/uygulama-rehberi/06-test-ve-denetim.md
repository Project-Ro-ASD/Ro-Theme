# 6 · Test ve denetim

## Elle test: dört durum

Uygulamanızı bırakmadan önce şu dört durumda açın. Hepsinde metin okunur, yüzeyler birbirinden ayrışır, hiçbir öğe
"başka bir temadan gelmiş" gibi durmamalı.

| Durum | Nasıl | Neye bakılır |
|---|---|---|
| **Ro Açık ve Ro Koyu** | Sistem Ayarları → Görünüm → Global Tema → Ro Açık / Ro Koyu | Beyaz kart, siyah çizgi, okunmayan gri metin |
| **Başka vurgu rengi** | Sistem Ayarları → Renkler → vurgu rengi (ör. turuncu) | Mavi kalan her şey sabit renktir |
| **%150 ölçek** | Sistem Ayarları → Ekran → Ölçek 150 % | Ekrandan taşan pencere/popup, bulanık simge |
| **Büyük yazı tipi** | Sistem Ayarları → Yazı Tipleri → genel 13 pt | Kesilen ya da büyümeyen metin |

Uygulama açıkken değişikliklerin çoğu anında yansır; yansımıyorsa uygulamayı yeniden başlatıp yine bakın (tema
değişimini izlemiyorsanız bkz. [05](05-qt-widgets.md#tema-değişimini-izlemek)).

## Otomatik denetim: `ro-tema-denetim.py`

```sh
python3 ro-tema-denetim.py KAYNAK_KLASORU            # ayrıntılı
python3 ro-tema-denetim.py KAYNAK_KLASORU --ozet     # dosya başına sayılar
python3 ro-tema-denetim.py KAYNAK_KLASORU --uyari-hata   # köşe uyarıları da CI'ı düşürür
```

| Tür | Ne bulur |
|---|---|
| Hata | Sabit renk (`"#RRGGBB"`, sayısal `Qt.rgba`, `QColor("#…")`, `QColor(r, g, b)`, `Qt::white`...), `.qss` / `setStyleSheet`, Kvantum, Klassy, `LD_PRELOAD`, `QML_IMPORT_PATH`, sistem ayar dosyasına `kwriteconfig`, `/home/<ad>/` yolu |
| Uyarı | QML'de sayı olarak köşe (`radius: 12`); Ro ölçeği (0, 4, 8, 12, 18, 24) dışındaysa ayrıca belirtilir |

Hata varsa çıkış kodu 1'dir; CI'a eklenebilir. Ro-Theme'in ürettiği `RoTokens.qml` taranmaz.

### İstisna

Gerçek bir rengi göstermesi gereken satıra ya da hemen üstüne **sebebiyle** yazın:

```qml
// ro-tema: izin renk körlüğü önizlemesi gerçek renkleri gösterir
model: [{ name: i18n("Kırmızılar"), colors: ["#ef4444", "#f97316", "#eab308"] }]
```

Sebepsiz `ro-tema: izin` kabul edilmez. İstisna, kodu okuyanın "bu neden sabit?" sorusunu cevaplamalıdır.

### Örnek çıktı

Ro-KDE-SystemSettings (Ekim 2026, `main`):

```
[HATA] overrides/qml/kcm_access/ZoomMagnifier.qml: 24
[HATA] overrides/qml/kcm_notifications/main.qml: 22
...
[HATA] scripts/apply-overrides.sh: 6
  80: LD_PRELOAD (güncellemede sessizce bozulur)
...
Toplam: 340 hata (40 dosya), 150 uyarı (40 dosya)
```

Bu sayı bir başlangıç noktasıdır; en çok hata veren dosyalardan ve elle çizilmiş kontrollerden başlamak (bkz.
[03](03-kontroller.md)) sayıyı en hızlı düşürür.

## CI'a eklemek

GitHub Actions örneği (Fedora konteyneri gerekmez, yalnız Python 3):

```yaml
- name: Ro tema denetimi
  run: |
    curl -fsSL -o ro-tema-denetim.py \
      https://raw.githubusercontent.com/Project-Ro-ASD/Ro-Theme/main/docs/uygulama-rehberi/ro-tema-denetim.py
    python3 ro-tema-denetim.py .
```

Önce `--ozet` ile mevcut durumu görün; hataları temizledikten sonra CI'a ekleyin, yoksa her PR kırmızı olur.
