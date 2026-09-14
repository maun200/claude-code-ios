#!/usr/bin/env bash
# Build the community Claude Code iOS .deb as an overlay/repack on top of the
# pinned upstream base package, instead of checking extracted proprietary
# sources (the Node runtime, the Claude Code CLI itself) into git.
#
# What this does:
#   1. Verifies debs/claude-code_2.1.19-1_iphoneos-arm64.deb against the
#      checksum pinned in scripts/base-deb.sha256 (refuses to build on top
#      of a base package that doesn't match exactly).
#   2. Extracts its control.tar.xz and data.tar.xz.
#   3. Removes the ClaudeCode.app home-screen launcher entirely.
#   4. Overlays this repo's small, non-proprietary files on top:
#        overlay/control/{control,postinst}
#        overlay/data/...            (currently just the two wrapper scripts)
#   5. Recomputes Installed-Size and repacks a new .deb with a bumped
#      package revision.
#
# Usage:
#   scripts/build-repack.sh [--base PATH_TO_BASE_DEB] [--out OUTPUT_DIR]
#
# Defaults: --base debs/claude-code_2.1.19-1_iphoneos-arm64.deb, --out debs/
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

BASE_DEB="debs/claude-code_2.1.19-1_iphoneos-arm64.deb"
OUT_DIR="debs"

while [ $# -gt 0 ]; do
    case "$1" in
        --base) BASE_DEB="$2"; shift 2 ;;
        --out) OUT_DIR="$2"; shift 2 ;;
        *) echo "build-repack.sh: unknown argument: $1" >&2; exit 64 ;;
    esac
done

# Normalize to absolute paths so this still works when the caller passes an
# absolute --base/--out (as the test suite does from a scratch tmpdir).
case "$BASE_DEB" in
    /*) : ;;
    *) BASE_DEB="$REPO_ROOT/$BASE_DEB" ;;
esac
case "$OUT_DIR" in
    /*) : ;;
    *) OUT_DIR="$REPO_ROOT/$OUT_DIR" ;;
esac

if [ ! -f "$BASE_DEB" ]; then
    echo "build-repack.sh: base .deb not found: $BASE_DEB" >&2
    exit 66
fi

# --- 1. verify the base package is exactly the pinned upstream build -------
CHECKSUM_FILE="scripts/base-deb.sha256"
PINNED_SUM="$(awk '{print $1}' "$CHECKSUM_FILE")"
PINNED_NAME="$(awk '{print $2}' "$CHECKSUM_FILE")"
ACTUAL_SUM="$(sha256sum "$BASE_DEB" | awk '{print $1}')"

if [ "$(basename "$BASE_DEB")" != "$PINNED_NAME" ]; then
    echo "build-repack.sh: warning: base deb filename '$(basename "$BASE_DEB")' does not match pinned name '$PINNED_NAME'" >&2
fi

if [ "$ACTUAL_SUM" != "$PINNED_SUM" ]; then
    echo "build-repack.sh: refusing to build - base .deb checksum mismatch" >&2
    echo "  expected: $PINNED_SUM" >&2
    echo "  actual:   $ACTUAL_SUM" >&2
    echo "  file:     $BASE_DEB" >&2
    exit 65
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# --- 2. extract the base package --------------------------------------------
mkdir -p "$WORK/base" "$WORK/control" "$WORK/data"
(cd "$WORK/base" && ar x "$BASE_DEB")
tar -xJf "$WORK/base/control.tar.xz" -C "$WORK/control"
tar -xJf "$WORK/base/data.tar.xz" -C "$WORK/data"

# --- 3. remove the home-screen app entirely ---------------------------------
rm -rf "$WORK/data/var/jb/Applications"

# --- 4. apply the overlay ----------------------------------------------------
cp -a overlay/data/. "$WORK/data/"
find overlay/data -type f -print0 | while IFS= read -r -d '' f; do
    rel="${f#overlay/data/}"
    chmod 0755 "$WORK/data/$rel"
    chown 1000:1000 "$WORK/data/$rel"
done

cp overlay/control/control "$WORK/control/control"
cp overlay/control/postinst "$WORK/control/postinst"
chmod 0644 "$WORK/control/control"
chmod 0755 "$WORK/control/postinst"
chown 0:0 "$WORK/control/control" "$WORK/control/postinst"

# --- 5. recompute Installed-Size and repack ----------------------------------
INSTALLED_SIZE_KB="$(du -sk --apparent-size "$WORK/data" | awk '{print $1}')"
sed -i "s/^Installed-Size: .*/Installed-Size: $INSTALLED_SIZE_KB/" "$WORK/control/control"

VERSION="$(awk -F': ' '/^Version:/{print $2; exit}' "$WORK/control/control")"
PACKAGE="$(awk -F': ' '/^Package:/{print $2; exit}' "$WORK/control/control")"
ARCH="$(awk -F': ' '/^Architecture:/{print $2; exit}' "$WORK/control/control")"

if [ -z "$VERSION" ] || [ -z "$PACKAGE" ] || [ -z "$ARCH" ]; then
    echo "build-repack.sh: could not read Package/Version/Architecture from overlay control" >&2
    exit 70
fi

# Normalize all timestamps to a fixed epoch so the resulting tar/xz/deb is
# byte-for-byte reproducible regardless of extraction timing or wall clock.
# Must run last: sed -i above rewrites control (new inode via rename), which
# would otherwise re-stamp both the file and its parent directory with "now".
find "$WORK/data" "$WORK/control" -exec touch -h -d "@0" {} +

tar --sort=name -cf - -C "$WORK/control" . | xz -T1 -9e > "$WORK/control.tar.xz"
tar --sort=name -cf - -C "$WORK/data" . | xz -T1 -9e > "$WORK/data.tar.xz"
echo "2.0" > "$WORK/debian-binary"

mkdir -p "$OUT_DIR"
OUT_DEB="$OUT_DIR/${PACKAGE#com.anthropic.}_${VERSION}_${ARCH}.deb"
rm -f "$OUT_DEB"
(cd "$WORK" && ar rcD "$OUT_DEB" debian-binary control.tar.xz data.tar.xz)

echo "Built $OUT_DEB"
echo "  Version:        $VERSION"
echo "  Installed-Size: ${INSTALLED_SIZE_KB} KB"
echo "  SHA256:         $(sha256sum "$OUT_DEB" | awk '{print $1}')"
