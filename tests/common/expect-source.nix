{ lib, runCommand }:
/**
  Builds a check that verifies which files made it through a crane source
  filter.

  # Arguments

  - `name`: a name for the check, used in its derivation name and errors.
  - `src`: the filtered source to inspect, e.g. a crane package's
    `passthru.commonArgs.src`.
  - `includes`: paths, relative to the source root, that must exist.
  - `excludes`: paths, relative to the source root, that must not exist.

  # Example

  ```nix
  testLib.expectSource {
    name = "my-crate";
    src = package.passthru.commonArgs.src;
    includes = [ "src/main.rs" ];
    excludes = [ "devenv.nix" ];
  }
  ```
*/
{
  name,
  src,
  includes ? [ ],
  excludes ? [ ],
}:
runCommand "${name}-source-test" { } ''
  cd ${src}

  for path in ${lib.escapeShellArgs includes}; do
    if [ ! -e "$path" ]; then
      echo "error: $path is missing from ${name}'s source. is it kept by the source filter?" >&2
      exit 1
    fi
  done

  for path in ${lib.escapeShellArgs excludes}; do
    if [ -e "$path" ] || [ -L "$path" ]; then
      echo "error: $path leaked into ${name}'s source, so editing it would rebuild everything." >&2
      exit 1
    fi
  done

  touch $out
''
