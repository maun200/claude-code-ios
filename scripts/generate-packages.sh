#!/usr/bin/env bash
# Regenerate the repo's Packages index (and compressed variants) from the
# .deb files in debs/. Run this after scripts/build-repack.sh produces a new
# revision. Depiction/SileoDepiction are pointed at this repo's own
# depiction pages, overriding whatever placeholder URL is baked into each
# .deb's internal control file.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

BASE_URL="https://imcynic.github.io/claude-code-ios"
OUT="Packages"
: > "$OUT"

first=1
for deb in debs/*.deb; do
    [ -e "$deb" ] || continue
    pkgid="$(dpkg-deb -f "$deb" Package)"

    if [ "$first" -eq 0 ]; then
        echo >> "$OUT"
    fi
    first=0

    {
        dpkg-deb -f "$deb" Package Version Architecture Maintainer \
            Installed-Size Depends Conflicts Provides
        printf 'Filename: %s\n' "$deb"
        printf 'Size: %s\n' "$(stat -c '%s' "$deb")"
        printf 'MD5sum: %s\n' "$(md5sum "$deb" | awk '{print $1}')"
        printf 'SHA1: %s\n' "$(sha1sum "$deb" | awk '{print $1}')"
        printf 'SHA256: %s\n' "$(sha256sum "$deb" | awk '{print $1}')"
        dpkg-deb -f "$deb" Section Description Tag Author
        printf 'Depiction: %s/depictions/%s.html\n' "$BASE_URL" "$pkgid"
        printf 'Name: %s\n' "$(dpkg-deb -f "$deb" Name)"
        printf 'SileoDepiction: %s/depictions/%s.json\n' "$BASE_URL" "$pkgid"
    } >> "$OUT"
done
echo >> "$OUT"

gzip -9 -k -f -c "$OUT" > "$OUT.gz"
bzip2 -9 -k -f -c "$OUT" > "$OUT.bz2"
xz -9e -k -f -c "$OUT" > "$OUT.xz"

echo "Regenerated $OUT (+ .gz/.bz2/.xz) from $(ls debs/*.deb | wc -l) package(s)."
