{ config, lib, ... }:
let
  cfg = config.languages.rust.crane;

  # keys consumed by `mkArgs` itself, rather than forwarded to crane.
  consumedKeys = [
    "crossSystem"
    "pkgs"
    "craneLib"
    "crateExpression"
    "features"
    "noDefaultFeatures"
    "allFeatures"
    "locked"
    "cargoExtraArgs"
    "src"
    "extraPaths"
    "extraFileTypes"
  ];

  # builds the shared arguments for a crane build: the source, the
  # (possibly cross) craneLib, resolved cargo flags, and a single
  # `cargoArtifacts`/`cargoVendorDir` pair that every derivation built from
  # the result should reuse verbatim.
  #
  # this is the one place `buildDepsOnly` and `vendorCargoDeps` are called
  # with implicit defaults; every other builder in this module is expected
  # to thread the resulting `cargoArtifacts`/`cargoVendorDir` through
  # explicitly, so that identical inputs always produce identical (and
  # therefore cache-hitting) dependency builds. see:
  # https://crane.dev/faq/constant-rebuilds.html
  mkArgs =
    path: args:
    let
      # instantiated once and shared with mkLib, since cross builds
      # re-import nixpkgs on every call
      pkgs = args.pkgs or (cfg.mkPkgs { crossSystem = args.crossSystem or null; });
      craneLib = args.craneLib or (cfg.mkLib { inherit pkgs; });

      src =
        args.src or (cfg.mkSource path {
          extraPaths = args.extraPaths or [ ];
          extraFileTypes = args.extraFileTypes or [ ];
        });

      splicedArgs = cfg.spliceCrateExpression pkgs (args.crateExpression or (_: { }));

      features = args.features or [ ];

      # setting cargoExtraArgs at all replaces crane's own "--locked"
      # default, so it's re-added here unless the caller opts out. cargo
      # rejects the flag twice, hence an option instead of a raw flag.
      cargoExtraArgs = lib.concatStringsSep " " (
        lib.optional (args.locked or true) "--locked"
        ++ lib.optional (args.noDefaultFeatures or false) "--no-default-features"
        ++ lib.optional (args.allFeatures or false) "--all-features"
        ++ lib.optional (features != [ ]) "--features ${lib.concatStringsSep "," features}"
        ++ lib.optional (args ? cargoExtraArgs) args.cargoExtraArgs
      );

      extra = builtins.removeAttrs args consumedKeys;

      commonArgs = {
        inherit src;
        strictDeps = true;
      }
      // extra
      // splicedArgs
      // {
        buildInputs = (extra.buildInputs or [ ]) ++ splicedArgs.buildInputs;
        nativeBuildInputs = (extra.nativeBuildInputs or [ ]) ++ splicedArgs.nativeBuildInputs;
        inherit cargoExtraArgs;
      };

      cargoArtifacts = commonArgs.cargoArtifacts or (craneLib.buildDepsOnly commonArgs);
      cargoVendorDir = commonArgs.cargoVendorDir or (craneLib.vendorCargoDeps { inherit src; });
    in
    {
      inherit
        craneLib
        pkgs
        src
        cargoArtifacts
        cargoVendorDir
        ;
      commonArgs = commonArgs // {
        inherit cargoArtifacts cargoVendorDir;
      };
    };
in
{
  options.languages.rust.crane.mkArgs = lib.mkOption {
    type = lib.types.functionTo (lib.types.functionTo lib.types.raw);
    readOnly = true;
    internal = true;
    description = ''
      Computes the shared crane build inputs (source, craneLib,
      cargoArtifacts, cargoVendorDir, and merged commonArgs) for a Cargo
      project. Used internally by `import`, `importWorkspace`, and
      `languages.rust.dioxus.import`.
    '';
  };

  config.languages.rust.crane.mkArgs = mkArgs;
}
