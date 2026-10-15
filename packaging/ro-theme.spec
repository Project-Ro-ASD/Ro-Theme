Name:           ro-theme
Version:        1.1.2
Release:        1%{?dist}
Summary:        Ro Desktop KDE Plasma theme package
# PKG-08: kod ve üretilen dosyalar GPL; elle hazırlanmış görseller ve logo CC-BY-SA-4.0 (LICENSES/ASSETS.md).
License:        GPL-3.0-or-later AND CC-BY-SA-4.0
URL:            https://github.com/Project-Ro-ASD/Ro-Theme
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

BuildRequires:  bash
BuildRequires:  python3

Requires:       bash
Requires:       coreutils
# PKG-05: kf6-kpackage, kf6-kservice ve plasma-workspace-libs plasma-workspace ile zaten geliyor.
# kf6-kconfig: paketteki apply-dark-defaults ve diagnose kwriteconfig6/kreadconfig6 kullanıyor.
Requires:       kf6-kconfig
Requires:       aurorae
Requires:       plasma-desktop
Requires:       plasma-workspace
Requires:       plasma-login-manager
# FNT-04: pencere başlığı Inter SemiBold; yoksa Noto Sans'a düşer (FNT-08).
Recommends:     rsms-inter-fonts
Requires:       util-linux
Requires(post): bash
Requires(post): coreutils
Requires(post): util-linux
Requires(postun): bash
# 16 · PLY-01 C: açılış teması Plymouth two-step modülüyle çizilir. Çekirdek parametreleri (rhgb quiet) ve
# initramfs üretimi kurulum programının işidir (PLY-09); paket initramfs'i yalnız gerektiğinde bir kez yeniler.
Requires:       plymouth
Requires:       plymouth-plugin-two-step
Requires(post): plymouth
Requires(posttrans): plymouth
Requires(posttrans): coreutils
Requires(preun): plymouth

%description
Ro Desktop theme for KDE Plasma: Ro Light and Ro Dark global themes, Plasma
styles, color schemes, the Ro Aurorae window decoration, the panel layout,
the Plymouth boot theme, the Ro GTK style, icon and cursor definitions, system
appearance defaults and diagnostic tools.

%description -l tr
KDE Plasma için Ro masaüstü teması: Ro Açık ve Ro Koyu global temaları, Plasma
stilleri, renk şemaları, Ro Aurorae pencere dekorasyonu, panel yerleşimi,
Plymouth açılış teması, Ro GTK stili, ikon ve imleç tanımları, sistem görünüm
varsayılanları ve tanı araçları.

%prep
%autosetup -n %{name}-%{version}

%build
./scripts/generate-theme.sh

%check
./scripts/validate.sh

%install
install -d \
  %{buildroot}%{_datadir}/color-schemes \
  %{buildroot}%{_datadir}/plasma/desktoptheme \
  %{buildroot}%{_datadir}/plasma/look-and-feel \
  %{buildroot}%{_datadir}/plasma/layout-templates \
  %{buildroot}%{_datadir}/ro-theme/wallpapers \
  %{buildroot}%{_datadir}/wallpapers \
  %{buildroot}%{_datadir}/aurorae/themes \
  %{buildroot}%{_datadir}/themes \
  %{buildroot}%{_datadir}/icons \
  %{buildroot}%{_datadir}/plymouth/themes \
  %{buildroot}%{_prefix}/lib/plasmalogin/plasmalogin.conf.d \
  %{buildroot}%{_libexecdir}/ro-theme \
  %{buildroot}%{_bindir} \
  %{buildroot}%{_sysconfdir}/xdg

