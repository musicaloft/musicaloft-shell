#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../common/lib.sh"

expect_output "loaded" "loaded zlib $TEST_ZLIB_VERSION" "$TEST_PACKAGE/bin/crane-runtime"

finish
