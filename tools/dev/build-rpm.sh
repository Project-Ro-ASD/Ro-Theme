#!/usr/bin/env bash
set -euo pipefail

# Ro tema RPM build yardımcısı.
# Kaynak tarball'ı temiz bir ro-theme-VERSION köküyle üretir, rpmbuild çalıştırır
# ve oluşan RPM'i tools/dev/test-rpm.sh ile kurulum öncesi test eder.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

NAME="ro-theme"
VERSION="$(tr -d '[:space:]' < VERSION)"
TOPDIR="${RPMBUILD_TOPDIR:-$ROOT/build/rpmbuild}"
SOURCE_DIR="$TOPDIR/SOURCES"
SPEC_FILE="$ROOT/packaging/ro-theme.spec"

echo "Generating theme outputs..."
./scripts/generate-theme.sh

echo "Validating source tree..."
./scripts/validate.sh

mkdir -p "$SOURCE_DIR" "$TOPDIR/BUILD" "$TOPDIR/RPMS" "$TOPDIR/SRPMS" "$TOPDIR/SPECS"

STAGE_ROOT="$(mktemp -d)"
trap 'rm -rf "$STAGE_ROOT"' EXIT

STAGE="$STAGE_ROOT/$NAME-$VERSION"
mkdir -p "$STAGE"

for item in assets core dist docs platform scripts tools packaging README.md LICENSE VERSION; do
  cp -a "$item" "$STAGE/"
done

tar -czf "$SOURCE_DIR/$NAME-$VERSION.tar.gz" -C "$STAGE_ROOT" "$NAME-$VERSION"
echo "Source tarball ready: $SOURCE_DIR/$NAME-$VERSION.tar.gz"

if ! command -v rpmbuild >/dev/null 2>&1; then
  echo "rpmbuild command not found. Fedora/RHEL için: sudo dnf install -y rpm-build dracut grubby plymouth plymouth-plugin-script" >&2
  echo "After installing rpm-build, rerun: ./tools/dev/build-rpm.sh" >&2
  exit 2
fi

echo "Building RPM..."
rpmbuild --define "_topdir $TOPDIR" -ba "$SPEC_FILE"

RPM_PATH="$(find "$TOPDIR/RPMS" -type f -name "$NAME-$VERSION-*.rpm" -printf '%T@ %p\n' | sort -n | tail -n 1 | sed 's/^[^ ]* //')"

if [[ -z "$RPM_PATH" || ! -f "$RPM_PATH" ]]; then
  echo "Build finished but no RPM file was found under $TOPDIR/RPMS." >&2
  exit 1
fi

echo "Testing RPM: $RPM_PATH"
./tools/dev/test-rpm.sh "$RPM_PATH"

echo "RPM ready: $RPM_PATH"
