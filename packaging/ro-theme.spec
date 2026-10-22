Name:           ro-theme
Version:        1.1.14
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
# FNT-08: seçilen aileler zayıf bağımlılıklar kapalıyken de kurulmalı.
Requires:       google-noto-sans-fonts
Requires:       google-noto-sans-mono-fonts
Requires:       rsms-inter-fonts
# GT-04c/e: global tema Ro Icons (Papirus tabanlı) ve Breeze imleç seçer; eksik kalırsa seçim sessizce düşer.
Requires:       papirus-icon-theme
Requires:       breeze-cursor-theme
# PAN-08, WGT-14: panel düzeni ro-launcher kuruluysa onu kullanır, değilse Kickoff'a düşer.
Recommends:     ro-widgets
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
# KDE duvar kâğıdı paketleri: Ayarlar'da "Ro Koyu" / "Ro Açık" olarak görünür, Plasma ekrana uygun boyutu
# (1920×1080 ya da 3840×2160) kendisi seçer; global tema ve yerleşim betiği bunları kullanır (GT-04j).
mkdir -p %{buildroot}%{_datadir}/wallpapers
cp -a assets/wallpapers/RoDark assets/wallpapers/RoLight %{buildroot}%{_datadir}/wallpapers/

# KWin, GTK, icon ve cursor paketleri.
# Pencere dekorasyonu (Aurorae).
cp -a platform/kwin/aurorae/RoLight %{buildroot}%{_datadir}/aurorae/themes/
cp -a platform/kwin/aurorae/RoDark %{buildroot}%{_datadir}/aurorae/themes/
mkdir -p %{buildroot}%{_datadir}/kwin/effects
cp -a platform/kwin/effects/ro-login-reveal %{buildroot}%{_datadir}/kwin/effects/
cp -a platform/gtk/Ro-GTK %{buildroot}%{_datadir}/themes/
cp -a platform/icons/ro-icons %{buildroot}%{_datadir}/icons/
# Açık mod: aynı Ro ikonları, tabanı Papirus-Light. Klasörler ro-icons'a sembolik bağ (ikonlar iki kez saklanmaz).
mkdir -p %{buildroot}%{_datadir}/icons/ro-icons-light
sed -e 's/^Name=Ro Icons$/Name=Ro Icons (Light)/' -e 's/^Inherits=Papirus-Dark$/Inherits=Papirus-Light/' \
  platform/icons/ro-icons/index.theme > %{buildroot}%{_datadir}/icons/ro-icons-light/index.theme
for dir in actions apps devices mimetypes places; do
  ln -s ../ro-icons/$dir %{buildroot}%{_datadir}/icons/ro-icons-light/$dir
done
cp -a platform/cursor/ro-cursor %{buildroot}%{_datadir}/icons/

# Firefox: ilerleme çubuğu rengi (GTK Breeze'de seçili yazı rengini alıyordu).
install -Dm0644 platform/firefox/ro-theme.js \
  %{buildroot}%{_libdir}/firefox/browser/defaults/preferences/ro-theme.js

