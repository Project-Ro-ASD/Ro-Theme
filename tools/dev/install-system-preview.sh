#!/usr/bin/env bash
set -euo pipefail


if [[ $EUID -ne 0 ]]; then
  echo "This script must be run with sudo: sudo ./tools/dev/install-system-preview.sh"
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

run_optional() {
  local label="$1"
  shift
  local output
  local status

  set +e
  output="$("$@" 2>&1)"
  status=$?
  set -e

  if [[ "$status" -ne 0 ]]; then
    echo "Warning: $label failed with status $status" >&2
    [[ -n "$output" ]] && echo "$output" >&2
    return 1
  fi

  return 0
}

echo "Installing Ro Plasma Login Manager and Plymouth system preview..."

mkdir -p /usr/share/ro-theme/wallpapers \
  /usr/lib/plasmalogin/plasmalogin.conf.d \
  /usr/share/plymouth/themes
rm -rf /usr/share/plymouth/themes/ro-theme

install -m0644 assets/wallpapers/loginv2.jpg /usr/share/ro-theme/wallpapers/login.jpg
install -m0644 platform/plasmalogin/20-ro-theme.conf \
  /usr/lib/plasmalogin/plasmalogin.conf.d/20-ro-theme.conf
cp -r platform/plymouth/ro-theme /usr/share/plymouth/themes/

# Plymouth script zip dosyasını doğrudan okuyamaz.
# Bu yüzden frame'ler sistem tema klasöründe animation/ altına açılır.
if [[ -f /usr/share/plymouth/themes/ro-theme/animation.zip ]]; then
  rm -rf /usr/share/plymouth/themes/ro-theme/animation
  mkdir -p /usr/share/plymouth/themes/ro-theme/animation
  TMP_DIR="$(mktemp -d)"
  if command -v unzip >/dev/null 2>&1; then
    unzip -q /usr/share/plymouth/themes/ro-theme/animation.zip -d "$TMP_DIR"

    # Yeni paket animation/frame_0001.png şeklindedir.
    # Eski paket ro-plymouth-frames/frame_0001.png şeklindeydi.
    # İkisi de desteklenir ki eski ara sürümler patlamasın.
    if compgen -G "$TMP_DIR/animation/frame_*.png" > /dev/null; then
      cp "$TMP_DIR"/animation/frame_*.png /usr/share/plymouth/themes/ro-theme/animation/
    elif compgen -G "$TMP_DIR/ro-plymouth-frames/frame_*.png" > /dev/null; then
      cp "$TMP_DIR"/ro-plymouth-frames/frame_*.png /usr/share/plymouth/themes/ro-theme/animation/
    else
      echo "No Plymouth animation frames found inside animation.zip." >&2
    fi
    rm -rf "$TMP_DIR"
  else
    echo "unzip not found; Plymouth animation frames were not extracted." >&2
  fi
fi

chmod -R a+rX /usr/share/ro-theme/wallpapers/login.jpg \
  /usr/lib/plasmalogin/plasmalogin.conf.d/20-ro-theme.conf \
  /usr/share/plymouth/themes/ro-theme

# Eski paketlerden kalmış /etc/xdg/kdeglobals [KDE] ColorScheme değeri,
# kullanıcı Colors ekranından light/dark seçince stale kalıp paleti karıştırabilir.
if [[ -f /etc/xdg/kdeglobals ]]; then
  if command -v kwriteconfig6 >/dev/null 2>&1; then
    kwriteconfig6 --file /etc/xdg/kdeglobals --group KDE --key ColorScheme --delete "" || true
  elif command -v kwriteconfig5 >/dev/null 2>&1; then
    kwriteconfig5 --file /etc/xdg/kdeglobals --group KDE --key ColorScheme --delete "" || true
  fi
fi

# Fedora/Ro boot animasyonunun GRUB sonrası görünmesi için rhgb quiet gerekir.
# Bu komut hata verirse kurulumu durdurmayız; kullanıcı komutu elle çalıştırabilir.
if command -v grubby >/dev/null 2>&1; then
  run_optional "grubby rhgb quiet update" grubby --update-kernel=ALL --args="rhgb quiet" || true
fi

# MSI/anakart logosu firmware/BGRT tarafındadır; script modülü bunu garanti edemez.
# Ro Plymouth teması tam ekran wallpaper çizmez; küçük loading animasyonu kullanır.
if command -v plymouth-set-default-theme >/dev/null 2>&1; then
  run_optional "plymouth theme activation" plymouth-set-default-theme ro-theme -R || true
elif [[ -x /usr/libexec/plymouth/plymouth-set-default-theme ]]; then
  run_optional "plymouth theme activation" /usr/libexec/plymouth/plymouth-set-default-theme ro-theme -R || true
else
  echo "plymouth-set-default-theme not found; Plymouth files were copied only." >&2
fi

# Fedora'da initramfs güncellemesi garanti olsun.
if command -v dracut >/dev/null 2>&1; then
  run_optional "dracut initramfs regeneration" dracut -f --regenerate-all || true
fi

echo "System preview installed. Reboot to test Plasma Login Manager and boot screen."
echo "Debug command: ./scripts/diagnose.sh"
