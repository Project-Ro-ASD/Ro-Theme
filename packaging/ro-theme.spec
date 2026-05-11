Name:           ro-theme
Version:        1.0.1
Release:        1%{?dist}
Summary:        Ro Desktop KDE Plasma theme package
License:        GPL-3.0-or-later
URL:            https://ro-theme.local
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

BuildRequires:  bash
BuildRequires:  python3

Requires:       bash
Requires:       coreutils
Requires:       kf6-kconfig
Requires:       kf6-kpackage
Requires:       kf6-kservice
Requires:       plasma-desktop
Requires:       plasma-workspace
Requires:       plasma-workspace-libs
Requires:       util-linux
Requires(post): bash
Requires(post): coreutils
Requires(post): kf6-kconfig
Requires(post): util-linux
Requires(post): plymouth
Requires(post): plymouth-plugin-script
Requires(post): dracut
Requires(post): grubby
Requires(postun): bash
Recommends:     sddm
Requires:       plymouth
Requires:       plymouth-plugin-script
Requires:       dracut
Requires:       grubby

%description
Ro Desktop için KDE Plasma global theme, Plasma style, color scheme,
KWin efekti, SDDM giriş ekranı, Plymouth boot teması, GTK stili,
icon/cursor tanımları ve tanı araçlarını içeren tema paketi.

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
  %{buildroot}%{_datadir}/kwin/effects \
  %{buildroot}%{_datadir}/themes \
  %{buildroot}%{_datadir}/icons \
  %{buildroot}%{_datadir}/sddm/themes \
  %{buildroot}%{_datadir}/plymouth/themes \
  %{buildroot}%{_libexecdir}/ro-theme \
  %{buildroot}%{_bindir} \
  %{buildroot}%{_sysconfdir}/sddm.conf.d \
  %{buildroot}%{_sysconfdir}/xdg/autostart