# GRUB teması: yalnız dosyalar; /boot ve /etc/default/grub'a paket yazmaz, açmak için ro-grub-theme enable.
install -d %{buildroot}%{_datadir}/grub/themes
cp -a platform/grub/ro %{buildroot}%{_datadir}/grub/themes/ro
install -Dm0755 scripts/ro-grub-theme.sh %{buildroot}%{_bindir}/ro-grub-theme

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
# Damga dizini ayrı değişkende: parametre açılımıyla dizin çıkarmak spec'te kaçış gerektiriyor ve okuyanı yanıltıyordu.
# plymouth-set-default-theme -R yalnız "dracut -f" çalıştırır: çalışan çekirdeğin (uname -r) initramfs'i.
# Installroot, konteyner ve imaj derlemesinde o çekirdeğin modülleri bu kökte yoktur; dracut orada başarısız
# olur. Betikler o kökün içinde (chroot) çalıştığı için ana sistemin initramfs'ine dokunulmaz; burada denenmez,
# damga yazılmaz (gerçek sistemdeki ilk işlem bir kez üretir). İmajın initramfs'ini imaj aracı kendi çekirdeği
# için üretir ve seçili temayı alır.
if [ "$(plymouth-set-default-theme 2>/dev/null)" = "ro-theme" ]; then
  stampdir=%{_sharedstatedir}/ro-theme
  stamp="$stampdir/plymouth.sha256"
  sum="$(cat %{_datadir}/plymouth/themes/ro-theme/* 2>/dev/null | sha256sum | cut -d' ' -f1)"
  kver="$(uname -r)"
  if [ "$sum" = "$(cat "$stamp" 2>/dev/null)" ]; then
    :
  elif [ ! -d "/lib/modules/$kver" ]; then
    echo "ro-theme posttrans: initramfs not rebuilt here: modules of the running kernel ($kver) are not in this root (installroot, container or image build)" >&2
  elif plymouth-set-default-theme -R ro-theme >/dev/null 2>&1; then
    mkdir -p "$stampdir" && echo "$sum" > "$stamp"
  else
    echo "ro-theme posttrans: warning: initramfs rebuild for the Plymouth theme failed; it is retried on the next ro-theme update" >&2
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
%{_datadir}/wallpapers/RoLight
%{_datadir}/wallpapers/RoDark
%{_datadir}/aurorae/themes/RoLight
%{_datadir}/aurorae/themes/RoDark
%{_datadir}/kwin/effects/ro-login-reveal
%dir %{_datadir}/grub
%dir %{_datadir}/grub/themes
%{_datadir}/grub/themes/ro
%{_bindir}/ro-grub-theme
%dir %{_libdir}/firefox
%dir %{_libdir}/firefox/browser
%dir %{_libdir}/firefox/browser/defaults
%dir %{_libdir}/firefox/browser/defaults/preferences
%{_libdir}/firefox/browser/defaults/preferences/ro-theme.js
%{_datadir}/themes/Ro-GTK
%{_datadir}/icons/ro-icons
%{_datadir}/icons/ro-icons-light
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
* Thu Oct 22 2026 Project Ro-ASD <contact@roasd.org> - 1.1.14-1
- ro-icons: audio-volume-*, audio-speakers, audio-input-microphone, video-display,
  image-missing, text-editor and about 40 other Papirus names no longer resolve to
  Ro's file-type icons (the volume applet showed a note in a document). The
  audio/video/image/text -x-generic icons are gone from the theme; the artwork
  stays under specific names and the common file types have aliases.
- Qt widget menus (Dolphin, Kate, System Settings, panel context menus) are slightly
  translucent: MenuOpacity=60 in the system breezerc (the Ro style, Ro-Style, adds
  the rounder corners; users can change the value in System Settings > Application
  Style > Configure > Transparency).
- Colours: dark-theme disabled text is lighter (ContrastAmount 0.45; it was #626365,
  almost invisible on translucent menus).
- Packaging: the selected font families (Noto Sans, Noto Sans Mono, Inter) are hard
  requirements, so they are installed even with weak dependencies disabled.
* Wed Oct 21 2026 Project Ro-ASD <contact@roasd.org> - 1.1.13-1
- GRUB: hills and moon artwork; the menu sits higher and is narrower (Noto Sans
  16) so long Fedora titles stay clear of the art; the theme defines a full
  screen terminal area, so pressing Enter no longer shows a black rectangle over
  the menu. Run `sudo ro-grub-theme enable` again to refresh /boot.
- ro-icons: trash-empty for Dolphin's Move to Trash.
* Wed Oct 21 2026 Project Ro-ASD <contact@roasd.org> - 1.1.12-1
- GRUB: wave artwork instead of the rings; menu rows keep their spacing when
  the selection moves; wider menu with Noto Sans 18 so long Fedora titles fit.
  ro-grub-theme no longer writes GRUB_GFXPAYLOAD_LINUX=keep (run
  `sudo ro-grub-theme enable` again to refresh the copy in /boot).
- ro-icons: Dolphin context menu icons (16 and 22 px, 24 and 32 link to 22).
* Wed Oct 21 2026 Project Ro-ASD <contact@roasd.org> - 1.1.11-1
- GRUB: new Ro GRUB theme (ring artwork, text-only menu, Ro icons) in
  /usr/share/grub/themes/ro. The package does not touch /boot or
  /etc/default/grub; turn it on with `sudo ro-grub-theme enable` (and off
  with `disable`).
