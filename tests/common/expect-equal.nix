{ lib, runCommand }:
/**
  Builds a check that compares two Nix values.

  The comparison happens during evaluation, but a mismatch only fails the
  check's build, so it's reported alongside every other failing test
  instead of aborting evaluation for the whole project.

  # Arguments

  - `name`: a name for the check, used in its derivation name and errors.
  - `actual`: the value under test. It must be serializable to JSON.
  - `expected`: the value `actual` must equal.

  # Example

  ```nix
  testLib.expectEqual {
    name = "member-names";
    actual = builtins.attrNames workspace.packages;
    expected = [ "cli" "core" ];
  }
  ```
*/
{
  name,
  actual,
  expected,
}:
let
  toJSON = value: lib.escapeShellArg (builtins.toJSON value);
in
runCommand "${name}-equality-test" { } (
  if actual == expected then
    "touch $out"
  else
    ''
      echo "error: ${name} isn't what it should be." >&2
      echo "  expected: "${toJSON expected} >&2
      echo "  actual:   "${toJSON actual} >&2
      exit 1
    ''
)
