#!/usr/bin/env bash
set -euo pipefail

# "Ro görünümüne dön" aracı (22 SYS-07 B). Yalnızca çalıştıran kullanıcı için ve yalnızca kullanıcı
# kendisi çalıştırdığında kullanılır; paket betikleri bu aracı çağırmaz.
#
# Yöntem: Ro'nun /etc/xdg altında yönettiği anahtarların satırları kullanıcının ~/.config dosyalarından
# kaldırılır. KDE ayar zinciri (XDG_CONFIG_DIRS) sayesinde kullanıcı o anahtarlar için sistem varsayılanına
# döner; değerlerin kopyası bu betikte tutulmaz. Değişiklikten önce dosyaların yedeği alınır.
#
# NOT: kwriteconfig6 --delete kullanılmaz. Alt katmanda (/etc/xdg) aynı anahtar varsa kwriteconfig6
# "anahtar[$d]" işareti yazar; bu işaret sistem varsayılanını da gizler. Satır doğrudan kaldırılır.

SYSTEM_XDG="${RO_THEME_SYSTEM_XDG:-/etc/xdg}"
USER_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
FILES=(kdeglobals kcmfonts breezerc plasmarc ksplashrc kscreenlockerrc kwinrc)
# Eski sürümün kullanıcı dosyalarına yazdığı, artık yönetilmeyen anahtarlar: "dosya|[grup]|anahtar"
LEGACY_KEYS=(
  "kdeglobals|[KDE]|ColorScheme"
  "kwinrc|[Plugins]|kwin4_effect_scaleEnabled"
  "kwinrc|[Plugins]|kwin4_effect_glideEnabled"
  "kwinrc|[Plugins]|kwin4_effect_squashEnabled"
  "kwinrc|[Plugins]|kwin4_effect_magiclampEnabled"
  "kwinrc|[Plugins]|kwin4_effect_windowapertureEnabled"
  "kwinrc|[Plugins]|kwin4_effect_frozenappEnabled"
  "kwinrc|[Plugins]|ro-smooth-motionEnabled"
  "kwinrc|[Plugins]|magiclampEnabled"
)
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: apply-dark-defaults [--current-user] [--dry-run]

Reset the Ro-managed appearance settings of the current user to the Ro-ASD
system defaults. Only keys that Ro-Theme ships in /etc/xdg are removed from
your ~/.config files; everything else is kept. A backup is written to
~/.config/ro-theme/backup-<date>-<random>/ first.
If preparation or backup fails, no settings are changed.

  --current-user  apply to the user running the command (default)
  --dry-run       show what would change, change nothing
EOF
}

for arg in "$@"; do
  case "$arg" in
    --current-user) ;;
    --dry-run) DRY_RUN=1 ;;
    --all-users|--force)
      echo "apply-dark-defaults: $arg was removed; the tool only changes the current user's own settings." >&2
      exit 2
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "apply-dark-defaults: unknown option: $arg" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ "$(id -u)" -eq 0 ]]; then
  echo "apply-dark-defaults: run this as your own user, not as root." >&2
  exit 2
fi

# Yönetilen anahtarlar: sistem dosyasındaki her "[grup]<TAB>anahtar" çifti + eski sürüm anahtarları.
managed_list() {
  local f="$1"
  if [[ -f "$SYSTEM_XDG/$f" ]]; then
    awk '/^\[.*\]$/ { g = $0; next }
         /^[^#].*=/ && g != "" { k = $0; sub(/=.*/, "", k); sub(/\[[^]]*\]$/, "", k); print g "\t" k }' "$SYSTEM_XDG/$f" || return 1
  fi
  local entry ef eg ek
  for entry in "${LEGACY_KEYS[@]}"; do
    IFS='|' read -r ef eg ek <<< "$entry"
    [[ "$ef" = "$f" ]] && printf '%s\t%s\n' "$eg" "$ek"
  done
  return 0
}

# Kullanıcı dosyasından yönetilen anahtar satırlarını (yerelleştirilmiş "anahtar[tr]=" ve "anahtar[$d]"
# biçimleri dahil) kaldırır; boş kalan grupları atar. Kaldırılan satırlar stderr'e yazılır.
filter_user_file() {
  awk -F'\t' -v file="$2" '
    FILENAME == ARGV[1] { m[$1 SUBSEP $2] = 1; next }
    /^\[.*\]$/ { g = $0; pending = $0; next }
    {
      k = $0
      if (k ~ /=/ || k ~ /\[\$[a-z]+\]$/) {
        sub(/=.*/, "", k); while (k ~ /\[[^]]*\]$/) sub(/\[[^]]*\]$/, "", k)
        if ((g SUBSEP k) in m) { print "reset: " file " " g " " k > "/dev/stderr"; next }
      }
      if ($0 == "") next
      if (pending != "") {
        if (printed) print ""
        print pending; pending = ""; printed = 1
      }
      print
    }' "$1" "$3"
}

