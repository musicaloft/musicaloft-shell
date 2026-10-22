# shellcheck shell=bash
#
# Assertion helpers shared by every test project's `.test.sh`.
#
# Source it from a test script, run the assertions, and end the script with
# `finish`:
#
#   source "$(dirname "${BASH_SOURCE[0]}")/../common/lib.sh"
#
#   expect_output "greeting" "hello" "$TEST_PACKAGE/bin/hello"
#   finish
#
# A failed assertion prints what went wrong and is counted, but doesn't stop
# the script, so one run reports every failure. `finish` exits non-zero if
# any assertion failed. Test scripts shouldn't use `set -e` for the same
# reason.

failures=0

# Records a failure with a message.
#
# Arguments: the message, printed to stderr.
fail() {
  echo "error: $*" >&2
  failures=$((failures + 1))
}

# Records that an assertion passed.
#
# Arguments: the name of the assertion.
pass() {
  echo "ok: $1"
}

# Checks that two strings are equal.
#
# Arguments: a name for the assertion, the expected value, and the actual
# value.
expect_equal() {
  local name="$1" expected="$2" actual="$3"

  if [ "$actual" = "$expected" ]; then
    pass "$name"
  else
    fail "$name isn't what it should be."
    echo "  expected: $expected" >&2
    echo "  actual:   $actual" >&2
  fi
}

# Checks that a command prints exactly the expected string to stdout.
#
# Arguments: a name for the assertion, the expected output without its
# trailing newline, and the command to run with its arguments. To test a
# pipeline, wrap it in a shell function or `bash -c`.
expect_output() {
  local name="$1" expected="$2"
  shift 2

  local actual
  if ! actual="$("$@")"; then
    fail "$name's command failed: $*"
    return 0
  fi

  expect_equal "$name" "$expected" "$actual"
}

# Checks that every path exists under a directory.
#
# Arguments: a name for the assertion, the directory, and the paths relative
# to it.
expect_files() {
  local name="$1" root="$2" path missing=0
  shift 2

  for path in "$@"; do
    if [ ! -e "$root/$path" ]; then
      fail "$path is missing from $name. is it kept by the source filter?"
      missing=1
    fi
  done

  if [ "$missing" -eq 0 ]; then
    pass "$name includes its files"
  fi
}

# Checks that no path exists under a directory.
#
# Arguments: a name for the assertion, the directory, and the paths relative
# to it.
expect_no_files() {
  local name="$1" root="$2" path leaked=0
  shift 2

  for path in "$@"; do
    if [ -e "$root/$path" ] || [ -L "$root/$path" ]; then
      fail "$path leaked into $name, so editing it would rebuild everything."
      leaked=1
    fi
  done

  if [ "$leaked" -eq 0 ]; then
    pass "$name excludes its files"
  fi
}

# Checks that a page from a running server contains a string.
#
# Arguments: the server's base url, the path to fetch, and the string the
# response body must contain.
expect_page() {
  local url="$1" path="$2" contains="$3" body

  if ! body="$(curl --silent --show-error --fail "$url$path")"; then
    fail "couldn't serve $path. is the route defined?"
    return 0
  fi

  if [[ "$body" != *"$contains"* ]]; then
    echo "$body" >&2
    fail "$path is missing '$contains' (its response is above)."
    return 0
  fi

  pass "$path contains '$contains'"
}

# Checks that a running server serves a bundled wasm client with the right
# content type. Without its wasm client, a page renders but never becomes
# interactive.
#
# Arguments: the server's base url, and the directory the server serves its
# public files from.
expect_wasm_client() {
  local url="$1" public="$2" wasm content_type

  wasm="$(cd "$public" && find . -name '*.wasm' -print -quit)"
  if [ -z "$wasm" ]; then
    fail "there's no wasm client in $public. did dx bundle the web target?"
    return 0
  fi

  if ! content_type="$(curl --silent --fail --output /dev/null \
    --write-out '%{content_type}' "$url/${wasm#./}")"; then
    fail "couldn't serve the wasm client at /${wasm#./}."
    return 0
  fi

  expect_equal "the wasm client's content type" application/wasm "$content_type"
}

# Ends a test script, exiting non-zero if any assertion failed.
finish() {
  if [ "$failures" -gt 0 ]; then
    echo "$failures assertion(s) failed." >&2
    exit 1
  fi
}
