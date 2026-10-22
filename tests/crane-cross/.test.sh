#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../common/lib.sh"

# keep wasmtime from writing a compilation cache to the home directory
wasmtime_run() {
  wasmtime run -C cache=n "$@"
}

# rust links musl binaries statically, which is what makes them portable
linkage_of() {
  file --brief "$1" | grep --only-matching static | head -n 1
}

expect_output "native" \
  "hello from x86_64-unknown-linux-gnu with zlib $TEST_ZLIB_VERSION, 2 + 3 = 5" \
  "$TEST_NATIVE/bin/crane-cross"

expect_output "aarch64" \
  "hello from aarch64-unknown-linux-gnu with zlib $TEST_AARCH64_ZLIB_VERSION, 2 + 3 = 5" \
  "$TEST_AARCH64_EMULATOR" "$TEST_AARCH64/bin/crane-cross"

# x86_64 machines run musl binaries natively
expect_output "musl" \
  "hello from $TEST_MUSL_SYSTEM, 2 + 3 = 5" \
  "$TEST_MUSL/bin/crane-cross"

expect_output "musl is static" static linkage_of "$TEST_MUSL/bin/crane-cross"

# the bare module has no entry point, so call its exported function
expect_output "wasm32" 5 \
  wasmtime_run --invoke add "$TEST_WASM32/lib/crane_cross.wasm" 2 3

expect_output "wasi" "hello from wasm32-wasip1, 2 + 3 = 5" \
  wasmtime_run "$TEST_WASI/bin/crane-cross.wasm"

finish
