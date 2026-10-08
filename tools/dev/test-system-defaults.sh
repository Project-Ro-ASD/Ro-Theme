#!/usr/bin/env bash
set -euo pipefail

# Sistem varsayılanları testi (Ro-Theme-Docs 22 SYS-10). Her senaryo temiz bir fedora:44 konteynerinde
# çalışır; makinedeki ayarlara dokunmaz.
#
#   1. Temiz kurulum: yeni kullanıcı Ro renklerini /etc/xdg'den okur, kullanıcı dosyası yazılmaz.
#   2. Kendi kdeglobals'ı olan kullanıcı: kurulum dosyasını değiştirmez.
#   3. Yöneticinin değiştirdiği /etc/xdg/kdeglobals yeniden kurulumda korunur.
#   4. Eski sürümden yükseltme (SYS-08): autostart kalkar, yeni varsayılanlar gelir, kullanıcı dosyası değişmez.
#
# Paketler bağımlılıksız (--nodeps) kurulur: test yalnızca dosya ve betik davranışına bakar. Ayar okumak için
# test imajına kf6-kconfig kurulur (eski sürümün %post'u da kwriteconfig6 kullanıyordu).
#
# Kullanım: tools/dev/test-system-defaults.sh YENI.rpm [ESKI.rpm]

NEW_RPM="${1:-}"
OLD_RPM="${2:-}"
BASE_IMAGE="${RO_THEME_TEST_BASE:-registry.fedoraproject.org/fedora:44}"
IMAGE="localhost/ro-theme-defaults-test:f44"

if [[ -z "$NEW_RPM" || ! -f "$NEW_RPM" ]]; then
  echo "Usage: $0 NEW.rpm [OLD.rpm]" >&2
  exit 2
