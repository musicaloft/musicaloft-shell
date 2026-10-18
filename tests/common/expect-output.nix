{ lib, runCommand }:
/**
  Builds a check that runs a shell command and compares everything it
  prints to stdout against an expected string.

  # Arguments

  - `name`: a name for the check, used in its derivation name and errors.
  - `command`: the shell command to run.
  - `expected`: the exact output the command must print, without the
    trailing newline.
  - `nativeBuildInputs`: extra tools the command needs on `PATH`.

  # Example

  ```nix
  testLib.expectOutput {
    name = "hello";
    command = "${hello}/bin/hello";
    expected = "Hello, world!";
  }
  ```
*/
{
  name,
  command,
  expected,
  nativeBuildInputs ? [ ],
}:
runCommand "${name}-output-test" { inherit nativeBuildInputs; } ''
  actual="$(${command})"
  expected=${lib.escapeShellArg expected}

  if [ "$actual" != "$expected" ]; then
    echo "error: ${name} didn't print what it should have." >&2
    echo "  expected: $expected" >&2
    echo "  actual:   $actual" >&2
    exit 1
  fi

  printf '%s\n' "$actual" > $out
''
