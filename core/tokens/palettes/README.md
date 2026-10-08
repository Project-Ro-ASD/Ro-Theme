# Saklanan paletler

Ana tema `core/tokens/colors.light.json` / `colors.dark.json` dosyalarından üretilir (RoLight / RoDark).
Bu klasördeki her `<ad>.light.json` + `<ad>.dark.json` çifti, karşılaştırma ve geri dönüş için ayrıca
renk şeması olarak üretilir: `Ro<Ad>Light.colors`, `Ro<Ad>Dark.colors` (ör. `cool` → RoCoolLight / RoCoolDark).

- `cool`: logo renklerinden ilk palet (nötr soğuk griler + lacivert). "Çok soğuk" bulunduğu için ana temadan
  çıkarıldı, sıcak taş tonlu palet ana tema oldu.
- `stone`: sıcak taş tonlu ikinci palet. Kullanıcıya hâlâ "soğuk / uyku getiren" geldi (soluk, düşük doygunluk).
  Ana tema; logonun gri ailesine ve mavisine (ton ~220°) sadık kalıp daha canlı vurgu ve belirgin katman
  kontrastı kullanan palete geçti.
