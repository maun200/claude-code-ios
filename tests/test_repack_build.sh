#!/usr/bin/env bash
# Structural tests for scripts/build-repack.sh. These build a real .deb from
# the pinned upstream base package plus the overlay in this repo, then
# inspect it with dpkg-deb/ar/tar. No device or network access required.
set -u
cd "$(dirname "$0")/.."
. tests/lib/assert.sh

BUILD_SCRIPT="scripts/build-repack.sh"
BASE_DEB="debs/claude-code_2.1.19-1_iphoneos-arm64.deb"

assert_file_exists "$BUILD_SCRIPT" "build-repack.sh exists"
assert_file_exists "$BASE_DEB" "pinned upstream base .deb is present"

if [ ! -x "$BUILD_SCRIPT" ] && [ ! -f "$BUILD_SCRIPT" ]; then
    echo "1..1"
    fail "build-repack.sh exists" "cannot continue without it"
    test_summary_and_exit
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
OUT_DIR="$WORK/out"
mkdir -p "$OUT_DIR"

# --- happy path: build against the real pinned base deb --------------------
BUILD_LOG="$WORK/build.log"
if bash "$BUILD_SCRIPT" --out "$OUT_DIR" >"$BUILD_LOG" 2>&1; then
    pass "build-repack.sh runs successfully against the pinned base .deb"
else
    fail "build-repack.sh runs successfully against the pinned base .deb" "$(cat "$BUILD_LOG")"
fi

NEW_DEB="$(find "$OUT_DIR" -maxdepth 1 -name '*.deb' | head -n1)"
if [ -n "$NEW_DEB" ]; then
    pass "build-repack.sh produced a .deb file"
else
    fail "build-repack.sh produced a .deb file" "no .deb found in $OUT_DIR"
    test_summary_and_exit
fi

assert_eq "$(basename "$NEW_DEB")" "claude-code_2.1.112-1_iphoneos-arm64.deb" \
    "output .deb is named with the upgraded CLI version"

VERSION="$(dpkg-deb -f "$NEW_DEB" Version)"
assert_eq "$VERSION" "2.1.112-1" "control Version is 2.1.112-1"

DEPENDS="$(dpkg-deb -f "$NEW_DEB" Depends)"
case "$DEPENDS" in
    *ripgrep*) pass "control Depends includes ripgrep" ;;
    *) fail "control Depends includes ripgrep" "Depends: $DEPENDS" ;;
esac
case "$DEPENDS" in
    *git*) pass "control Depends includes git" ;;
    *) fail "control Depends includes git" "Depends: $DEPENDS" ;;
esac

FILELIST="$WORK/filelist.txt"
dpkg-deb -c "$NEW_DEB" > "$FILELIST"

assert_not_contains "$FILELIST" "ClaudeCode.app" \
    "packaged file list has no trace of ClaudeCode.app"
assert_contains "$FILELIST" "./var/jb/usr/local/bin/claude" \
    "packaged file list still ships the claude binary"
assert_contains "$FILELIST" "./var/jb/usr/local/bin/claude-auth" \
    "packaged file list still ships the claude-auth stub"

EXTRACT="$WORK/extract"
mkdir -p "$EXTRACT"
dpkg-deb -e "$NEW_DEB" "$EXTRACT/control"
dpkg-deb -x "$NEW_DEB" "$EXTRACT/data"

assert_not_contains "$EXTRACT/control/postinst" "ClaudeCode.app" \
    "postinst no longer references ClaudeCode.app"
assert_not_contains "$EXTRACT/control/postinst" "uicache" \
    "postinst no longer calls uicache for the removed app"

assert_file_absent "$EXTRACT/data/var/jb/Applications" \
    "Applications directory is gone from the packaged data tree"

if diff -q "overlay/data/var/jb/usr/local/bin/claude" \
    "$EXTRACT/data/var/jb/usr/local/bin/claude" >/dev/null 2>&1; then
    pass "packaged claude wrapper matches the overlay source exactly"
else
    fail "packaged claude wrapper matches the overlay source exactly"
fi

CLAUDE_CODE_DIR="$EXTRACT/data/var/jb/usr/local/lib/claude-code/node_modules/@anthropic-ai/claude-code"
BUNDLED_CLI_VERSION="$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$CLAUDE_CODE_DIR/package.json" | head -n1)"
assert_eq "$BUNDLED_CLI_VERSION" "2.1.112" \
    "bundled Claude Code CLI package.json reports the upgraded version"

