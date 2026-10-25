#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../common/lib.sh"

# the sandbox is gone, so keep wasmtime from writing a compilation cache to
# the home directory
wasmtime_run() {
  wasmtime run -C cache=n "$@"
}

# crates/experimental matches the `crates/*` glob, but is excluded
expect_equal "workspace members" \
  "workspace-cli workspace-core workspace-stats" \
  "$TEST_MEMBERS"

# cargo only inherits the workspace version when a member opts in, and
# defaults to 0.0.0 when a member sets no version at all
expect_equal "member versions" \
  "workspace-cli=1.2.3 workspace-core=0.3.0 workspace-stats=0.0.0" \
  "$TEST_VERSIONS"

# each member's main program is inferred from its own Cargo.toml
expect_equal "member main programs" \
  "workspace-cli=workspace-cli workspace-core=workspace-core workspace-stats=workspace-stats" \
  "$TEST_MAIN_PROGRAMS"

# every member must reuse the single workspace-wide dependency build
for pair in $TEST_MEMBER_DEPS; do
  expect_equal "${pair%%=*}'s dependency build" "$TEST_WORKSPACE_DEPS" "${pair#*=}"
done

expect_output "cli" "[Workspace Cli] ready" "$TEST_CLI/bin/workspace-cli"
expect_output "stats" "5 words" "$TEST_STATS/bin/workspace-stats"

expect_output "cli on wasi" "[Workspace Cli] ready" \
  wasmtime_run "$TEST_WASI_CLI/bin/workspace-cli.wasm"
expect_output "stats on wasi" "5 words" \
  wasmtime_run "$TEST_WASI_STATS/bin/workspace-stats.wasm"

finish