# Plasma renk şemaları, global theme ve Plasma style.
cp -a platform/plasma/color-schemes/* %{buildroot}%{_datadir}/color-schemes/
cp -a platform/plasma/desktoptheme/RoLight %{buildroot}%{_datadir}/plasma/desktoptheme/
cp -a platform/plasma/desktoptheme/RoDark %{buildroot}%{_datadir}/plasma/desktoptheme/
cp -a platform/plasma/look-and-feel/org.ro.light %{buildroot}%{_datadir}/plasma/look-and-feel/
cp -a platform/plasma/look-and-feel/org.ro.dark %{buildroot}%{_datadir}/plasma/look-and-feel/
cp -a platform/plasma/layout-templates/org.ro.desktop %{buildroot}%{_datadir}/plasma/layout-templates/

# Wallpaper dosyaları.
install -Dm0644 dist/qml/RoTokens.qml %{buildroot}%{_datadir}/ro-theme/qml/RoTokens.qml
install -Dm0644 assets/wallpapers/light.jpg %{buildroot}%{_datadir}/ro-theme/wallpapers/light.jpg
install -Dm0644 assets/wallpapers/dark.jpg %{buildroot}%{_datadir}/ro-theme/wallpapers/dark.jpg
install -Dm0644 assets/wallpapers/loginv2.jpg %{buildroot}%{_datadir}/ro-theme/wallpapers/login.jpg
install -Dm0644 assets/wallpapers/light.jpg "%{buildroot}%{_datadir}/wallpapers/Ro Light.jpg"
install -Dm0644 assets/wallpapers/dark.jpg "%{buildroot}%{_datadir}/wallpapers/Ro Dark.jpg"

# KWin, GTK, icon ve cursor paketleri.
# Pencere dekorasyonu (Aurorae).
cp -a platform/kwin/aurorae/RoLight %{buildroot}%{_datadir}/aurorae/themes/
cp -a platform/kwin/aurorae/RoDark %{buildroot}%{_datadir}/aurorae/themes/
cp -a platform/gtk/Ro-GTK %{buildroot}%{_datadir}/themes/
cp -a platform/icons/ro-icons %{buildroot}%{_datadir}/icons/
cp -a platform/cursor/ro-cursor %{buildroot}%{_datadir}/icons/

# Plymouth.
cp -a platform/plymouth/ro-theme %{buildroot}%{_datadir}/plymouth/themes/
install -Dm0644 platform/plasmalogin/20-ro-theme.conf \
  %{buildroot}%{_prefix}/lib/plasmalogin/plasmalogin.conf.d/20-ro-theme.conf

# Kullanıcı/system tanı ve default uygulama araçları.
install -Dm0755 scripts/apply-dark-defaults.sh %{buildroot}%{_libexecdir}/ro-theme/apply-dark-defaults
install -Dm0755 scripts/check-plasma-runtime.sh %{buildroot}%{_libexecdir}/ro-theme/check-plasma-runtime
install -Dm0755 scripts/diagnose.sh %{buildroot}%{_bindir}/ro-theme-diagnose

# Sistem varsayılanları üreticiden gelir (platform/plasma/defaults/xdg); %%config(noreplace) ile kurulur.
# %%post bu dosyalara ve kullanıcı dosyalarına yazmaz (DEFAULTS-OWNERSHIP-V1).
for f in kdeglobals kcmfonts breezerc plasmarc ksplashrc kscreenlockerrc kwinrc; do
  install -Dm0644 "platform/plasma/defaults/xdg/$f" "%{buildroot}%{_sysconfdir}/xdg/$f"
done

# Aynı görselin uyumluluk yollarını koru; yalnızca birebir aynı dosyaları buildroot'ta bağla.
# Kaynak görseller değişmez. Farklı açık/koyu içerikler ve sembolik bağlantılar birleştirilmez.
python3 - "%{buildroot}%{_datadir}" <<'PY'
import hashlib
import os
from pathlib import Path
import sys

root = Path(sys.argv[1])
seen = {}
for folder in ('wallpapers', 'ro-theme/wallpapers', 'plasma/look-and-feel'):
    for path in sorted((root / folder).rglob('*')):
        if path.is_symlink() or not path.is_file() or path.suffix not in ('.jpg', '.png'):
            continue
        key = (path.stat().st_mode, hashlib.sha256(path.read_bytes()).digest())
        if key in seen:
            path.unlink()
            os.link(seen[key], path)
        else:
            seen[key] = path
PY

%post
set +e

ro_theme_warn() {
  echo "ro-theme post: warning: $*" >&2
}

ro_theme_try() {
  label="$1"
  shift
  output="$("$@" 2>&1)"
  status=$?
  if [ "$status" -ne 0 ]; then
    ro_theme_warn "$label failed with status $status"
    if [ -n "$output" ]; then
      echo "$output" >&2
    fi
    return 1
  fi
  return 0
}

if command -v kbuildsycoca6 >/dev/null 2>&1; then
  ro_theme_try "KDE service cache refresh" kbuildsycoca6 --noincremental || true
elif command -v kbuildsycoca5 >/dev/null 2>&1; then
  ro_theme_try "KDE service cache refresh" kbuildsycoca5 --noincremental || true
fi

# PLY-08 B: Ro açılış teması yalnız ilk kurulumda seçilir; kullanıcının sonradan seçtiği tema güncellemede ezilmez.
# initramfs burada değil, %%posttrans'ta ve yalnız gerekiyorsa üretilir.
if [ "$1" -eq 1 ]; then
  ro_theme_try "plymouth theme selection" plymouth-set-default-theme ro-theme || true
fi

exit 0

%posttrans
set +e
# PLY-08 B / PLY-10: Ro teması seçiliyse ve tema dosyaları değiştiyse initramfs bir kez (çalışan çekirdek) yenilenir.
# Her güncellemede değil; dosyalar aynıysa hiçbir şey yapılmaz. Kurulum programı kendi initramfs'ini zaten üretir.
if [ "$(plymouth-set-default-theme 2>/dev/null)" = "ro-theme" ]; then
  stamp=%{_sharedstatedir}/ro-theme/plymouth.sha256
  sum="$(cat %{_datadir}/plymouth/themes/ro-theme/* 2>/dev/null | sha256sum | cut -d' ' -f1)"
  if [ "$sum" != "$(cat "$stamp" 2>/dev/null)" ]; then
    if plymouth-set-default-theme -R ro-theme >/dev/null 2>&1; then
      mkdir -p "${stamp%%/*}" && echo "$sum" > "$stamp"
    else
      echo "ro-theme posttrans: warning: initramfs rebuild for the Plymouth theme failed" >&2
    fi
  fi
fi
exit 0

%preun
set +e
# Paket kaldırılırken Ro açılış teması seçiliyse dağıtım varsayılanına dönülür (tek initramfs üretimi).
# %%postun'da değil: tema dosyaları silindikten sonra plymouth-set-default-theme seçili temayı göremez.
if [ "$1" -eq 0 ] && [ "$(plymouth-set-default-theme 2>/dev/null)" = "ro-theme" ]; then
  plymouth-set-default-theme --reset --rebuild-initrd >/dev/null 2>&1 || true
fi
exit 0

%postun
set +e
[ "$1" -eq 0 ] && rm -rf %{_sharedstatedir}/ro-theme

if command -v kbuildsycoca6 >/dev/null 2>&1; then
  kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
elif command -v kbuildsycoca5 >/dev/null 2>&1; then
  kbuildsycoca5 --noincremental >/dev/null 2>&1 || true
fi

exit 0

%files
%defattr(-,root,root,-)
%license LICENSE LICENSES/CC-BY-SA-4.0.txt LICENSES/ASSETS.md
%doc README.md
%{_datadir}/color-schemes/RoLight.colors
%{_datadir}/color-schemes/RoDark.colors
%{_datadir}/plasma/desktoptheme/RoLight
%{_datadir}/plasma/desktoptheme/RoDark
%{_datadir}/plasma/look-and-feel/org.ro.light
%{_datadir}/plasma/look-and-feel/org.ro.dark
%{_datadir}/plasma/layout-templates/org.ro.desktop
%dir %{_datadir}/ro-theme
%dir %{_datadir}/ro-theme/wallpapers
%dir %{_datadir}/ro-theme/qml
%{_datadir}/ro-theme/qml/RoTokens.qml
%{_datadir}/ro-theme/wallpapers/light.jpg
%{_datadir}/ro-theme/wallpapers/dark.jpg
%{_datadir}/ro-theme/wallpapers/login.jpg
"%{_datadir}/wallpapers/Ro Light.jpg"
"%{_datadir}/wallpapers/Ro Dark.jpg"
%{_datadir}/aurorae/themes/RoLight
%{_datadir}/aurorae/themes/RoDark
%{_datadir}/themes/Ro-GTK
%{_datadir}/icons/ro-icons
%{_datadir}/icons/ro-cursor
%{_datadir}/plymouth/themes/ro-theme
%{_prefix}/lib/plasmalogin/plasmalogin.conf.d/20-ro-theme.conf
%dir %{_libexecdir}/ro-theme
%{_libexecdir}/ro-theme/apply-dark-defaults
%{_libexecdir}/ro-theme/check-plasma-runtime
%{_bindir}/ro-theme-diagnose
%config(noreplace) %{_sysconfdir}/xdg/kdeglobals
%config(noreplace) %{_sysconfdir}/xdg/kcmfonts
%config(noreplace) %{_sysconfdir}/xdg/breezerc
%config(noreplace) %{_sysconfdir}/xdg/plasmarc
%config(noreplace) %{_sysconfdir}/xdg/ksplashrc
%config(noreplace) %{_sysconfdir}/xdg/kscreenlockerrc
%config(noreplace) %{_sysconfdir}/xdg/kwinrc

%changelog
* Wed Oct 14 2026 Project Ro-ASD <contact@roasd.org> - 1.1.2-1
- Release workflow: create the draft release through the API and use its id for asset
  upload and publishing; a new draft is listed without its tag at first, so v1.1.1 stopped
  before publishing. No theme changes since 1.1.0.

* Wed Oct 14 2026 Project Ro-ASD <contact@roasd.org> - 1.1.1-1
- Release workflow: install git and mark the workspace safe before the tag check in the
  Fedora container; v1.1.0 was tagged but never published because of this.
- No theme changes since 1.1.0; see the 1.1.0 entry below.

* Wed Oct 14 2026 Project Ro-ASD <contact@roasd.org> - 1.1.0-1
- Defaults: /etc/xdg files shipped as %%config(noreplace); the package no longer writes user
  or system configuration in scriptlets; global themes and /etc/xdg are checked to agree.
- Colors: Ro palette from the logo hue, per-set roles, visible inactive selection and
  alternate rows; glass opacity 85% from a single token.
- Plasma style: Ro-drawn line edit, buttons, list highlight, scrollbar, checkbox, radio,
  switch, slider, popup header/footer, tooltip, task indicators, busy indicator, tab bar,
  progress bar, separators, frames, arrows and the panel background (solid variant too).
- Window decoration: Ro Aurorae (v2) is the default; soft window shadow, rounded-square
  buttons, red close; Turkish names; button layout M / IAX.
- Panel: single floating bottom bar from tokens (launcher, centred tasks, tray, clock in
  Noto Sans SemiBold); ro-launcher when installed, Kickoff otherwise; the layout template
  no longer removes panels; wallpaper path works for RPM installs.
- Application style: Breeze settings (no tree lines, no toolbar separators, no slider ticks,
  120 ms animations), no icons on push buttons.
- KWin: KDE default effects; the custom JavaScript window effect is removed; adaptive
  transparency on.
- Fonts: Noto Sans roles, Inter SemiBold window titles (Recommends rsms-inter-fonts), DPI.
- Global themes: previews, Turkish metadata, automatic light/dark pair.
- Ro Icons for Dolphin; RoTokens.qml for Ro widgets.
- Packaging: License GPL-3.0-or-later AND CC-BY-SA-4.0, repository URL, fewer
  dependencies, README-only docs, rpmlint report, weekly Fedora 44 check.

* Fri Aug 28 2026 Project Ro-ASD <contact@roasd.org> - 1.0.1-2
- Rebuild for Fedora 44 and Plasma Login Manager.
- Remove the legacy SDDM theme and provide only the Ro login wallpaper default.

* Mon May 11 2026 Project Ro-ASD <ro-theme@example.invalid> - 1.0.1-1
- Update v2 wallpaper assets and SDDM login logo treatment.
- Improve lock screen wallpaper dimming and Plymouth RPM activation dependencies.
- Add project and wallpaper maintenance notes.
* Tue May 05 2026 Project Ro-ASD <ro-theme@example.invalid> - 1.0.0-1
- Align Ro global theme colors and Plasma style with generated token outputs.
- Add validation, diagnostics, RPM build and RPM test helpers with clear error output.
