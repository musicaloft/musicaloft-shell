{ config, lib, ... }:
let
  cfg = config.languages.rust.crane;

  # keys consumed by `mkArgs` itself, rather than forwarded to crane.
  consumedKeys = [
    "crossSystem"
    "craneLib"
    "crateExpression"
    "features"
    "noDefaultFeatures"
    "allFeatures"
    "cargoExtraArgs"
    "src"
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
      craneLib = args.craneLib or (cfg.mkLib { crossSystem = args.crossSystem or null; });
      pkgs = cfg.mkPkgs { crossSystem = args.crossSystem or null; };

      src = args.src or (cfg.mkSource path);

      # run the caller's crateExpression through callPackage so that
      # nixpkgs can splice buildInputs/nativeBuildInputs onto the correct
      # build/host/target pkgs when cross-compiling. see:
      # https://crane.dev/examples/cross-rust-overlay.html
      splicedArgs = pkgs.callPackage (args.crateExpression or (_: { })) { };

      features = args.features or [ ];
      cargoExtraArgs = lib.concatStringsSep " " (
        lib.optional (args.noDefaultFeatures or false) "--no-default-features"
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
        buildInputs = (extra.buildInputs or [ ]) ++ (splicedArgs.buildInputs or [ ]);
        nativeBuildInputs = (extra.nativeBuildInputs or [ ]) ++ (splicedArgs.nativeBuildInputs or [ ]);
      }
      // lib.optionalAttrs (cargoExtraArgs != "") { inherit cargoExtraArgs; };

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
