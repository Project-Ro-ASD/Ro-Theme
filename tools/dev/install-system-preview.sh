#!/usr/bin/env bash
set -euo pipefail


if [[ $EUID -ne 0 ]]; then
  echo "This script must be run with sudo: sudo ./tools/dev/install-system-preview.sh"
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

# Eksik kaynak yüzünden kurulu açılış temasını silmeden önce girdileri denetle.
for source_file in assets/wallpapers/loginv2.jpg platform/plasmalogin/20-ro-theme.conf \
  platform/plymouth/ro-theme/ro-theme.plymouth; do
  if [[ ! -f "$source_file" || ! -r "$source_file" ]]; then
    echo "Missing or unreadable preview source: $source_file; system files were not changed." >&2
    exit 1
  fi
done

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

chmod -R a+rX /usr/share/ro-theme/wallpapers/login.jpg \
  /usr/lib/plasmalogin/plasmalogin.conf.d/20-ro-theme.conf \
  /usr/share/plymouth/themes/ro-theme

# Açılış teması (16 · PLY-08): tema seçilir ve yalnız çalışan çekirdeğin initramfs'i bir kez üretilir.
# Çekirdek parametrelerine (rhgb quiet) dokunulmaz; o kurulum programının işi (PLY-09). Açılış zincirini
# değiştirdiği için önce VM'de denenmeli (Ro-Theme-Docs 16).
if command -v plymouth-set-default-theme >/dev/null 2>&1; then
  if ! run_optional "plymouth theme activation" plymouth-set-default-theme ro-theme -R; then
    echo "Preview files were installed, but Plymouth activation failed. Fix the error and retry before rebooting." >&2
    exit 1
  fi
else
  echo "plymouth-set-default-theme not found; Plymouth files were copied only." >&2
  echo "System preview files installed; Plymouth activation was skipped."
  echo "Debug command: ./scripts/diagnose.sh"
  exit 0
fi

echo "System preview installed. Reboot to test Plasma Login Manager and boot screen."
echo "Debug command: ./scripts/diagnose.sh"
