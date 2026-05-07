#!/usr/bin/env bash
set -euo pipefail

# Crash-safe local test runner for Ro Dark/Ro Light.
# It records a timestamp, applies both themes without enabling the KWin JS effect,
# then reports new Plasma/KWin/KIO coredumps and recent warning logs.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

START="$(date '+%Y-%m-%d %H:%M:%S')"
errors=0
skip_lookandfeel=0
runtime_notes=""
install_ok=0

section() {
  printf '\n== %s ==\n' "$1"
}

run_step() {
  local label="$1"
  shift
  local output
  local status

  section "$label"
  printf 'command:'
  printf ' %q' "$@"
  printf '\n'

  set +e
  output="$("$@" 2>&1)"
  status=$?
  set -e

  if [[ "$status" -eq 0 ]]; then
    printf '[OK] %s\n' "$label"
    [[ -n "$output" ]] && printf '%s\n' "$output"
    return 0
  fi

  printf '[FAIL] %s exited with status %d\n' "$label" "$status" >&2
  [[ -n "$output" ]] && printf '%s\n' "$output" >&2
  errors=$((errors + 1))
  return 1
}

skip_step() {
  local label="$1"
  local reason="$2"

  section "$label"
  printf '[SKIP] %s\n' "$reason"
}

runtime_preflight() {
  local checker="./scripts/check-plasma-runtime.sh"
  local mode
  local output
  local status

  section "Runtime Preflight"

  if [[ ! -x "$checker" ]]; then
    printf '[WARN] %s is missing; lookandfeeltool will be skipped for safety\n' "$checker" >&2
    skip_lookandfeel=1
    runtime_notes="runtime checker is missing"
    return 0
  fi

  for mode in popups layout; do
    set +e
    output="$("$checker" "$mode" 2>&1)"
    status=$?
    set -e

    printf '%s\n' "$output"
    if [[ "$status" -ne 0 ]]; then
      skip_lookandfeel=1
      if [[ -z "$runtime_notes" ]]; then
        runtime_notes="$mode preflight failed"
      else
        runtime_notes="$runtime_notes; $mode preflight failed"
      fi
    fi
  done

  if [[ "$skip_lookandfeel" -eq 1 ]]; then
    printf '[WARN] lookandfeeltool steps will be skipped: %s\n' "$runtime_notes" >&2
    printf '[WARN] This avoids forcing broken stock plasmoids into plasmashell during crash-safe testing.\n' >&2
  else
    printf '[OK] Plasma runtime preflight passed; lookandfeeltool steps are enabled\n'
  fi
}

check_new_crashes() {
  section "New Crash Check"

  if ! command -v coredumpctl >/dev/null 2>&1; then
    echo "[WARN] coredumpctl not found; crash check skipped" >&2
    return 0
  fi

  local crashes
  crashes="$(coredumpctl list --since "$START" 2>&1 | grep -E '/usr/bin/plasmashell|/usr/bin/kwin|/usr/bin/kwin_wayland|/usr/libexec/kf6/kioworker' || true)"

  if [[ -n "$crashes" ]]; then
    echo "[FAIL] New Plasma/KWin/KIO coredumps appeared after test start: $START" >&2
    printf '%s\n' "$crashes" >&2
    errors=$((errors + 1))
  else
    echo "[OK] No new Plasma/KWin/KIO coredumps after test start: $START"
  fi
}

section "Start"
echo "Test started at: $START"
echo "KWin JavaScript effect stays disabled in this test."
echo "Live PlasmaShell DBus refresh stays disabled unless explicitly enabled."

run_step "Generate" ./scripts/generate-theme.sh || true
run_step "Validate" ./scripts/validate.sh || true
if run_step "Install Local" ./tools/dev/install-local.sh; then
  install_ok=1
else
  install_ok=0
fi
runtime_preflight

if [[ "$install_ok" -eq 0 ]]; then
  skip_step "Theme Switches" "Local install failed; apply/diagnose steps were skipped to avoid cascading false failures."
else
  run_step "Apply Dark" ./tools/dev/apply-theme.sh dark || true
  if [[ "$skip_lookandfeel" -eq 0 ]]; then
    run_step "LookAndFeel Dark" lookandfeeltool -a org.ro.dark --resetLayout || true
  else
    skip_step "LookAndFeel Dark" "Plasma runtime preflight failed; active config was applied with tools/dev/apply-theme.sh instead."
  fi
  run_step "Diagnose Dark" ./scripts/diagnose.sh --local || true
  run_step "Apply Light" ./tools/dev/apply-theme.sh light || true
  if [[ "$skip_lookandfeel" -eq 0 ]]; then
    run_step "LookAndFeel Light" lookandfeeltool -a org.ro.light --resetLayout || true
  else
    skip_step "LookAndFeel Light" "Plasma runtime preflight failed; active config was applied with tools/dev/apply-theme.sh instead."
  fi
  run_step "Diagnose Light" ./scripts/diagnose.sh --local || true
  run_step "Apply Dark Again" ./tools/dev/apply-theme.sh dark || true
  if [[ "$skip_lookandfeel" -eq 0 ]]; then
    run_step "LookAndFeel Dark Again" lookandfeeltool -a org.ro.dark --resetLayout || true
  else
    skip_step "LookAndFeel Dark Again" "Plasma runtime preflight failed; active config was applied with tools/dev/apply-theme.sh instead."
  fi
  run_step "Final Diagnose" ./scripts/diagnose.sh --local || true
fi

check_new_crashes

section "Recent User Warnings"
journalctl --user -b --since "$START" -p warning..alert 2>/dev/null | tail -n 120 || true

printf '\nLocal safe test summary: %d error(s)\n' "$errors"

if [[ "$errors" -ne 0 ]]; then
  echo "Local safe test failed. See the [FAIL] blocks above." >&2
  exit 1
fi

echo "Local safe test passed."
