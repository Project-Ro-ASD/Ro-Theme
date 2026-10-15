#!/usr/bin/env bash
set -euo pipefail

# Temiz test konteynerinde bağımlılık çözümünü kurmadan denetler. DNF'nin --assumeno iptali
# de hata kodu döndürür; yalnızca açık işlem özeti ve beklenen iptal başarı sayılır.
RPM_PATH="${1:-}"
if [[ -z "$RPM_PATH" || ! -f "$RPM_PATH" ]]; then
  echo "Usage: $0 NEW.rpm (run in a clean Fedora test container)" >&2
  exit 2
fi

status=0
output="$(LC_ALL=C dnf --setopt=skip_if_unavailable=False install --assumeno "$RPM_PATH" 2>&1)" || status=$?
if [[ "$status" -eq 1 ]] \
    && grep -q '^Transaction Summary:' <<< "$output" \
    && grep -qE '^ ro-theme[[:space:]]' <<< "$output" \
    && grep -q '^Operation aborted by the user\.$' <<< "$output"; then
  printf '%s\n' "$output"
  echo "Dependency resolution passed; RPM transaction was not executed."
else
  echo "Dependency resolution failed or returned an unexpected result (dnf exit $status)." >&2
  printf '%s\n' "$output" >&2
  exit 1
fi
