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
Requires:       util-linux

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
    [ -n "$output" ] && echo "$output" >&2
    return 1
  fi
  return 0
}

if command -v kbuildsycoca6 >/dev/null 2>&1; then
  ro_theme_try "KDE service cache refresh" kbuildsycoca6 --noincremental || true
elif command -v kbuildsycoca5 >/dev/null 2>&1; then
  ro_theme_try "KDE service cache refresh" kbuildsycoca5 --noincremental || true
fi

# Plymouth teması yalnız ilk kurulumda seçilir; kullanıcının sonraki seçimi ezilmez.
# initramfs burada değil, %posttrans içinde ve yalnız gerekiyorsa üretilir.
if [ "$1" -eq 1 ]; then
  ro_theme_try "plymouth theme selection" plymouth-set-default-theme ro-theme || true
fi

exit 0

%posttrans
set +e

# Ro teması seçiliyse ve tema dosyaları değiştiyse initramfs bir kez yenilenir.
# Installroot, konteyner ve imaj derlemesinde çalışan çekirdeğin modülleri bu kökte
# yoktur; dracut orada denenmez ve damga yazılmaz.
if command -v plymouth-set-default-theme >/dev/null 2>&1 \
   && [ "$(plymouth-set-default-theme 2>/dev/null)" = "ro-theme" ]; then
  stampdir=/var/lib/ro-theme
  stamp="$stampdir/plymouth.sha256"
  sum="$(cat /usr/share/plymouth/themes/ro-theme/* 2>/dev/null | sha256sum | cut -d' ' -f1)"
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

# Tam kaldırmada tema sıfırlanır. Modül dizini yoksa (konteyner/installroot)
# yalnız tema seçimi sıfırlanır; initramfs yeniden üretilmez.
if [ "$1" -eq 0 ] && command -v plymouth-set-default-theme >/dev/null 2>&1 \
   && [ "$(plymouth-set-default-theme 2>/dev/null)" = "ro-theme" ]; then
  if [ -d "/lib/modules/$(uname -r)" ]; then
    plymouth-set-default-theme --reset --rebuild-initrd >/dev/null 2>&1 || true
  else
    echo "ro-theme preun: initramfs not rebuilt here: modules of the running kernel are not in this root" >&2
    plymouth-set-default-theme --reset >/dev/null 2>&1 || true
  fi
fi

exit 0

%postun
set +e

if [ "$1" -eq 0 ]; then
  rm -rf /var/lib/ro-theme
fi

if command -v kbuildsycoca6 >/dev/null 2>&1; then
  kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
elif command -v kbuildsycoca5 >/dev/null 2>&1; then
  kbuildsycoca5 --noincremental >/dev/null 2>&1 || true
fi

exit 0

%files -f ro-theme.files
%license LICENSE LICENSES/CC-BY-SA-4.0.txt LICENSES/ASSETS.md
%doc README.md

%changelog
* Sun Nov 01 2026 Project Ro-ASD <contact@roasd.org> - 2.0.0-1
- New build infrastructure; repository moved to a fresh history.
