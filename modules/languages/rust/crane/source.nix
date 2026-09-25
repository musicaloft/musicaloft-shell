{ config, lib, ... }:
let
  cfg = config.languages.rust.crane;

  # builds a fileset-based source for a crane build rooted at `root`.
  #
  # tracks the same files as `craneLib.cleanCargoSource` (rust sources,
  # toml files, and Cargo.lock), so unrelated changes (flake.nix,
  # devenv.nix, README.md, ...) never invalidate cached cargoArtifacts, but
  # as a fileset so per-build extras can be unioned in. see:
  # https://crane.dev/faq/constant-rebuilds.html
  mkSource =
    root:
    {
      extraPaths ? [ ],
      extraFileTypes ? [ ],
    }:
    let
      # accept both root-relative strings and path literals; interpolating
      # a path literal into a string would copy it to the store instead
      toPath = p: if builtins.isPath p then p else root + "/${p}";

      # devenv evaluates the working tree directly rather than a git
      # checkout, so local build outputs (build-script `.rs` files under
      # target/, generated toml under .devenv/) would otherwise match the
      # filters above and churn the source hash on every local build
      localOutputs = lib.fileset.unions (
        map (p: lib.fileset.maybeMissing (root + "/${p}")) [
          "target"
          ".devenv"
          ".direnv"
          "result"
        ]
      );
    in
    lib.fileset.toSource {
      inherit root;
      fileset = lib.fileset.difference (lib.fileset.unions (
        [ (cfg.lib.fileset.commonCargoSources root) ]
        ++ lib.optional (extraFileTypes != [ ]) (
          lib.fileset.fileFilter (file: builtins.any file.hasExt extraFileTypes) root
        )
        ++ map (p: lib.fileset.maybeMissing (toPath p)) extraPaths
      )) localOutputs;
    };
in
{
  options.languages.rust.crane.mkSource = lib.mkOption {
    type = lib.types.functionTo (lib.types.functionTo lib.types.package);
    readOnly = true;
    description = ''
      Builds a source derivation for a crane build rooted at the given
      path, filtered down to Rust sources, toml files, and Cargo.lock.

      The second argument is an attribute set of per-build extras:

      - `extraPaths`: files or directories to keep in full, either as
        strings relative to the root or as path literals. Paths that don't
        exist are silently ignored.
      - `extraFileTypes`: file extensions (without the leading dot) to keep
        anywhere under the root, e.g. `[ "html" "css" ]` for files read via
        `include_str!`.

      Example usage:
      ```nix
      config.languages.rust.crane.mkSource ./. {
        extraPaths = [ "assets" ];
        extraFileTypes = [ "sql" ];
      }
      ```
    '';
  };

  config.languages.rust.crane.mkSource = mkSource;
}
