#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../common/lib.sh"

# dx regenerates the stylesheet with tailwind, which only emits the utility
# classes it finds in the sources
count_tailwind_stylesheets() {
  { grep --recursive --files-with-matches --include='*.css' \
    --fixed-strings .text-3xl "$TEST_PACKAGE/bin/public" || true; } | wc -l
}

wait_for_processes

expect_page "$TEST_SERVER_URL" / "hello from dioxus simple"

# rendered on the server through use_server_future
expect_page "$TEST_SERVER_URL" / "the server says hello"
expect_page "$TEST_SERVER_URL" /api/greeting "the server says hello"

expect_wasm_client "$TEST_SERVER_URL" "$TEST_PACKAGE/bin/public"

expect_output "tailwind" 1 count_tailwind_stylesheets

finish
