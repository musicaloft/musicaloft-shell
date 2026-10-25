#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../common/lib.sh"

expect_output "default" "hello from Crane Simple!" "$TEST_PACKAGE/bin/crane-simple"
expect_output "shouting" "HELLO FROM CRANE SIMPLE!" "$TEST_SHOUTING/bin/crane-simple"

expect_equal "inferred main program" "crane-simple" "$TEST_MAIN_PROGRAM"
expect_equal "main program set by the caller" "custom-name" "$TEST_MAIN_PROGRAM_OVERRIDE"
expect_equal "dependency build's main program" "none" "$TEST_DEPS_MAIN_PROGRAM"

expect_files "crane-simple's source" "$TEST_SOURCE" \
  Cargo.lock \
  Cargo.toml \
  src/greeting.txt \
  src/lib.rs \
  src/main.rs

expect_no_files "crane-simple's source" "$TEST_SOURCE" \
  .cargo/config.toml \
  .devenv \
  .rustfmt.toml \
  devenv.lock \
  devenv.nix \
  devenv.yaml \
  target

finish
