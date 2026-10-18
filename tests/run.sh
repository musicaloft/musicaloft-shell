#!/usr/bin/env bash
# Builds every output of musicaloft-shell's test projects, which includes
# their packages, crane checks, and tests.
#
# Usage: tests/run.sh [project...]
#
# With no arguments, every project under tests/ is built. Otherwise, only
# the named projects are, e.g. `tests/run.sh crane-simple dioxus-simple`.

set -euo pipefail

tests_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

projects=("$@")
if [ ${#projects[@]} -eq 0 ]; then
  for dir in "$tests_dir"/*/; do
    # shared modules like common/ aren't projects of their own
    if [ -f "$dir/devenv.nix" ]; then
      projects+=("$(basename "$dir")")
    fi
  done
fi

passed=()
failed=()

for project in "${projects[@]}"; do
  dir="$tests_dir/$project"

  if [ ! -f "$dir/devenv.nix" ]; then
    echo "error: there's no test project named '$project' in $tests_dir." >&2
    failed+=("$project")
    continue
  fi

  echo "==> building $project"

  # keep going past a failed derivation, so one run reports every failure
  # in the project instead of only the first
  if (cd "$dir" && devenv --nix-option keep-going true build); then
    passed+=("$project")
  else
    failed+=("$project")
  fi
done

echo
echo "${#passed[@]} passed: ${passed[*]:-none}"
echo "${#failed[@]} failed: ${failed[*]:-none}"

[ ${#failed[@]} -eq 0 ]
