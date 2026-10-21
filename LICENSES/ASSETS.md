# Ro-Theme lisansları

Ro-Theme iki lisansla dağıtılır (Ro-Theme-Docs 23 · PKG-08). Telif sahibi: **Project Ro-ASD**.

| Ne | Lisans | Metin |
|---|---|---|
| Kod, üretici, doğrulayıcı, araçlar; üreticinin token'dan ürettiği SVG, QML ve ayar dosyaları (Plasma stili, Aurorae, renk şemaları, yerleşim betikleri, `/etc/xdg` varsayılanları) | `GPL-3.0-or-later` | [`LICENSE`](../LICENSE) |
| Elle hazırlanmış görseller (aşağıdaki liste) | `CC-BY-SA-4.0` | [`CC-BY-SA-4.0.txt`](CC-BY-SA-4.0.txt) |

## CC-BY-SA-4.0 görseller

Atıf: "© Project Ro-ASD, CC-BY-SA-4.0". Tasarımcılar "Designed by" sütununda anılır.

| Yol | İçerik | Designed by |
|---|---|---|
| `assets/brand/` | Ro logosu (v1'de Ro-Theme sahipliğinde; ileride ro-asd-branding'e taşınacak) | — |
| `assets/wallpapers/` | Masaüstü ve giriş duvar kâğıtları | — |
| `platform/plasma/look-and-feel/*/contents/splash/*.jpg` | Açılış ekranı görselleri | — |
| `platform/plasma/look-and-feel/*/contents/lockscreen/assets/` | Kilit ekranı görseli | — |
| `platform/plasma/look-and-feel/*/contents/previews/` | Global tema önizlemeleri (Ro masaüstü ekran görüntüsü) | — |
| `platform/plymouth/ro-theme/throbber-*.png` | Açılış animasyonu kareleri (parola alanı görselleri üreticiden, GPL) | — |
| `platform/grub/ro/` | GRUB teması: `bg.jpg` yapay zekâ üretimi (Z-Image Turbo, Apache-2.0 model; çıktı Ro'ya aittir), simgeler ve seçim hapı (`scripts/make-grub-assets.py`; Ro simgesi logodan), `NotoSans-*.pf2` Noto Sans'tan `grub2-mkfont` ile (OFL-1.1) | — |
| `platform/icons/ro-icons/` | Ro ikon teması (Dolphin seti) | — |
| `platform/cursor/ro-cursor/` | Ro imleci | — |

Yeni bir görsel eklenince bu tabloya yolu, içeriği ve tasarımcısı yazılır. Üçüncü taraf bir görsel kullanılacaksa
lisansı CC-BY-SA-4.0 ile uyumlu olmalı ve kaynağı bu dosyada belirtilmelidir.