assert_file_exists "$CLAUDE_CODE_DIR/vendor/ripgrep/arm64-darwin/rg" \
    "upgraded package still ships the (unused-by-default) vendor ripgrep"

# The packaged node binary is an iOS Mach-O build and can't run on the build
# host, but any host Node.js can still syntax-check the extracted cli.js.
if command -v node >/dev/null 2>&1; then
    if node --check "$CLAUDE_CODE_DIR/cli.js" 2>"$WORK/cli_syntax.log"; then
        pass "upgraded cli.js passes node --check on the build host"
    else
        fail "upgraded cli.js passes node --check on the build host" "$(cat "$WORK/cli_syntax.log")"
    fi
else
    pass "no host node available, skipping cli.js syntax check"
fi

INSTALLED_SIZE="$(dpkg-deb -f "$NEW_DEB" Installed-Size)"
if [ -n "$INSTALLED_SIZE" ] && [ "$INSTALLED_SIZE" -gt 0 ] 2>/dev/null && [ "$INSTALLED_SIZE" -lt 142528 ] 2>/dev/null; then
    pass "Installed-Size was recomputed and shrank after removing the app"
else
    fail "Installed-Size was recomputed and shrank after removing the app" "got: $INSTALLED_SIZE"
fi

if dpkg-deb --info "$NEW_DEB" >/dev/null 2>&1; then
    pass "resulting .deb is structurally valid per dpkg-deb --info"
else
    fail "resulting .deb is structurally valid per dpkg-deb --info"
fi

# --- reproducibility: building twice yields identical bytes ---------------
OUT_DIR2="$WORK/out2"
mkdir -p "$OUT_DIR2"
if bash "$BUILD_SCRIPT" --out "$OUT_DIR2" >"$WORK/build2.log" 2>&1; then
    NEW_DEB2="$(find "$OUT_DIR2" -maxdepth 1 -name '*.deb' | head -n1)"
    if [ -n "$NEW_DEB2" ] && [ "$(sha256sum <"$NEW_DEB" | cut -d' ' -f1)" = "$(sha256sum <"$NEW_DEB2" | cut -d' ' -f1)" ]; then
        pass "build is reproducible: rebuilding yields byte-identical output"
    else
        fail "build is reproducible: rebuilding yields byte-identical output"
    fi
else
    fail "build is reproducible: rebuilding yields byte-identical output" "second build failed: $(cat "$WORK/build2.log")"
fi

# --- safety net: refuses to build against a tampered base .deb -------------
TAMPERED_DIR="$WORK/tampered"
mkdir -p "$TAMPERED_DIR"
cp "$BASE_DEB" "$TAMPERED_DIR/claude-code_2.1.19-1_iphoneos-arm64.deb"
printf '\x00' >> "$TAMPERED_DIR/claude-code_2.1.19-1_iphoneos-arm64.deb"
TAMPER_LOG="$WORK/tamper.log"
if bash "$BUILD_SCRIPT" --base "$TAMPERED_DIR/claude-code_2.1.19-1_iphoneos-arm64.deb" --out "$WORK/out3" >"$TAMPER_LOG" 2>&1; then
    fail "build-repack.sh refuses a base .deb that fails checksum verification" "build unexpectedly succeeded"
else
    pass "build-repack.sh refuses a base .deb that fails checksum verification"
fi

# --- safety net: refuses to build against a tampered npm CLI tarball -------
# The happy-path build above already populated the local cache.
NPM_CACHE="$(basename "$(grep -v '^#' scripts/claude-code-npm.sha256 | grep -v '^[[:space:]]*$' | head -n1 | awk '{print $2}')")"
TAMPERED_NPM="$WORK/tampered-claude-code.tgz"
cp ".build-cache/$NPM_CACHE" "$TAMPERED_NPM" 2>/dev/null
if [ -f "$TAMPERED_NPM" ]; then
    printf '\x00' >> "$TAMPERED_NPM"
    TAMPER_NPM_LOG="$WORK/tamper-npm.log"
    if bash "$BUILD_SCRIPT" --npm-tarball "$TAMPERED_NPM" --out "$WORK/out4" >"$TAMPER_NPM_LOG" 2>&1; then
        fail "build-repack.sh refuses a tampered npm CLI tarball" "build unexpectedly succeeded"
    else
        pass "build-repack.sh refuses a tampered npm CLI tarball"
    fi
else
    fail "build-repack.sh refuses a tampered npm CLI tarball" "no cached tarball found to tamper with - did the happy-path build run first?"
fi

test_summary_and_exit
