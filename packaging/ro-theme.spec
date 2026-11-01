Name:           ro-theme
Version:        2.0.0
Release:        1%{?dist}
Summary:        Ro Desktop KDE Plasma theme package
Summary(tr):    Ro Masaüstü KDE Plasma tema paketi
License:        GPL-3.0-or-later AND CC-BY-SA-4.0 AND OFL-1.1
URL:            https://github.com/Project-Ro-ASD/Ro-Theme
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

BuildRequires:  python3

Requires:       aurorae
Requires:       bash
Requires:       breeze-cursor-theme
Requires:       coreutils
Requires:       google-noto-sans-fonts
Requires:       google-noto-sans-mono-fonts
Requires:       kf6-kconfig
Requires:       papirus-icon-theme
Requires:       papirus-icon-theme-dark
Requires:       papirus-icon-theme-light
Requires:       plasma-desktop
Requires:       plasma-login-manager
Requires:       plasma-workspace
Requires:       plymouth
Requires:       plymouth-plugin-two-step
Requires:       python3
Requires:       rsms-inter-fonts

Recommends:     ro-widgets
Recommends:     ro-style

%description
Ro Desktop için KDE Plasma masaüstü teması, renk şemaları, pencere
dekorasyonu, simge ve imleç temaları, Plymouth açılış teması, GRUB teması
ve sistem geneli /etc/xdg varsayılanları.

%prep
%autosetup -n %{name}-%{version}

%build
./ro generate --check

%install
rm -rf %{buildroot}
./ro install --destdir %{buildroot} --record-files ro-theme.files

%check
./ro validate --installed %{buildroot}

%post
set +e

# Plymouth teması yalnız ilk kurulumda seçilir; sonraki seçimler korunur.
if [ "${1:-}" = 1 ] && command -v plymouth-set-default-theme >/dev/null 2>&1; then
  if ! plymouth-set-default-theme ro-theme >/dev/null 2>&1; then
    echo "ro-theme: could not select the Plymouth theme" >&2
  fi
fi

exit 0

%posttrans
set +e

theme_root=/usr/share/plymouth/themes/ro-theme
stamp_dir=/var/lib/ro-theme
stamp_file=$stamp_dir/plymouth.sha256

# Yalnız etkin tema Ro ise ve tema dosyaları yerindeyse çalış.
if [ -d "$theme_root" ] && command -v plymouth-set-default-theme >/dev/null 2>&1 \
   && [ "$(plymouth-set-default-theme 2>/dev/null)" = ro-theme ]; then
  digest=$(find "$theme_root" -type f -print0 2>/dev/null \
    | LC_ALL=C sort -z \
    | xargs -0 -r cat 2>/dev/null \
    | sha256sum | cut -d' ' -f1)

  if [ -f "$stamp_file" ] && [ "$(cat "$stamp_file" 2>/dev/null)" = "$digest" ]; then
    :  # Tema değişmedi; initramfs zaten güncel.
  elif [ ! -d "/lib/modules/$(uname -r)" ]; then
    echo "ro-theme: initramfs not rebuilt here (installroot, container or image build)" >&2
  elif plymouth-set-default-theme -R ro-theme >/dev/null 2>&1; then
    mkdir -p "$stamp_dir" && printf '%s\n' "$digest" > "$stamp_file"
  else
    echo "ro-theme: initramfs rebuild failed, will retry on next update" >&2
  fi
fi

exit 0

%preun
set +e

# Tam kaldırmada varsayılan temaya dönülür.
if [ "${1:-}" = 0 ] && command -v plymouth-set-default-theme >/dev/null 2>&1 \
   && [ "$(plymouth-set-default-theme 2>/dev/null)" = ro-theme ]; then
  if [ -d "/lib/modules/$(uname -r)" ]; then
    plymouth-set-default-theme --reset --rebuild-initrd >/dev/null 2>&1 \
      || echo "ro-theme: could not reset the Plymouth theme" >&2
  else
    plymouth-set-default-theme --reset >/dev/null 2>&1 \
      || echo "ro-theme: could not reset the Plymouth theme" >&2
  fi
fi

exit 0

%postun
set +e

if [ "${1:-}" = 0 ]; then
  rm -rf /var/lib/ro-theme
fi

exit 0

%files -f ro-theme.files
%license LICENSE LICENSES/CC-BY-SA-4.0.txt LICENSES/ASSETS.md
%doc README.md

%changelog
* Sun Nov 01 2026 Project Ro-ASD <contact@roasd.org> - 2.0.0-1
- New build infrastructure; repository moved to a fresh history.