# Plasma renk şemaları, global theme ve Plasma style.
cp -a platform/plasma/color-schemes/* %{buildroot}%{_datadir}/color-schemes/
cp -a platform/plasma/desktoptheme/RoLight %{buildroot}%{_datadir}/plasma/desktoptheme/
cp -a platform/plasma/desktoptheme/RoDark %{buildroot}%{_datadir}/plasma/desktoptheme/
cp -a platform/plasma/look-and-feel/org.ro.light %{buildroot}%{_datadir}/plasma/look-and-feel/
cp -a platform/plasma/look-and-feel/org.ro.dark %{buildroot}%{_datadir}/plasma/look-and-feel/
cp -a platform/plasma/layout-templates/org.ro.desktop %{buildroot}%{_datadir}/plasma/layout-templates/

# Wallpaper dosyaları.
install -Dm0644 assets/wallpapers/light.jpg %{buildroot}%{_datadir}/ro-theme/wallpapers/light.jpg
install -Dm0644 assets/wallpapers/dark.jpg %{buildroot}%{_datadir}/ro-theme/wallpapers/dark.jpg
install -Dm0644 assets/wallpapers/light.jpg "%{buildroot}%{_datadir}/wallpapers/Ro Light.jpg"
install -Dm0644 assets/wallpapers/dark.jpg "%{buildroot}%{_datadir}/wallpapers/Ro Dark.jpg"

# KWin, GTK, icon ve cursor paketleri.
cp -a platform/kwin/effects/ro-smooth-motion %{buildroot}%{_datadir}/kwin/effects/
cp -a platform/gtk/Ro-GTK %{buildroot}%{_datadir}/themes/
cp -a platform/icons/ro-icons %{buildroot}%{_datadir}/icons/
cp -a platform/cursor/ro-cursor %{buildroot}%{_datadir}/icons/

# SDDM ve Plymouth.
cp -a platform/sddm/themes/Ro %{buildroot}%{_datadir}/sddm/themes/
cp -a platform/plymouth/ro-theme %{buildroot}%{_datadir}/plymouth/themes/

# Kullanıcı/system tanı ve default uygulama araçları.
install -Dm0755 scripts/apply-dark-defaults.sh %{buildroot}%{_libexecdir}/ro-theme/apply-dark-defaults
install -Dm0755 scripts/check-plasma-runtime.sh %{buildroot}%{_libexecdir}/ro-theme/check-plasma-runtime
install -Dm0755 scripts/diagnose.sh %{buildroot}%{_bindir}/ro-theme-diagnose

cat > %{buildroot}%{_sysconfdir}/sddm.conf.d/10-ro-theme.conf <<'EOF'
[Theme]
Current=Ro
EOF

cat > %{buildroot}%{_sysconfdir}/xdg/kdeglobals <<'EOF'
[KDE]
LookAndFeelPackage=org.ro.dark
widgetStyle=Breeze

[General]
ColorScheme=RoDark
EOF

cat > %{buildroot}%{_sysconfdir}/xdg/plasmarc <<'EOF'
[Theme]
name=RoDark
EOF

cat > %{buildroot}%{_sysconfdir}/xdg/ksplashrc <<'EOF'
[KSplash]
Engine=KSplashQML
Theme=org.ro.dark
EOF

cat > %{buildroot}%{_sysconfdir}/xdg/kscreenlockerrc <<'EOF'
[Greeter]
WallpaperPlugin=org.kde.image

[Greeter][Wallpaper][org.kde.image][General]
Image=file:///usr/share/plasma/look-and-feel/org.ro.dark/contents/lockscreen/assets/login.jpg
PreviewImage=file:///usr/share/plasma/look-and-feel/org.ro.dark/contents/lockscreen/assets/login.jpg
Blur=false
EOF

cat > %{buildroot}%{_sysconfdir}/xdg/kwinrc <<'EOF'
[org.kde.kdecoration2]
library=org.kde.breeze
theme=Breeze

[Plugins]
ro-smooth-motionEnabled=false
kwin4_effect_scaleEnabled=false
kwin4_effect_glideEnabled=false
kwin4_effect_squashEnabled=false
kwin4_effect_magiclampEnabled=false
magiclampEnabled=false
kwin4_effect_windowapertureEnabled=false
kwin4_effect_frozenappEnabled=false
EOF

cat > %{buildroot}%{_sysconfdir}/xdg/autostart/ro-theme-dark-defaults.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Ro Theme Dark Defaults
Comment=Apply Ro Dark defaults once for the current user
Exec=/usr/libexec/ro-theme/apply-dark-defaults --current-user
OnlyShowIn=KDE;
X-KDE-autostart-after=panel
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF

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

if [ -x /usr/libexec/ro-theme/apply-dark-defaults ]; then
  ro_theme_try "apply dark defaults" /usr/libexec/ro-theme/apply-dark-defaults --all-users --force || true
fi

if [ -f /etc/xdg/kdeglobals ]; then
  if command -v kwriteconfig6 >/dev/null 2>&1; then
    ro_theme_try "remove stale KDE ColorScheme fallback" kwriteconfig6 --file /etc/xdg/kdeglobals --group KDE --key ColorScheme --delete "" || true
  elif command -v kwriteconfig5 >/dev/null 2>&1; then
    ro_theme_try "remove stale KDE ColorScheme fallback" kwriteconfig5 --file /etc/xdg/kdeglobals --group KDE --key ColorScheme --delete "" || true
  fi
fi

if command -v kbuildsycoca6 >/dev/null 2>&1; then
  ro_theme_try "KDE service cache refresh" kbuildsycoca6 --noincremental || true
elif command -v kbuildsycoca5 >/dev/null 2>&1; then
  ro_theme_try "KDE service cache refresh" kbuildsycoca5 --noincremental || true
fi

if command -v plymouth-set-default-theme >/dev/null 2>&1; then
  ro_theme_try "plymouth theme activation" plymouth-set-default-theme ro-theme -R || true
elif [ -x /usr/libexec/plymouth/plymouth-set-default-theme ]; then
  ro_theme_try "plymouth theme activation" /usr/libexec/plymouth/plymouth-set-default-theme ro-theme -R || true
else
  ro_theme_warn "plymouth-set-default-theme not found; Plymouth files were installed but not activated"
fi

if command -v grubby >/dev/null 2>&1; then
  ro_theme_try "grubby rhgb quiet update" grubby --update-kernel=ALL --args="rhgb quiet" || true
else
  ro_theme_warn "grubby not found; rhgb quiet was not written automatically"
fi

if command -v dracut >/dev/null 2>&1; then
  ro_theme_try "dracut initramfs regeneration" dracut -f --regenerate-all || true
else
  ro_theme_warn "dracut not found; initramfs was not regenerated automatically"
fi

exit 0

%postun
set +e

if command -v kbuildsycoca6 >/dev/null 2>&1; then
  kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
elif command -v kbuildsycoca5 >/dev/null 2>&1; then
  kbuildsycoca5 --noincremental >/dev/null 2>&1 || true
fi

exit 0

%files
%defattr(-,root,root,-)
%license LICENSE
%doc README.md docs
%{_datadir}/color-schemes/RoLight.colors
%{_datadir}/color-schemes/RoDark.colors
%{_datadir}/plasma/desktoptheme/RoLight
%{_datadir}/plasma/desktoptheme/RoDark
%{_datadir}/plasma/look-and-feel/org.ro.light
%{_datadir}/plasma/look-and-feel/org.ro.dark
%{_datadir}/plasma/layout-templates/org.ro.desktop
%dir %{_datadir}/ro-theme
%dir %{_datadir}/ro-theme/wallpapers
%{_datadir}/ro-theme/wallpapers/light.jpg
%{_datadir}/ro-theme/wallpapers/dark.jpg
"%{_datadir}/wallpapers/Ro Light.jpg"
"%{_datadir}/wallpapers/Ro Dark.jpg"
%{_datadir}/kwin/effects/ro-smooth-motion
%{_datadir}/themes/Ro-GTK
%{_datadir}/icons/ro-icons
%{_datadir}/icons/ro-cursor
%{_datadir}/sddm/themes/Ro
%{_datadir}/plymouth/themes/ro-theme
%dir %{_libexecdir}/ro-theme
%{_libexecdir}/ro-theme/apply-dark-defaults
%{_libexecdir}/ro-theme/check-plasma-runtime
%{_bindir}/ro-theme-diagnose
%config %{_sysconfdir}/sddm.conf.d/10-ro-theme.conf
%config %{_sysconfdir}/xdg/kdeglobals
%config %{_sysconfdir}/xdg/plasmarc
%config %{_sysconfdir}/xdg/ksplashrc
%config %{_sysconfdir}/xdg/kscreenlockerrc
%config %{_sysconfdir}/xdg/kwinrc
%config %{_sysconfdir}/xdg/autostart/ro-theme-dark-defaults.desktop

%changelog
* Mon May 11 2026 Project Ro-ASD <ro-theme@example.invalid> - 1.0.1-1
- Update v2 wallpaper assets and SDDM login logo treatment.
- Improve lock screen wallpaper dimming and Plymouth RPM activation dependencies.
- Add project and wallpaper maintenance notes.
* Tue May 05 2026 Project Ro-ASD <ro-theme@example.invalid> - 1.0.0-1
- Align Ro global theme colors and Plasma style with generated token outputs.
- Add validation, diagnostics, RPM build and RPM test helpers with clear error output.
