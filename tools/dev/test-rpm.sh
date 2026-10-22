#!/usr/bin/env bash
set -euo pipefail

# Oluşturulmuş Ro RPM dosyasını kurmadan önce denetler.
# Hata olursa komut, çıkış kodu ve yakalanan çıktı birlikte gösterilir.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RPM_PATH=""
VERIFY_INSTALLED=0

usage() {
  echo "Usage: $0 [RPM_PATH] [--verify-installed]"
  echo "Without RPM_PATH, test the newest ro-theme noarch RPM across build/rpmbuild/RPMS and ~/rpmbuild/RPMS."
}

for arg in "$@"; do
  case "$arg" in
    --verify-installed) VERIFY_INSTALLED=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Unknown argument: $arg" >&2; usage >&2; exit 2 ;;
    *)
      if [[ -n "$RPM_PATH" ]]; then
        echo "Only one RPM path may be supplied." >&2
        usage >&2
        exit 2
      fi
      RPM_PATH="$arg"
      ;;
  esac
done

# Göreli yol çağıranın çalışma dizinine aittir; depoya cd edildikten sonra yorumlanmaz.
if [[ -n "$RPM_PATH" && "$RPM_PATH" != /* ]]; then
  RPM_PATH="$PWD/$RPM_PATH"
fi
cd "$ROOT"

errors=0

section() {
  printf '\n== %s ==\n' "$1"
}

pass() {
  printf '  [OK] %s\n' "$1"
}

fail() {
  printf '  [FAIL] %s\n' "$1" >&2
  errors=$((errors + 1))
}

latest_rpm() {
  local dirs=()
  local dir

  for dir in "$ROOT/build/rpmbuild/RPMS" "$HOME/rpmbuild/RPMS"; do
    [[ ! -d "$dir" ]] || dirs+=("$dir")
  done

  if (( ${#dirs[@]} )); then
    # İki dizinin adaylarını birlikte sırala; kaynak RPM'leri ve başka mimarileri seçme.
    find "${dirs[@]}" -type f -name 'ro-theme-*.noarch.rpm' -printf '%T@ %p\n' \
      | sort -n | tail -n 1 | sed 's/^[^ ]* //'
  fi
}

run_capture() {
  local label="$1"
  shift
  local output
  local status

  section "$label"
  printf '  command:'
  printf ' %q' "$@"
  printf '\n'

  set +e
  output="$("$@" 2>&1)"
  status=$?
  set -e

  if [[ "$status" -eq 0 ]]; then
    pass "$label"
    if [[ -n "$output" && "${RO_THEME_VERBOSE:-0}" = "1" ]]; then
      printf '%s\n' "$output"
    fi
    return 0
  fi

  fail "$label exited with status $status"
  if [[ -n "$output" ]]; then
    printf '%s\n' "$output" >&2
  else
    printf '  no output captured\n' >&2
  fi
  return 1
}

if [[ -z "$RPM_PATH" ]]; then
  RPM_PATH="$(latest_rpm)"
fi

if [[ -z "$RPM_PATH" || ! -f "$RPM_PATH" ]]; then
  usage >&2
  echo "RPM file not found. Supply a path or build a ro-theme noarch RPM under build/rpmbuild/RPMS or ~/rpmbuild/RPMS." >&2
  exit 2
fi

if ! command -v rpm >/dev/null 2>&1; then
  echo "rpm command not found; install rpm-build/rpm tools first." >&2
  exit 2
fi

section "RPM"
printf '  file: %s\n' "$RPM_PATH"

run_capture "Digest And Signature" rpm -K "$RPM_PATH" || true
run_capture "Package Metadata" rpm -qip "$RPM_PATH" || true

section "Required Fonts"
# Spec metni yerine üretilmiş paketin gerçek güçlü bağımlılıklarını sınar.
if requirements="$(rpm -qp --requires "$RPM_PATH" 2>&1)"; then
  for font_package in google-noto-sans-fonts google-noto-sans-mono-fonts rsms-inter-fonts; do
    if grep -Eq "^${font_package}([[:space:]]|$)" <<< "$requirements"; then
      pass "required font: $font_package"
    else
      fail "RPM must require $font_package; a weak dependency does not guarantee installation"
    fi
  done
else
  fail "RPM font requirements could not be read: $requirements"
fi

section "Payload Files"
payload="$(mktemp)"
payload_err="$(mktemp)"
if ! rpm -qlp "$RPM_PATH" > "$payload" 2> "$payload_err"; then
  fail "rpm -qlp could not read the payload"
  cat "$payload_err" >&2
fi

required_paths=(
  /usr/share/color-schemes/RoLight.colors
  /usr/share/color-schemes/RoDark.colors
  /usr/share/plasma/desktoptheme/RoLight/metadata.json
  /usr/share/plasma/desktoptheme/RoLight/colors
  /usr/share/plasma/desktoptheme/RoLight/plasmarc
  /usr/share/plasma/desktoptheme/RoDark/metadata.json
  /usr/share/plasma/desktoptheme/RoDark/colors
  /usr/share/plasma/desktoptheme/RoDark/plasmarc
  /usr/share/plasma/look-and-feel/org.ro.light/metadata.json
  /usr/share/plasma/look-and-feel/org.ro.dark/metadata.json
  /usr/share/plasma/look-and-feel/org.ro.light/contents/layouts/org.kde.plasma.desktop-layout.js
  /usr/share/plasma/look-and-feel/org.ro.dark/contents/layouts/org.kde.plasma.desktop-layout.js
  /usr/share/plasma/look-and-feel/org.ro.light/contents/lockscreen/assets/login.jpg
  /usr/share/plasma/look-and-feel/org.ro.dark/contents/lockscreen/assets/login.jpg
  /usr/share/ro-theme/wallpapers/light.jpg
  /usr/share/ro-theme/wallpapers/dark.jpg
  /usr/share/ro-theme/wallpapers/login.jpg
  /usr/share/wallpapers/RoLight/metadata.json
  /usr/share/wallpapers/RoLight/contents/images/1920x1080.jpg
  /usr/share/wallpapers/RoLight/contents/images/3840x2160.jpg
  /usr/share/wallpapers/RoDark/metadata.json
  /usr/share/wallpapers/RoDark/contents/images/1920x1080.jpg
  /usr/share/wallpapers/RoDark/contents/images/3840x2160.jpg
  /usr/share/plymouth/themes/ro-theme/ro-theme.plymouth
  /usr/lib/plasmalogin/plasmalogin.conf.d/20-ro-theme.conf
  /usr/bin/ro-theme-diagnose
  /usr/libexec/ro-theme/apply-dark-defaults
  /usr/libexec/ro-theme/check-plasma-runtime
  /etc/xdg/kdeglobals
  /etc/xdg/kcmfonts
  /usr/share/ro-theme/qml/RoTokens.qml
  /etc/xdg/breezerc
  /etc/xdg/plasmarc
  /etc/xdg/ksplashrc
  /etc/xdg/kscreenlockerrc
  /etc/xdg/kwinrc
)

for path in "${required_paths[@]}"; do
  if grep -Fxq "$path" "$payload"; then
    pass "$path"
  else
    fail "RPM payload missing $path"
  fi
done

forbidden_paths=(
  /usr/share/sddm/themes/Ro/Main.qml
  /etc/sddm.conf.d/10-ro-theme.conf
)

for path in "${forbidden_paths[@]}"; do
  if grep -Fxq "$path" "$payload"; then
    fail "RPM payload must not own Fedora 44 login-manager path $path"
  else
    pass "not packaged: $path"
  fi
done

rm -f "$payload" "$payload_err"

run_capture "Install Or Upgrade Transaction Test" rpm -Uvh --test --ignoresize "$RPM_PATH" || true

if [[ "$VERIFY_INSTALLED" -eq 1 ]]; then
  run_capture "Installed Package Verify" rpm -V ro-theme || true
fi

printf '\nRPM test summary: %d error(s)\n' "$errors"

if [[ "$errors" -ne 0 ]]; then
  echo "RPM test failed. The [FAIL] blocks above include the command output needed for debugging." >&2
  exit 1
fi

echo "RPM test passed."
