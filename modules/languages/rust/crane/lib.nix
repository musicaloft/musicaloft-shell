{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.languages.rust;

  crane = config.lib.getInput {
    name = "crane";
    url = "github:ipetkov/crane";
    attribute = "languages.rust.crane.lib";
    follows = [ "nixpkgs" ];
  };

  # builds (or reuses) the pkgs set that a crane build should run against.
  #
  # for the native host this is just the shell's own `pkgs`. for a foreign
  # target, nixpkgs is re-instantiated, carrying over devenv's overlays and
  # nixpkgs config so cross builds see the same package set (including
  # rust-overlay, if configured) as the dev shell.
  mkPkgs =
    {
      crossSystem ? null,
    }:
    if crossSystem == null then
      pkgs
    else
      import pkgs.path {
        localSystem = pkgs.stdenv.buildPlatform.system;
        inherit crossSystem;
        overlays = config.overlays;
        inherit (pkgs) config;
      };

  # builds a craneLib instance pinned to the devenv-managed rust toolchain.
  #
  # passing a constant function (rather than the toolchain package directly)
  # to `overrideToolchain` satisfies crane's splicing requirements for cross
  # builds without any additional cost, since the toolchain itself is a
  # build-platform tool that is valid across every splice.
  mkLib =
    {
      crossSystem ? null,
    }:
    let
      targetPkgs = mkPkgs { inherit crossSystem; };
      craneLib = (crane.mkLib targetPkgs).overrideToolchain (_: cfg.toolchainPackage);

      hostPlatform = targetPkgs.stdenv.hostPlatform;
      isCross = targetPkgs.stdenv.buildPlatform != hostPlatform;
      rustcTarget = hostPlatform.rust.rustcTarget;
    in
    lib.warnIf (isCross && !(builtins.elem rustcTarget cfg.targets))
      "languages.rust.crane.mkLib is cross-compiling to '${rustcTarget}', but that target isn't in languages.rust.targets. add it so rustc and rust-std are available for the toolchain."
      craneLib;
in
{
  options.languages.rust.crane = {
    lib = lib.mkOption {
      type = lib.types.raw;
      readOnly = true;
      description = ''
        A crane library instance (`craneLib`) pinned to the devenv-managed
        Rust toolchain and targeting the native host platform.

        This is an escape hatch for callers who want to build crane
        derivations directly rather than going through
        `languages.rust.crane.import` or `languages.rust.crane.importWorkspace`.
      '';
    };

    mkLib = lib.mkOption {
      type = lib.types.functionTo lib.types.raw;
      readOnly = true;
      description = ''
        Builds a crane library instance (`craneLib`) pinned to the
        devenv-managed Rust toolchain, optionally targeting a foreign
        platform for cross-compilation.

        Takes an attribute set:

        - `crossSystem` (optional): a Nixpkgs `crossSystem` value (e.g.
          `"aarch64-linux"`, or an attribute set as accepted by
          `import <nixpkgs> { }`). When set, nixpkgs is re-instantiated for
          that target, carrying over this shell's overlays and nixpkgs
          config, and the returned `craneLib` is bound to that
          cross-instantiated `pkgs`.

        Example usage:
        ```nix
        let
          craneLib = config.languages.rust.crane.mkLib {
            crossSystem = "aarch64-linux";
          };
        in
        craneLib.buildPackage { src = craneLib.cleanCargoSource ./.; }
        ```
      '';
    };

    mkPkgs = lib.mkOption {
      type = lib.types.functionTo lib.types.raw;
      readOnly = true;
      internal = true;
      description = ''
        Builds (or reuses) the `pkgs` set backing `mkLib`'s `craneLib` for a
        given `crossSystem`. Used internally so `crateExpression` callbacks
        can be spliced against the exact same `pkgs` instance a build runs
        against.
      '';
    };
  };

  config.languages.rust.crane = {
    lib = mkLib { };
    inherit mkLib mkPkgs;
  };
}