- Firefox: default accent colour (ui.accentcolor) so the download progress
  bar is visible; it took the dark selected-text colour and merged with its track.
* Wed Oct 21 2026 Project Ro-ASD <contact@roasd.org> - 1.1.10-1
- Panel: 56 px high; the system tray icons keep their fixed size (scaling them
  to the panel made them look oversized next to the app icons).
- Login: new KWin effect ro-login-reveal, enabled by default. When the desktop
  is ready the splash window dissolves and grows a little while the desktop and
  panel zoom in; the splash no longer fades on its own (its fade was cut short
  when the splash process exited).
* Tue Oct 20 2026 Project Ro-ASD <contact@roasd.org> - 1.1.9-1
- Panel: 52 px high (was 44) and the system tray icons scale with the panel
  instead of staying 22 px (scaleIconsToFit). Layout packages and the layout
  template follow.
- Global themes: the Settings previews are regenerated from a real Ro desktop
  (seed-102 wallpaper, Ro Icons, English interface).

* Tue Oct 20 2026 Project Ro-ASD <contact@roasd.org> - 1.1.8-1
- Global themes now select the whole look: Ro Icons over Papirus (ro-icons,
  ro-icons-light for the light theme), the Breeze cursor and the Ro wallpaper
  package. Requires papirus-icon-theme and breeze-cursor-theme.
- Wallpaper: RoDark and RoLight KDE wallpaper packages (seed 102, 1080p and 4K,
  Plasma picks the size) replace the single jpg files; login, splash and lock
  screen images from the seed-102 login art.
- Plymouth: 192 px animation frames so the splash fits every screen size
  (it overlapped the firmware logo and ran off the bottom at 640x480).

* Tue Oct 20 2026 Project Ro-ASD <contact@roasd.org> - 1.1.7-1
- Plymouth: %%posttrans no longer tries to rebuild the initramfs when the
  running kernel's modules are not in this root (installroot, container,
  image build); it prints a note instead of a failure warning and writes no
  stamp. The stamp directory is set explicitly.
- Tests: stamp after a successful rebuild, failed rebuild (warning, no stamp,
  retried next time) and the installroot case.

* Tue Oct 20 2026 Project Ro-ASD <contact@roasd.org> - 1.1.6-1
- Packaging: Recommends ro-widgets, so the panel layout finds ro-launcher on a
  fresh install; without it the panel still falls back to Kickoff.
- CI: Fedora 44 baseline kf6-kconfig 6.31.0, verified against the theme.

* Mon Oct 19 2026 Project Ro-ASD <contact@roasd.org> - 1.1.5-1
- Plasma shell: popups, the panel, tooltips and desktop widget frames are
  borderless with soft shadows; the double line under popups attached to a
  non-floating panel is gone.
- Task manager: tiles no longer touch each other or the panel edge; the
  expanded launcher/tray highlight stays clear of the popup.
- Panel layout: ro-launcher keeps its own icon (ro-start); Kickoff, the
  fallback, gets the distribution logo.
- Developer tools: diagnose reports missing installed component files; CI
  parses the generated GTK 3/4 CSS. App developer guide (docs/).

* Thu Oct 15 2026 Project Ro-ASD <contact@roasd.org> - 1.1.4-1
- Task manager: group indicator (accent circle with a plus) for applications
  with several windows.
- Developer tools: local theme switching keeps the Ro window decoration;
  diagnose checks it against the global theme defaults; safer appearance
  reset backups, local install and system preview error handling; RPM build
  output selection and paths validated.

* Thu Oct 15 2026 Project Ro-ASD <contact@roasd.org> - 1.1.3-1
- Boot splash: two-step Plymouth theme with the Ro animation; password prompt,
  Caps Lock warning, update progress and the firmware logo now shown.
- Package scripts select the boot theme only on first install and rebuild the
  initramfs once, only when its files change; kernel arguments and the
  initramfs of other kernels are left to the installer; removal returns to
  the distribution default.
- Text fields: corner matches buttons, Breeze height; focus and hover rings stay
  on the field edge (login and lock screen password row).
- Login screen wallpaper setting uses the WallpaperPluginId key.
- Dock tokens removed; RoTokens.qml carries an SPDX header.
- Stricter package validation and installation tests.

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
