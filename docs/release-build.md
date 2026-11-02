# Sürüm çıkarma

1. `release/vX.Y.Z` dalı aç; `VERSION` dosyasını ve `packaging/ro-theme.spec` içindeki `Version` ile
   `%changelog` girdisini güncelle, `./ro generate` çalıştır (metadata sürümleri güncellenir).
2. `make check` ve `make test` temiz olmalı. PR aç; `Fedora 44 RPM CI` yeşil olunca birleştir.
3. Birleşen `main` commit'inde `vX.Y.Z` etiketini at ve yalnız etiketi gönder.
4. `.github/workflows/release.yml` RPM ve SRPM'i derler, `SHA256SUMS` ile
   `component-artifact-manifest-v1.json` dosyasını üretir, attest eder ve sürümü taslaktan yayına alır.
   Sürümler değiştirilemez (immutable): yayınlanmış bir etiket asla silinmez ya da yeniden atılmaz;
   hata varsa yeni sürüm çıkarılır.
5. Ro-Repo, `Project-Ro-ASD/Ro-Theme` deposunu ve `release.yml` yolunu tanır; yayını oradan alır.
