#!/usr/bin/env bash
set -euo pipefail

# Sistem varsayılanları testi (Ro-Theme-Docs 22 SYS-10). Her senaryo temiz bir fedora:44 konteynerinde
# çalışır; makinedeki ayarlara dokunmaz.
#
#   1. Temiz kurulum: yeni kullanıcı Ro renklerini /etc/xdg'den okur, kullanıcı dosyası yazılmaz.
#   2. Kendi kdeglobals'ı olan kullanıcı: kurulum dosyasını değiştirmez.
#   3. Yöneticinin değiştirdiği /etc/xdg/kdeglobals yeniden kurulumda korunur.
#   4. Eski sürümden yükseltme (SYS-08): autostart kalkar, yeni varsayılanlar gelir, kullanıcı dosyası değişmez.
#   5. Kaldırma (PKG-13): dosyalar gider, yöneticinin değiştirdiği /etc/xdg dosyası .rpmsave olarak kalır.
#   6. Bağımlılık çözümü (PKG-13, Ro-Repo dependency-solve): Fedora 44 depolarından, kurmadan.
#   7. Plymouth (16 · PLY-08/10): tema yalnız ilk kurulumda seçilir, initramfs yalnız tema dosyaları değişince ve bir
#      kez üretilir, başarılı üretimden sonra damga yazılır, aynı dosyalarla yeniden üretim yapılmaz, başarısız
#      üretim uyarır ve damga yazmaz (sonraki işlem yeniden dener), kullanıcının seçtiği tema güncellemede korunur,
#      kaldırınca varsayılana dönülür. initramfs üretimi gerçek değil; plymouth-update-initrd yerine çağrıları sayan
#      bir yer tutucu konur.
#   7b. Plymouth installroot: çalışan çekirdeğin modülleri kökte yokken (installroot, konteyner, imaj derlemesi)
#      dracut denenmez, "failed" uyarısı yerine bilgi notu çıkar, damga yazılmaz.
#   8. Eski sürümde yönetici tarafından düzenlenen dosya yükseltmede korunur; yeni varsayılan .rpmnew olur.
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
cp "$(dirname "${BASH_SOURCE[0]}")/check-rpm-dependencies.sh" "$WORK/check-rpm-dependencies.sh"
[[ -n "$OLD_RPM" ]] && cp "$OLD_RPM" "$WORK/old.rpm"

