#!/usr/bin/env bash
# Runs when `devenv test` is run in this repository. Consumers of
# musicaloft-shell only import its devenv.nix, so they never run this.
set -euo pipefail

exec "$(dirname "${BASH_SOURCE[0]}")/tests/run.sh"
