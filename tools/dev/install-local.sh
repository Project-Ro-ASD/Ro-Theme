#!/usr/bin/env bash
set -euo pipefail

# Ro local kurulum scripti
# Kullanıcı dizinine kurulum yapar.
# SDDM ve Plymouth gibi sistem bileşenleri için ayrıca install-system-preview.sh çalıştırılır.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

./scripts/generate-theme.sh
./scripts/validate.sh

echo "Installing Ro Desktop locally..."

for writable_dir in "$HOME/.local/share" "$HOME/.themes"; do
  mkdir -p "$writable_dir"
  if [[ ! -w "$writable_dir" ]]; then
    echo "Cannot write to $writable_dir" >&2
    echo "Fix ownership/permissions, then rerun this script:" >&2
    echo "  sudo chown -R \"$USER:$USER\" \"$HOME/.local\" \"$HOME/.themes\"" >&2
    exit 1
  fi
done

mkdir -p \
  "$HOME/.local/share/color-schemes" \
  "$HOME/.local/share/plasma/desktoptheme" \
  "$HOME/.local/share/plasma/look-and-feel" \
  "$HOME/.local/share/plasma/layout-templates" \
  "$HOME/.local/share/ro-theme/wallpapers" \
  "$HOME/.local/share/wallpapers" \
  "$HOME/.local/share/kwin/effects" \
  "$HOME/.themes" \
  "$HOME/.local/share/icons"

# Eski Ro kalıntıları temizlenir.
# Bu adım bozuk wallpaper klasörlerini ve eski KWin efektini de kaldırır.
rm -rf "$HOME/.local/share/plasma/desktoptheme/Ro" \
       "$HOME/.local/share/plasma/desktoptheme/RoLight" \
       "$HOME/.local/share/plasma/desktoptheme/RoDark" \
       "$HOME/.local/share/plasma/look-and-feel/org.ro.global" \
       "$HOME/.local/share/plasma/look-and-feel/org.ro.light" \
       "$HOME/.local/share/plasma/look-and-feel/org.ro.dark" \
       "$HOME/.local/share/plasma/layout-templates/org.ro.desktop" \
       "$HOME/.local/share/wallpapers/Ro" \
       "$HOME/.local/share/wallpapers/RoLight" \
       "$HOME/.local/share/wallpapers/RoDark" \
       "$HOME/.local/share/wallpapers/dark" \
       "$HOME/.local/share/wallpapers/light" \
       "$HOME/.local/share/ro-theme/wallpapers" \
       "$HOME/.local/share/kwin/effects/ro-smooth-motion" \
       "$HOME/.themes/Ro-GTK" \
       "$HOME/.local/share/icons/ro-icons" \
       "$HOME/.local/share/icons/ro-cursor"

rm -f "$HOME/.local/share/wallpapers/dark.jpg" \
      "$HOME/.local/share/wallpapers/light.jpg" \
      "$HOME/.local/share/wallpapers/Ro Dark.jpg" \
      "$HOME/.local/share/wallpapers/Ro Light.jpg"

mkdir -p "$HOME/.local/share/ro-theme/wallpapers" "$HOME/.local/share/wallpapers"

cp platform/plasma/color-schemes/RoLight.colors "$HOME/.local/share/color-schemes/"
cp platform/plasma/color-schemes/RoDark.colors "$HOME/.local/share/color-schemes/"

# Wallpaper dosyaları iki yere kopyalanır:
# 1) Ro scriptlerinin sabit beklediği klasör
# 2) KDE ayarlarında düzgün isimle görünecek genel wallpaper klasörü
cp assets/wallpapers/light.jpg "$HOME/.local/share/ro-theme/wallpapers/light.jpg"
cp assets/wallpapers/dark.jpg "$HOME/.local/share/ro-theme/wallpapers/dark.jpg"
cp assets/wallpapers/light.jpg "$HOME/.local/share/wallpapers/Ro Light.jpg"
cp assets/wallpapers/dark.jpg "$HOME/.local/share/wallpapers/Ro Dark.jpg"

cp -r platform/plasma/desktoptheme/RoLight "$HOME/.local/share/plasma/desktoptheme/"
cp -r platform/plasma/desktoptheme/RoDark "$HOME/.local/share/plasma/desktoptheme/"
cp -r platform/plasma/look-and-feel/org.ro.light "$HOME/.local/share/plasma/look-and-feel/"
cp -r platform/plasma/look-and-feel/org.ro.dark "$HOME/.local/share/plasma/look-and-feel/"
cp -r platform/plasma/layout-templates/org.ro.desktop "$HOME/.local/share/plasma/layout-templates/"
cp -r platform/kwin/effects/ro-smooth-motion "$HOME/.local/share/kwin/effects/"
cp -r platform/gtk/Ro-GTK "$HOME/.themes/"
cp -r platform/icons/ro-icons "$HOME/.local/share/icons/" || true
cp -r platform/cursor/ro-cursor "$HOME/.local/share/icons/" || true

# KWin JavaScript efekti crash riskinden dolayı varsayılan olarak kayıt edilmez.
# Denemek gerekirse apply-theme.sh --enable-kwin-effect ile ayrı test edilir.

chmod +x scripts/*.sh tools/dev/*.sh

# Varsayılan kurulum dark yapılır; light için apply-theme.sh light yeterli.
if ! apply_output="$(./tools/dev/apply-theme.sh dark 2>&1)"; then
  echo "Local files were installed, but applying the active KDE theme failed." >&2
  echo "$apply_output" >&2
  echo "Run ./scripts/diagnose.sh for a fuller report." >&2
fi

echo "Local install complete."
echo "Recommended test:"
echo "  ./tools/dev/apply-theme.sh dark"
echo "  ./tools/dev/test-local-safe.sh"
echo "  ./scripts/diagnose.sh --local"
echo "Optional after Plasma runtime preflight passes:"
echo "  lookandfeeltool -a org.ro.dark"
echo "  ./tools/dev/test-layout.sh"
echo "System login/boot preview:"
echo "  sudo ./tools/dev/install-system-preview.sh"
