#!/usr/bin/env bash
# Tests for the overlay wrapper scripts that replace the ones shipped in the
# upstream community .deb. These are pure text/content checks and do not
# require building a package, so they run fast and need no network access.
set -u
cd "$(dirname "$0")/.."
. tests/lib/assert.sh

CLAUDE_WRAPPER="overlay/data/var/jb/usr/local/bin/claude"
CLAUDE_AUTH="overlay/data/var/jb/usr/local/bin/claude-auth"

assert_file_exists "$CLAUDE_WRAPPER" "claude wrapper exists in overlay"
assert_file_exists "$CLAUDE_AUTH" "claude-auth stub exists in overlay"

# --- credential gate must be gone -----------------------------------------
assert_not_contains "$CLAUDE_WRAPPER" "AUTH_OK" \
    "claude wrapper has no AUTH_OK credential gate"
assert_not_contains "$CLAUDE_WRAPPER" "is not authenticated" \
    "claude wrapper does not block on missing credentials"

# --- old OAuth/localhost callback must be gone ----------------------------
assert_not_contains "$CLAUDE_AUTH" "createServer" \
    "claude-auth no longer runs its own HTTP server"
assert_not_contains "$CLAUDE_AUTH" "19283" \
    "claude-auth no longer hardcodes the old callback port"
assert_not_contains "$CLAUDE_AUTH" "oauth/authorize" \
    "claude-auth no longer implements its own OAuth authorize step"
assert_not_contains "$CLAUDE_AUTH" "code_verifier" \
    "claude-auth no longer implements its own PKCE flow"
for f in "$CLAUDE_WRAPPER" "$CLAUDE_AUTH"; do
    assert_not_contains "$f" "127.0.0.1:19283" "$f has no legacy localhost callback URL"
done

# --- required iOS/accessibility/UTF-8 env vars ----------------------------
assert_contains "$CLAUDE_WRAPPER" "CLAUDE_CODE_ACCESSIBILITY" \
    "claude wrapper sets CLAUDE_CODE_ACCESSIBILITY"
assert_contains "$CLAUDE_WRAPPER" 'CLAUDE_CODE_ACCESSIBILITY:-1' \
    "claude wrapper defaults CLAUDE_CODE_ACCESSIBILITY to 1"
assert_contains "$CLAUDE_WRAPPER" "USE_BUILTIN_RIPGREP" \
    "claude wrapper sets USE_BUILTIN_RIPGREP to use system ripgrep"
assert_contains "$CLAUDE_WRAPPER" 'USE_BUILTIN_RIPGREP:-1' \
    "claude wrapper defaults USE_BUILTIN_RIPGREP to 1"
assert_contains "$CLAUDE_WRAPPER" "LANG" "claude wrapper sets LANG for UTF-8"
assert_contains "$CLAUDE_WRAPPER" "LC_ALL" "claude wrapper sets LC_ALL for UTF-8"
assert_contains "$CLAUDE_WRAPPER" "UTF-8" "claude wrapper references UTF-8 locale"

# --- HOME must be correct for both root and mobile ------------------------
assert_contains "$CLAUDE_WRAPPER" "/var/jb/var/root" \
    "claude wrapper knows root's home directory"
assert_contains "$CLAUDE_WRAPPER" "/var/jb/var/mobile" \
    "claude wrapper knows mobile's home directory"
assert_contains "$CLAUDE_WRAPPER" 'id -u' \
    "claude wrapper distinguishes root from mobile by uid"

# --- must still exec the real CLI, unchanged core behavior -----------------
assert_contains "$CLAUDE_WRAPPER" "cli.js" \
    "claude wrapper still execs the official cli.js"
assert_contains "$CLAUDE_WRAPPER" "segmenter-shim.js" \
    "claude wrapper still loads the Intl.Segmenter shim"
assert_contains "$CLAUDE_WRAPPER" "exec " \
    "claude wrapper execs node instead of forking"

# --- claude-auth must defer to the official CLI ---------------------------
assert_contains "$CLAUDE_AUTH" "claude" \
    "claude-auth stub points users at the claude command"
assert_contains "$CLAUDE_AUTH" "setup-token" \
    "claude-auth stub mentions headless setup-token flow"

# --- shell syntax sanity ---------------------------------------------------
if command -v zsh >/dev/null 2>&1; then
    if zsh -n "$CLAUDE_WRAPPER" 2>/tmp/claude_wrapper_syntax.$$; then
        pass "claude wrapper passes zsh -n syntax check"
    else
        fail "claude wrapper passes zsh -n syntax check" "$(cat /tmp/claude_wrapper_syntax.$$)"
    fi
    rm -f /tmp/claude_wrapper_syntax.$$
    if zsh -n "$CLAUDE_AUTH" 2>/tmp/claude_auth_syntax.$$; then
        pass "claude-auth stub passes zsh -n syntax check"
    else
        fail "claude-auth stub passes zsh -n syntax check" "$(cat /tmp/claude_auth_syntax.$$)"
    fi
    rm -f /tmp/claude_auth_syntax.$$
else
    pass "zsh not available on build host, skipping zsh -n check"
fi

test_summary_and_exit