fi
command -v podman >/dev/null 2>&1 || { echo "podman not found" >&2; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cp "$NEW_RPM" "$WORK/new.rpm"
[[ -n "$OLD_RPM" ]] && cp "$OLD_RPM" "$WORK/old.rpm"

cat > "$WORK/scenario.sh" <<'EOS'
#!/usr/bin/env bash
set -u
fails=0
pass() { printf '  [PASS] %s\n' "$1"; }
fail() { printf '  [FAIL] %s\n' "$1"; fails=$((fails + 1)); }
as_user() { local u="$1"; shift; runuser -u "$u" -- env HOME="/home/$u" XDG_CONFIG_DIRS=/etc/xdg "$@"; }
sysval() { awk -v g="[$1]" -v k="$2" '$0 == g { s = 1; next } /^\[/ { s = 0 } s && index($0, k "=") == 1 { print substr($0, length(k) + 2); exit }' /etc/xdg/kdeglobals; }


case "$1" in
  clean)
    rpm -i --nodeps /work/new.rpm >/dev/null 2>&1 || fail "install new package"
    useradd -m yeni
    [[ "$(as_user yeni kreadconfig6 --file kdeglobals --group General --key ColorScheme)" == "RoDark" ]] \
      && pass "new user reads ColorScheme=RoDark from /etc/xdg" || fail "new user ColorScheme is not RoDark"
    want="$(sysval Colors:View BackgroundNormal)"
    got="$(as_user yeni kreadconfig6 --file kdeglobals --group Colors:View --key BackgroundNormal)"
    [[ -n "$want" && "$got" == "$want" ]] && pass "new user reads Ro view color ($got) from /etc/xdg" || fail "new user view color '$got' != '$want'"
    [[ ! -e /home/yeni/.config/kdeglobals ]] && pass "no user kdeglobals written" || fail "user kdeglobals was written"
    [[ ! -e /etc/xdg/autostart/ro-theme-dark-defaults.desktop ]] && pass "no autostart entry" || fail "autostart entry exists"
    [[ -z "$(rpm -V ro-theme 2>/dev/null | grep '/etc/xdg/')" ]] && pass "/etc/xdg files unchanged after %post" || fail "%post modified /etc/xdg: $(rpm -V ro-theme | grep /etc/xdg/)"
    ;;
  user-own)
    useradd -m kendi
    install -d -o kendi /home/kendi/.config
    printf '[General]\nColorScheme=BreezeClassic\n\n[KDE]\nSingleClick=true\n' > /home/kendi/.config/kdeglobals
    before="$(sha256sum /home/kendi/.config/kdeglobals)"
    rpm -i --nodeps /work/new.rpm >/dev/null 2>&1 || fail "install new package"
    [[ "$(sha256sum /home/kendi/.config/kdeglobals)" == "$before" ]] && pass "existing user kdeglobals unchanged" || fail "existing user kdeglobals changed"
    [[ "$(as_user kendi kreadconfig6 --file kdeglobals --group General --key ColorScheme)" == "BreezeClassic" ]] \
      && pass "user's own ColorScheme wins over /etc/xdg" || fail "user's own ColorScheme lost"
    ;;
  admin-edit)
    rpm -i --nodeps /work/new.rpm >/dev/null 2>&1 || fail "install new package"
    printf '\n[Ro-Test]\nAdminKey=1\n' >> /etc/xdg/kdeglobals
    rpm -Uvh --replacepkgs --nodeps /work/new.rpm >/dev/null 2>&1 || fail "reinstall new package"
    grep -q '^AdminKey=1$' /etc/xdg/kdeglobals && pass "admin change in /etc/xdg/kdeglobals kept" || fail "admin change lost"
    ;;
  upgrade)
    useradd -m eski
    rpm -i --nodeps /work/old.rpm >/dev/null 2>&1 || fail "install old package"
    echo "  [INFO] old package files modified by its own %post: $(rpm -V ro-theme 2>/dev/null | grep -c '/etc/xdg/')"
    user_before="$(cat /home/eski/.config/kdeglobals 2>/dev/null | sha256sum)"
    rpm -Uvh --nodeps /work/new.rpm >/dev/null 2>&1 || fail "upgrade to new package"
    [[ ! -e /etc/xdg/autostart/ro-theme-dark-defaults.desktop ]] && pass "autostart entry removed on upgrade" || fail "autostart entry left behind"
    if grep -q '^\[Colors:View\]' /etc/xdg/kdeglobals; then
      pass "upgraded /etc/xdg/kdeglobals has the new full color scheme"
    else
      fail "upgraded /etc/xdg/kdeglobals kept the old content (new one: $(ls /etc/xdg/kdeglobals.rpmnew 2>/dev/null || echo none))"
    fi
    [[ "$(cat /home/eski/.config/kdeglobals 2>/dev/null | sha256sum)" == "$user_before" ]] && pass "user files untouched by the upgrade" || fail "upgrade changed user files"
    ;;
esac
exit "$fails"
EOS
chmod +x "$WORK/scenario.sh"

# Test araçları (kreadconfig6, runuser, useradd) bir kez kurulu yerel imaj; senaryolar bu imajdan başlar.
if ! podman image exists "$IMAGE" || [[ "${RO_THEME_TEST_REBUILD:-0}" == "1" ]]; then
  echo "Preparing test image $IMAGE (one time)..."
  printf 'FROM %s\nRUN dnf -y install kf6-kconfig util-linux shadow-utils && dnf clean all\n' "$BASE_IMAGE" \
    | podman build -q -t "$IMAGE" -f - "$WORK" >/dev/null
fi

total=0
for scenario in clean user-own admin-edit upgrade; do
  if [[ "$scenario" == "upgrade" && -z "$OLD_RPM" ]]; then
    echo "== $scenario: skipped (no OLD.rpm given)"
    continue
  fi
  echo "== $scenario"
  set +e
  podman run --rm -v "$WORK:/work:Z" "$IMAGE" /work/scenario.sh "$scenario"
  status=$?
  set -e
  total=$((total + status))
done

echo
if [[ "$total" -eq 0 ]]; then
  echo "System defaults test passed."
else
  echo "System defaults test failed: $total check(s)." >&2
  exit 1
fi
