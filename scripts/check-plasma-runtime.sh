#!/usr/bin/env bash
set -euo pipefail

# Plasma runtime preflight.
# Full panel layouts are skipped when required stock plasmoids are missing or
# incomplete, because adding broken applets can crash plasmashell.

MODE="${1:-layout}"
errors=0
warnings=0

ok() {
  printf '  [OK] %s\n' "$1"
}

warn() {
  printf '  [WARN] %s\n' "$1" >&2
  warnings=$((warnings + 1))
}

fail() {
  printf '  [FAIL] %s\n' "$1" >&2
  errors=$((errors + 1))
}

candidate_dirs() {
  local package="$1"
  printf '%s\n' \
    "$HOME/.local/share/plasma/plasmoids/$package" \
    "/usr/share/plasma/plasmoids/$package"
}

candidate_plugin_files() {
  local plugin="$1"
  printf '%s\n' \
    "$HOME/.local/lib/qt6/plugins/plasma/applets/$plugin.so" \
    "$HOME/.local/lib64/qt6/plugins/plasma/applets/$plugin.so" \
    "/usr/lib64/qt6/plugins/plasma/applets/$plugin.so" \
    "/usr/lib/qt6/plugins/plasma/applets/$plugin.so" \
    "/usr/lib64/qt5/plugins/plasma/applets/$plugin.so" \
    "/usr/lib/qt5/plugins/plasma/applets/$plugin.so"
}

find_package_dir() {
  local package="$1"
  local dir

  while IFS= read -r dir; do
    if [[ -d "$dir" ]]; then
      echo "$dir"
      return 0
    fi
  done < <(candidate_dirs "$package")

  return 1
}

find_plugin_file() {
  local plugin="$1"
  local path

  while IFS= read -r path; do
    if [[ -f "$path" ]]; then
      echo "$path"
      return 0
    fi
  done < <(candidate_plugin_files "$plugin")

  return 1
}

has_metadata() {
  local dir="$1"
  [[ -f "$dir/metadata.json" || -f "$dir/metadata.desktop" ]]
}

metadata_file() {
  local dir="$1"
  if [[ -f "$dir/metadata.json" ]]; then
    echo "$dir/metadata.json"
  elif [[ -f "$dir/metadata.desktop" ]]; then
    echo "$dir/metadata.desktop"
  fi
}

metadata_root_plugin() {
  local dir="$1"
  local metadata
  metadata="$(metadata_file "$dir")"
  [[ -n "$metadata" ]] || return 1

  sed -n 's/.*"X-Plasma-RootPath"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p; s/^X-Plasma-RootPath[[:space:]]*=[[:space:]]*\(.*\)$/\1/p' "$metadata" | head -n 1
}

has_mainscript() {
  local dir="$1"
  [[ -f "$dir/contents/ui/main.qml" || -f "$dir/ui/main.qml" ]]
}

check_plasmoid() {
  local package="$1"
  local required="$2"
  local dir=""
  local plugin_file=""
  local root_plugin=""
  local severity="fail"

  if [[ "$required" != "required" ]]; then
    severity="warn"
  fi

  if ! dir="$(find_package_dir "$package")"; then
    if plugin_file="$(find_plugin_file "$package")"; then
      ok "$package (Plasma 6 plugin: $plugin_file)"
      return
    fi

    if [[ "$required" = "required" ]]; then
      fail "missing stock plasmoid/plugin: $package"
    else
      warn "optional stock plasmoid/plugin missing: $package"
    fi
    return
  fi

  if ! has_metadata "$dir"; then
    if plugin_file="$(find_plugin_file "$package")"; then
      ok "$package (metadata-less Plasma plugin: $plugin_file)"
    else
      "$severity" "plasmoid has no metadata: $package ($dir)"
    fi
    return
  fi

  if has_mainscript "$dir"; then
    ok "$package"
    return
  fi

  if plugin_file="$(find_plugin_file "$package")"; then
    ok "$package (Plasma plugin: $plugin_file)"
    return
  fi

  root_plugin="$(metadata_root_plugin "$dir")"
  if [[ -n "$root_plugin" ]] && plugin_file="$(find_plugin_file "$root_plugin")"; then
    ok "$package (root plugin: $root_plugin)"
    return
  fi

  "$severity" "plasmoid has no main QML file or Plasma plugin: $package ($dir)"
}

echo "Checking Plasma runtime for $MODE..."

case "$MODE" in
  layout)
    check_plasmoid org.kde.plasma.kickoff required
    check_plasmoid org.kde.plasma.showdesktop required
    check_plasmoid org.kde.plasma.panelspacer required
    check_plasmoid org.kde.plasma.digitalclock required
    check_plasmoid org.kde.plasma.systemtray required
    check_plasmoid org.kde.plasma.icontasks required
    ;;
  popups)
    check_plasmoid org.kde.plasma.systemtray required
    check_plasmoid org.kde.plasma.brightness optional
    check_plasmoid org.kde.plasma.battery optional
    ;;
  *)
    echo "Usage: $0 [layout|popups]" >&2
    exit 2
    ;;
esac

printf 'Plasma runtime summary: %d error(s), %d warning(s)\n' "$errors" "$warnings"

if [[ "$errors" -ne 0 ]]; then
  if [[ "$MODE" = "layout" ]]; then
    echo "Unsafe to apply the full Ro panel layout on the current system." >&2
  else
    echo "Plasma popup runtime is incomplete on the current system." >&2
  fi
  echo "This is a system Plasma package/runtime problem, not a theme color problem." >&2
  exit 1
fi

exit 0
