#!/usr/bin/env bash
# Run all test suites for the overlay/repack build. No network access or
# device connection required - everything here runs on the build host.
set -u
cd "$(dirname "$0")/.."

status=0
for t in tests/test_overlay_wrapper.sh tests/test_repack_build.sh; do
    echo "=== $t ==="
    if ! bash "$t"; then
        status=1
    fi
    echo
done

if [ "$status" -eq 0 ]; then
    echo "All test suites passed."
else
    echo "One or more test suites failed." >&2
fi
exit "$status"