cat > "$WORK/scenario.sh" <<'EOS'
#!/usr/bin/env bash
set -u
fails=0
pass() { printf '  [PASS] %s\n' "$1"; }
fail() { printf '  [FAIL] %s\n' "$1"; fails=$((fails + 1)); }
as_user() { local u="$1"; shift; runuser -u "$u" -- env HOME="/home/$u" XDG_CONFIG_DIRS=/etc/xdg "$@"; }
rebuilds() { wc -l < /tmp/initrd.log 2>/dev/null || echo 0; }
# Test imajında plymouth-update-initrd gerçek dracut yerine çağrıyı /tmp/initrd.log'a yazar. Gerçek sistemde
# çalışan çekirdeğin modülleri vardır; konteynerde yoktur (installroot ile aynı durum), burada oluşturulur.
stub_initrd() { : > /tmp/initrd.log; mkdir -p "/lib/modules/$(uname -r)"; }
# initramfs üretimi başarısız olsun (dracut hatası yerine)
fail_initrd() { printf '#!/bin/sh\necho rebuild >> /tmp/initrd.log\nexit 1\n' > /usr/libexec/plymouth/plymouth-update-initrd; }
ok_initrd() { printf '#!/bin/sh\necho rebuild >> /tmp/initrd.log\n' > /usr/libexec/plymouth/plymouth-update-initrd; }
STAMP=/var/lib/ro-theme/plymouth.sha256
theme_sum() { cat /usr/share/plymouth/themes/ro-theme/* 2>/dev/null | sha256sum | cut -d' ' -f1; }
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
    printf '[General]\nforceFontDPI=120\n' > /home/kendi/.config/kcmfonts
    printf '[Windeco]\nDrawBackgroundGradient=true\n' > /home/kendi/.config/breezerc
    printf '[Theme]\nname=UserTheme\n' > /home/kendi/.config/plasmarc
    printf '[KSplash]\nTheme=UserSplash\n' > /home/kendi/.config/ksplashrc
    printf '[Greeter]\nWallpaperPlugin=UserWallpaper\n' > /home/kendi/.config/kscreenlockerrc
    printf '[org.kde.kdecoration2]\ntheme=UserDecoration\n' > /home/kendi/.config/kwinrc
    before="$(find /home/kendi -type f -print0 | sort -z | xargs -0 sha256sum)"
    rpm -i --nodeps /work/new.rpm >/dev/null 2>&1 || fail "install new package"
    [[ "$(find /home/kendi -type f -print0 | sort -z | xargs -0 sha256sum)" == "$before" ]] \
      && pass "all existing user files unchanged; no new user files written" || fail "user files changed by installation"
    [[ "$(as_user kendi kreadconfig6 --file kdeglobals --group General --key ColorScheme)" == "BreezeClassic" ]] \
      && pass "user's own ColorScheme wins over /etc/xdg" || fail "user's own ColorScheme lost"
    [[ "$(as_user kendi kreadconfig6 --file kcmfonts --group General --key forceFontDPI)" == "120" ]] \
      && pass "user's own DPI wins over /etc/xdg" || fail "user's own DPI lost"
    ;;
  admin-edit)
    rpm -i --nodeps /work/new.rpm >/dev/null 2>&1 || fail "install new package"
    printf '\n[Ro-Test]\nAdminKey=1\n' >> /etc/xdg/kdeglobals
    rpm -Uvh --replacepkgs --nodeps /work/new.rpm >/dev/null 2>&1 || fail "reinstall new package"
    grep -q '^AdminKey=1$' /etc/xdg/kdeglobals && pass "admin change in /etc/xdg/kdeglobals kept" || fail "admin change lost"
    ;;
  upgrade)
    useradd -m eski
    stub_initrd
    rpm -i --nodeps /work/old.rpm >/dev/null 2>&1 || fail "install old package"
    : > /tmp/initrd.log
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
    [[ "$(plymouth-set-default-theme)" == "ro-theme" ]] && pass "Plymouth theme still ro-theme after upgrade" || fail "Plymouth theme changed by upgrade"
    [[ "$(rebuilds)" == "1" ]] && pass "upgrade with new Plymouth files rebuilds initramfs once" || fail "upgrade rebuilt initramfs $(rebuilds) times (want 1)"
    ;;
  admin-upgrade)
    rpm -i --nodeps /work/old.rpm >/dev/null 2>&1 || fail "install old package"
    printf '\n[Ro-Test]\nAdminKey=1\n' >> /etc/xdg/kdeglobals
    before="$(sha256sum /etc/xdg/kdeglobals)"
    rpm -Uvh --nodeps /work/new.rpm >/dev/null 2>&1 || fail "upgrade to new package"
    [[ "$(sha256sum /etc/xdg/kdeglobals)" == "$before" ]] \
      && pass "upgrade preserves the administrator's old configuration" || fail "upgrade changed administrator settings"
    [[ -f /etc/xdg/kdeglobals.rpmnew ]] && grep -q '^\[Colors:View\]' /etc/xdg/kdeglobals.rpmnew \
      && pass "updated defaults delivered as .rpmnew" || fail "updated .rpmnew defaults missing"
    ;;
  plymouth)
    stub_initrd
    rpm -i --nodeps /work/new.rpm >/dev/null 2>&1 || fail "install new package"
    [[ "$(plymouth-set-default-theme)" == "ro-theme" ]] && pass "first install selects ro-theme" || fail "first install theme: $(plymouth-set-default-theme)"
    [[ "$(rebuilds)" == "1" ]] && pass "first install rebuilds initramfs once" || fail "first install rebuilt $(rebuilds) times (want 1)"
    [[ -f "$STAMP" && "$(cat "$STAMP")" == "$(theme_sum)" ]] && pass "successful rebuild writes the theme checksum stamp" || fail "stamp missing or wrong after rebuild: $(cat "$STAMP" 2>&1)"
    rpm -Uvh --replacepkgs --nodeps /work/new.rpm >/dev/null 2>&1 || fail "reinstall new package"
    [[ "$(rebuilds)" == "1" ]] && pass "reinstall with unchanged theme files does not rebuild" || fail "reinstall rebuilt initramfs again ($(rebuilds))"
    # Başarısız üretim: damga eskisi kalır, uyarı verilir, bir sonraki işlemde yeniden denenir
    echo stale > "$STAMP"
    fail_initrd
    err="$(rpm -Uvh --replacepkgs --nodeps /work/new.rpm 2>&1 >/dev/null)"
    [[ "$(rebuilds)" == "2" ]] && pass "changed theme files trigger a rebuild" || fail "rebuild attempts: $(rebuilds) (want 2)"
    grep -q "initramfs rebuild for the Plymouth theme failed" <<<"$err" && pass "failed rebuild warns" || fail "no warning on failed rebuild: $err"
    [[ "$(cat "$STAMP")" == "stale" ]] && pass "failed rebuild does not write the stamp" || fail "stamp written after a failed rebuild"
    ok_initrd
    rpm -Uvh --replacepkgs --nodeps /work/new.rpm >/dev/null 2>&1 || fail "reinstall new package"
    [[ "$(rebuilds)" == "3" && "$(cat "$STAMP")" == "$(theme_sum)" ]] && pass "next transaction retries and writes the stamp" || fail "retry: rebuilds $(rebuilds), stamp $(cat "$STAMP")"
    : > /tmp/initrd.log; echo rebuild > /tmp/initrd.log
    plymouth-set-default-theme spinner
    rpm -Uvh --replacepkgs --nodeps /work/new.rpm >/dev/null 2>&1 || fail "reinstall new package"
    [[ "$(plymouth-set-default-theme)" == "spinner" ]] && pass "user's own Plymouth theme kept on reinstall" || fail "reinstall replaced the user's Plymouth theme"
    [[ "$(rebuilds)" == "1" ]] && pass "no rebuild when another theme is selected" || fail "rebuilt for a theme that is not selected ($(rebuilds))"
    plymouth-set-default-theme ro-theme
    rpm -e --nodeps ro-theme >/dev/null 2>&1 || fail "remove package"
    [[ "$(plymouth-set-default-theme)" != "ro-theme" ]] && pass "removal resets Plymouth to the distribution default ($(plymouth-set-default-theme))" || fail "ro-theme still selected after removal"
    [[ "$(rebuilds)" == "2" ]] && pass "removal rebuilds initramfs once" || fail "removal rebuilds: $(rebuilds) (want 2)"
    [[ ! -e /var/lib/ro-theme ]] && pass "state directory removed" || fail "/var/lib/ro-theme left behind"
    ;;
  plymouth-installroot)
    # Installroot / konteyner / imaj derlemesi: çalışan çekirdeğin modülleri bu kökte yok. dracut denenmez,
    # "failed" uyarısı çıkmaz, damga yazılmaz; tema yine seçilir (imaj aracı initramfs'i kendi üretir).
    : > /tmp/initrd.log
    rm -rf "/lib/modules/$(uname -r)"
    err="$(rpm -i --nodeps /work/new.rpm 2>&1 >/dev/null)" || fail "install new package"
    [[ "$(plymouth-set-default-theme)" == "ro-theme" ]] && pass "installroot: ro-theme selected" || fail "installroot theme: $(plymouth-set-default-theme)"
    [[ "$(rebuilds)" == "0" ]] && pass "installroot: initramfs not rebuilt" || fail "installroot rebuilt $(rebuilds) times"
    [[ ! -e "$STAMP" ]] && pass "installroot: no stamp written" || fail "installroot wrote a stamp"
    grep -q "initramfs not rebuilt here" <<<"$err" && ! grep -q "failed" <<<"$err" && pass "installroot: informative note, no failure warning" || fail "installroot output: $err"
    ;;
  remove)
    # PKG-13: kaldırma. Paket dosyaları gider; yöneticinin değiştirdiği /etc/xdg dosyası .rpmsave olarak korunur.
    rpm -i --nodeps /work/new.rpm >/dev/null 2>&1 || fail "install new package"
    printf '\n[Ro-Test]\nAdminKey=1\n' >> /etc/xdg/kdeglobals
    rpm -e --nodeps ro-theme >/dev/null 2>&1 || fail "remove package"
    rpm -q ro-theme >/dev/null 2>&1 && fail "package still installed" || pass "package removed"
    left="$(find /usr/share/plasma/look-and-feel/org.ro.dark /usr/share/plasma/desktoptheme/RoDark /usr/share/aurorae/themes/RoDark -type f 2>/dev/null | wc -l)"
    [[ "$left" == "0" ]] && pass "theme files removed" || fail "$left theme files left behind"
    [[ -f /etc/xdg/kdeglobals.rpmsave ]] && grep -q '^AdminKey=1$' /etc/xdg/kdeglobals.rpmsave \
      && pass "admin-edited /etc/xdg/kdeglobals kept as .rpmsave" || fail "admin-edited /etc/xdg/kdeglobals lost on removal"
    [[ ! -e /etc/xdg/kwinrc ]] && pass "unmodified /etc/xdg files removed" || fail "unmodified /etc/xdg/kwinrc left behind"
    ;;
  deps)
    # PKG-13 / Ro-Repo dependency-solve: bütün bağımlılıklar Fedora 44 depolarından çözülebilir (kurmadan).
    if out="$(bash /work/check-rpm-dependencies.sh /work/new.rpm 2>&1)"; then
      pass "all dependencies resolve from the Fedora 44 repositories"
    else
      fail "dependency resolution failed: $out"
    fi
    for font_package in google-noto-sans-fonts google-noto-sans-mono-fonts rsms-inter-fonts; do
      rpm -qp --requires /work/new.rpm | grep -Eq "^${font_package}([[:space:]]|$)" \
        && pass "font required even with weak dependencies disabled: $font_package" \
        || fail "missing strong font dependency: $font_package"
    done
    grep -qE "ro-widgets" <<<"$out" && pass "weak dependency ro-widgets offered" || echo "  [INFO] ro-widgets not in the transaction (not in Fedora repos)"
    ;;
esac
exit "$fails"
EOS
chmod +x "$WORK/scenario.sh"

# Test araçları (kreadconfig6, runuser, useradd) bir kez kurulu yerel imaj; senaryolar bu imajdan başlar.
if ! podman image exists "$IMAGE" || [[ "${RO_THEME_TEST_REBUILD:-0}" == "1" ]]; then
  echo "Preparing test image $IMAGE (one time)..."
  printf 'FROM %s\nRUN dnf -y install kf6-kconfig util-linux shadow-utils plymouth plymouth-plugin-two-step plymouth-plugin-script plymouth-theme-spinner && dnf clean all\nRUN printf "#!/bin/sh\\necho rebuild >> /tmp/initrd.log\\n" > /usr/libexec/plymouth/plymouth-update-initrd\n' "$BASE_IMAGE" \
    | podman build -q -t "$IMAGE" -f - "$WORK" >/dev/null
fi

total=0
for scenario in clean user-own admin-edit upgrade admin-upgrade remove plymouth plymouth-installroot deps; do
  if [[ "$scenario" == *upgrade && -z "$OLD_RPM" ]]; then
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
