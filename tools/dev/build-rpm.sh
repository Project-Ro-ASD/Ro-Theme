#!/usr/bin/env bash
set -euo pipefail

# Ro tema RPM build yardımcısı.
# Kaynak tarball'ı temiz bir ro-theme-VERSION köküyle üretir, rpmbuild çalıştırır
# ve oluşan RPM'i tools/dev/test-rpm.sh ile kurulum öncesi test eder.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

NAME="ro-theme"
VERSION="$(tr -d '[:space:]' < VERSION)"
# rpmbuild hazırlık sırasında kendi dizinlerine cd eder; _topdir mutlak olmalıdır.
# Göreli özelleştirme, önceki davranış gibi depo köküne göre değerlendirilir.
TOPDIR="$(realpath -m -- "${RPMBUILD_TOPDIR:-$ROOT/build/rpmbuild}")"
SOURCE_DIR="$TOPDIR/SOURCES"
SPEC_FILE="$ROOT/packaging/ro-theme.spec"
FEDORA_RELEASE="${FEDORA_RELEASE:-44}"

echo "Generating theme outputs..."
./scripts/generate-theme.sh

echo "Validating source tree..."
./scripts/validate.sh

mkdir -p "$SOURCE_DIR" "$TOPDIR/BUILD" "$TOPDIR/RPMS" "$TOPDIR/SRPMS" "$TOPDIR/SPECS"

STAGE_ROOT="$(mktemp -d)"
trap 'rm -rf "$STAGE_ROOT"' EXIT

STAGE="$STAGE_ROOT/$NAME-$VERSION"
mkdir -p "$STAGE"

for item in .github assets core dist docs platform scripts tools packaging README.md LICENSE LICENSES VERSION; do
  cp -a "$item" "$STAGE/"
done

tar -czf "$SOURCE_DIR/$NAME-$VERSION.tar.gz" -C "$STAGE_ROOT" "$NAME-$VERSION"
echo "Source tarball ready: $SOURCE_DIR/$NAME-$VERSION.tar.gz"

for rpm_tool in rpmbuild rpmspec; do
  if ! command -v "$rpm_tool" >/dev/null 2>&1; then
    echo "$rpm_tool command not found. Install Fedora build tools: sudo dnf install -y rpm-build dracut plymouth plymouth-plugin-two-step" >&2
    echo "After installing rpm-build, rerun: ./tools/dev/build-rpm.sh" >&2
    exit 2
  fi
done

RPM_MACROS=(--define "_topdir $TOPDIR" --define "_tmppath ${TMPDIR:-/tmp}" --define "dist .fc${FEDORA_RELEASE}")
# Test edilecek çıktı aynı makrolarla spec'ten belirlenir; dosya tarihi eski bir Fedora
# veya başka mimari paketini yeni derlemenin sonucu gibi göstermemelidir.
RPM_FILENAME="$(rpmspec "${RPM_MACROS[@]}" --query --rpms \
  --queryformat '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}.rpm\n' "$SPEC_FILE")"
if [[ "$RPM_FILENAME" == *$'\n'* || "$RPM_FILENAME" == */* || "$RPM_FILENAME" != "$NAME-$VERSION-"*.noarch.rpm ]]; then
  echo "Expected exactly one ro-theme $VERSION noarch package from $SPEC_FILE; got: $RPM_FILENAME" >&2
  exit 1
fi

echo "Building Fedora ${FEDORA_RELEASE} RPM..."
rpmbuild "${RPM_MACROS[@]}" -ba "$SPEC_FILE"

RPM_PATH="$TOPDIR/RPMS/noarch/$RPM_FILENAME"
if [[ ! -f "$RPM_PATH" ]]; then
  echo "Build finished but the expected RPM file was not found: $RPM_PATH" >&2
  exit 1
fi

echo "Testing RPM: $RPM_PATH"
./tools/dev/test-rpm.sh "$RPM_PATH"

echo "RPM ready: $RPM_PATH"