fail() {
  echo "apply-dark-defaults: $*" >&2
  [[ -z "$backup_dir" ]] || echo "Backup directory: $backup_dir" >&2
  exit 1
}

backup_dir=""
work_dir=""
changed_files=()
staged_files=()
cleanup() {
  [[ -z "$work_dir" ]] || rm -rf -- "$work_dir"
  if (( ${#staged_files[@]} )); then
    rm -f -- "${staged_files[@]}"
  fi
  return 0
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
work_dir="$(mktemp -d)" || fail "cannot create temporary workspace."

# Bütün dosyaları önce hazırla. Okuma/filtreleme hatası yedek veya ayar değişikliği başlatmaz.
changed=0
for f in "${FILES[@]}"; do
  [[ -e "$USER_CONFIG/$f" || -L "$USER_CONFIG/$f" ]] || continue
  [[ -f "$USER_CONFIG/$f" && ! -L "$USER_CONFIG/$f" ]] || fail "expected a regular, non-symlink config file: $USER_CONFIG/$f"
  cp -p -- "$USER_CONFIG/$f" "$work_dir/$f.original" || fail "cannot read $f; settings were not changed."
  managed_list "$f" > "$work_dir/$f.keys" || fail "cannot read managed settings for $f."
  if ! filter_user_file "$work_dir/$f.keys" "$f" "$work_dir/$f.original" > "$work_dir/$f.out" 2> "$work_dir/$f.log"; then
    cat "$work_dir/$f.log" >&2
    fail "cannot read or filter $f."
  fi
  if [[ -s "$work_dir/$f.log" ]]; then
    changed_files+=("$f")
    changed=$((changed + $(wc -l < "$work_dir/$f.log")))
  fi
done

if [[ "$DRY_RUN" -eq 1 ]]; then
  for f in "${changed_files[@]}"; do
    sed 's/^reset:/would reset:/' "$work_dir/$f.log"
  done
  exit 0
fi

if (( ${#changed_files[@]} )); then
  mkdir -p -- "$USER_CONFIG/ro-theme" || fail "cannot create backup parent directory."
  backup_dir="$(mktemp -d "$USER_CONFIG/ro-theme/backup-$(date +%Y%m%d-%H%M%S)-XXXXXX")" || fail "cannot create backup directory."
  # Tek bir yedek bile alınamıyorsa hiçbir ayar dosyasına dokunma.
  for f in "${changed_files[@]}"; do
    cp -p -- "$work_dir/$f.original" "$backup_dir/$f" || fail "cannot back up $f; settings were not changed."
  done
  # Aynı dosya sisteminde hazırla; mv başarısızsa özgün dosya kesilmez veya silinmez.
  for f in "${changed_files[@]}"; do
    staged="$(mktemp "$USER_CONFIG/.ro-theme-reset.XXXXXX")" || fail "cannot stage $f; settings were not changed."
    staged_files+=("$staged")
    cat "$work_dir/$f.out" > "$staged" || fail "cannot write staged $f; settings were not changed."
    chmod --reference="$USER_CONFIG/$f" -- "$staged" || fail "cannot preserve permissions for $f."
  done
  for i in "${!changed_files[@]}"; do
    f="${changed_files[$i]}"
    # Hazırlık sırasında değişen kullanıcı dosyasını eski bir kopyayla ezme.
    current_hash="$(sha256sum < "$USER_CONFIG/$f")" || fail "cannot reread $f; stopping."
    original_hash="$(sha256sum < "$backup_dir/$f")" || fail "cannot read backup for $f; stopping."
    [[ "$current_hash" = "$original_hash" ]] || fail "$f changed during reset; stopping."
    mv -f -- "${staged_files[$i]}" "$USER_CONFIG/$f" || fail "cannot replace $f; restore any earlier changes from the backup if needed."
  done
fi

# Eski işareti yalnızca başarılı bir sıfırlamadan sonra kaldır.
rm -f -- "$USER_CONFIG/ro-theme/default-dark-applied" || fail "cannot remove the legacy marker."
echo "Ro appearance settings reset to the system defaults: $changed setting(s) removed from your files."
[[ -z "$backup_dir" ]] || echo "Backup: $backup_dir"
if [[ "$changed" -gt 0 ]]; then
  echo "Log out and back in to see all changes."
fi
