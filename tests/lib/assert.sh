#!/usr/bin/env bash
# Minimal TAP-ish assertion helpers shared by the test scripts in this
# directory. No external test framework is required on the build host.

TESTS_RUN=0
TESTS_FAILED=0
CURRENT_FILE="${0##*/}"

pass() {
    TESTS_RUN=$((TESTS_RUN + 1))
    printf 'ok %d - %s\n' "$TESTS_RUN" "$1"
}

fail() {
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf 'not ok %d - %s\n' "$TESTS_RUN" "$1"
    if [ -n "${2:-}" ]; then
        printf '    %s\n' "$2"
    fi
}

assert_contains() {
    local haystack_file="$1" needle="$2" desc="$3"
    if grep -qF -- "$needle" "$haystack_file"; then
        pass "$desc"
    else
        fail "$desc" "expected to find: $needle"
    fi
}

assert_not_contains() {
    local haystack_file="$1" needle="$2" desc="$3"
    if grep -qF -- "$needle" "$haystack_file"; then
        fail "$desc" "did not expect to find: $needle"
    else
        pass "$desc"
    fi
}

assert_file_exists() {
    local path="$1" desc="$2"
    if [ -e "$path" ]; then
        pass "$desc"
    else
        fail "$desc" "missing path: $path"
    fi
}

assert_file_absent() {
    local path="$1" desc="$2"
    if [ -e "$path" ]; then
        fail "$desc" "unexpected path present: $path"
    else
        pass "$desc"
    fi
}

assert_eq() {
    local actual="$1" expected="$2" desc="$3"
    if [ "$actual" = "$expected" ]; then
        pass "$desc"
    else
        fail "$desc" "expected [$expected] got [$actual]"
    fi
}

test_summary_and_exit() {
    echo "1..$TESTS_RUN"
    if [ "$TESTS_FAILED" -gt 0 ]; then
        echo "# $CURRENT_FILE: $TESTS_FAILED/$TESTS_RUN failed" >&2
        exit 1
    fi
    echo "# $CURRENT_FILE: $TESTS_RUN passed"
    exit 0
}
