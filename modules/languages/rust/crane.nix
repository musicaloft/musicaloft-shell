{ config, lib, ... }:
let
  cfg = config.languages.rust.crane;

  # imports a single Cargo package (crate) using crane.
  import' =
    path: args:
    let
      result = cfg.mkArgs path (args // { doCheck = args.doCheck or false; });
      pkg = result.craneLib.buildPackage result.commonArgs;
    in
    pkg.overrideAttrs (old: {
      passthru = (old.passthru or { }) // {
        craneLib = result.craneLib;
        commonArgs = result.commonArgs;
        cargoArtifacts = result.cargoArtifacts;
        checks = cfg.mkChecks result;
      };
    });
in
{
  imports = [
    ./crane/args.nix
    ./crane/checks.nix
    ./crane/lib.nix
    ./crane/source.nix
  ];

  options.languages.rust.crane.import = lib.mkOption {
    type = lib.types.functionTo (lib.types.functionTo lib.types.package);
    readOnly = true;
    description = ''
      Import a single Cargo package using crane.

      This function takes a path to a directory containing a Cargo.toml
      file and returns a derivation that builds the Rust project using
      crane, with dependency artifacts cached in a separate derivation so
      editing the crate's own source never rebuilds its dependencies. The
      returned package carries `passthru.checks` (`clippy`, `doc`, `fmt`,
      `nextest`, `taplo`), `passthru.craneLib`, `passthru.commonArgs`, and
      `passthru.cargoArtifacts`, all reusing the same dependency build.

      The `args` attribute set accepts everything `craneLib.buildPackage`
      does, plus:

      - `crossSystem`: a Nixpkgs `crossSystem` value to cross-compile for.
      - `crateExpression`: a `pkgs.callPackage`-style function returning
        extra `buildInputs`/`nativeBuildInputs`, spliced onto the correct
        build/host/target `pkgs` when cross-compiling.
      - `features`, `noDefaultFeatures`, `allFeatures`: cargo feature
        flags, folded into `cargoExtraArgs` consistently across the
        dependency build and every check.

      Example usage:
      ```nix
      let
        mypackage = config.languages.rust.crane.import ./path/to/cargo/project { };
      in {
        languages.rust.enable = true;
        packages = [ mypackage ];
      }
      ```
    '';
  };

  config.languages.rust.crane.import = import';
}
