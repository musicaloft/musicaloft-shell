#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../common/lib.sh"

# the stylesheet must include classes from both the app crate and the ui
# crate, which tailwind.css pulls in with @source
stylesheet_classes() {
  cat "$TEST_PACKAGE"/bin/public/assets/tailwind-*.css \
    | grep --only-matching --fixed-strings --regexp .italic --regexp .text-3xl \
    | sort --unique \
    | tr '\n' ' '
}

wait_for_processes

# cargo resolves `version.workspace = true` from the workspace root
expect_equal "the package's name" web "$TEST_PNAME"
expect_equal "the package's version" 0.1.0 "$TEST_VERSION"

# the default source must hold the whole workspace, not just the app
expect_files "dioxus-workspace's source" "$TEST_SOURCE" \
  Cargo.lock \
  Cargo.toml \
  packages/api/src/lib.rs \
  packages/ui/assets/banner.css \
  packages/ui/src/lib.rs \
  packages/web/Dioxus.toml \
  packages/web/assets/tailwind.css \
  packages/web/src/main.rs \
  packages/web/tailwind.css

expect_no_files "dioxus-workspace's source" "$TEST_SOURCE" \
  .devenv \
  devenv.lock \
  devenv.nix \
  devenv.yaml \
  target

expect_page "$TEST_SERVER_URL" / "hello from the web crate"
expect_page "$TEST_SERVER_URL" / "hello from the ui crate"

# rendered on the server through use_server_future
expect_page "$TEST_SERVER_URL" / "the api crate says hello"
expect_page "$TEST_SERVER_URL" /api/greeting "the api crate says hello"

expect_wasm_client "$TEST_SERVER_URL" "$TEST_PACKAGE/bin/public"

expect_output "tailwind" ".italic .text-3xl " stylesheet_classes

finish
