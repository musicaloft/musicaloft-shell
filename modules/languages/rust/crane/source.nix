{ config, lib, ... }:
let
  cfg = config.languages.rust.crane;

  # builds a fileset-based source for a crane build rooted at `root`.
  #
  # unlike `src = ./.` or even `craneLib.cleanCargoSource`, this only tracks
  # the files a cargo build can actually depend on, so unrelated changes
  # (flake.nix, devenv.nix, README.md, ...) never invalidate cached
  # cargoArtifacts. see: https://crane.dev/faq/constant-rebuilds.html
  mkSource =
    root:
    let
      craneLib = config.languages.rust.crane.lib;
      extraFileTypes = cfg.src.extraFileTypes;
    in
    lib.fileset.toSource {
      inherit root;
      fileset = lib.fileset.unions (
        [ (craneLib.fileset.commonCargoSources root) ]
        ++ lib.optional (extraFileTypes != [ ]) (
          lib.fileset.fileFilter (file: builtins.any file.hasExt extraFileTypes) root
        )
        ++ map (path: lib.fileset.maybeMissing path) cfg.src.extraPaths
      );
    };
in
{
  options.languages.rust.crane = {
    src.extraFileTypes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "html"
        "css"
      ];
      description = ''
        File extensions (without the leading dot) to keep in crane's source
        filter, in addition to the Rust and Cargo files crane tracks by
        default.

        Useful for projects that read non-Rust files at compile time, e.g.
        via `include_str!` or Dioxus's `asset!` macro.
      '';
    };

    src.extraPaths = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      example = [ ./assets ];
      description = ''
        Additional paths to keep in crane's source filter, in full,
        regardless of file extension. Paths that don't exist are silently
        ignored.
      '';
    };

    mkSource = lib.mkOption {
      type = lib.types.functionTo lib.types.package;
      readOnly = true;
      description = ''
        Builds a source derivation for a crane build rooted at the given
        path, filtered down to Cargo/Rust files plus `src.extraFileTypes`
        and `src.extraPaths`.
      '';
    };
  };

  config.languages.rust.crane.mkSource = mkSource;
}
