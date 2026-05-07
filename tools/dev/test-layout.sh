#!/usr/bin/env bash
set -euo pipefail

# Ro layout test scripti
# Repo içindeki Plasma layout.js dosyasını PlasmaShell DBus API üzerinden çalıştırır.
# KDE'nin güncel dokümantasyonunda önerilen yöntem:
# qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(cat /path/to/file.js)"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LAYOUT="$ROOT/platform/plasma/layout-templates/org.ro.desktop/contents/layout.js"

cd "$ROOT"

if [[ ! -f "$LAYOUT" ]]; then
  echo "Layout file not found: $LAYOUT" >&2
  exit 1
fi

if ! ./scripts/check-plasma-runtime.sh layout; then
  echo "" >&2
  echo "Ro full panel layout was not applied to avoid another plasmashell crash." >&2
  echo "Your current Plasma install is missing required stock widget files." >&2
  echo "Wallpaper and Ro Dark/Ro Light global themes can still be tested safely." >&2
  exit 1
fi

if ! pgrep -x plasmashell >/dev/null 2>&1; then
  echo "plasmashell is not running; starting it..." >&2
  plasmashell >/dev/null 2>&1 &
  sleep 3
fi

SCRIPT_CONTENT="$(cat "$LAYOUT")"
LAST_ERROR=""

try_qdbus() {
  local bus="$1"
  command -v "$bus" >/dev/null 2>&1 || {
    LAST_ERROR+=$'\n'"missing command: $bus"
    return 1
  }

  local out status
  set +e
  out="$($bus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$SCRIPT_CONTENT" 2>&1)"
  status=$?
  set -e
  if [[ $status -eq 0 ]]; then
    return 0
  fi
  LAST_ERROR+=$'\n'"$bus full method failed: $out"

  set +e
  out="$($bus org.kde.plasmashell /PlasmaShell evaluateScript "$SCRIPT_CONTENT" 2>&1)"
  status=$?
  set -e
  if [[ $status -eq 0 ]]; then
    return 0
  fi
  LAST_ERROR+=$'\n'"$bus short method failed: $out"

  return 1
}

try_gdbus() {
  command -v gdbus >/dev/null 2>&1 || {
    LAST_ERROR+=$'\n'"missing command: gdbus"
    return 1
  }

  local out status
  set +e
  out="$(gdbus call --session \
    --dest org.kde.plasmashell \
    --object-path /PlasmaShell \
    --method org.kde.PlasmaShell.evaluateScript \
    "$SCRIPT_CONTENT" 2>&1)"
  status=$?
  set -e
  if [[ $status -eq 0 ]]; then
    return 0
  fi
  LAST_ERROR+=$'\n'"gdbus failed: $out"
  return 1
}

if try_qdbus qdbus6 || try_qdbus qdbus || try_qdbus qdbus-qt6 || try_qdbus qdbus-qt5 || try_gdbus; then
  echo "Ro layout applied."
else
  echo "PlasmaShell evaluateScript call failed." >&2
  echo "$LAST_ERROR" >&2
  echo "" >&2
  echo "Manual debug:" >&2
  echo "  qdbus6 org.kde.plasmashell /PlasmaShell | grep -i evaluate" >&2
  echo "  qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript 'print(\"ro dbus ok\")'" >&2
  echo "" >&2
  echo "If qdbus6 is missing on Fedora, install it with:" >&2
  echo "  sudo dnf install qt6-qttools" >&2
  exit 1
fi
