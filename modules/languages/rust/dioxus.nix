{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.languages.rust.dioxus;
  craneCfg = config.languages.rust.crane;

  # builds a source derivation covering everything a Dioxus fullstack
  # build might read: the usual crane/cargo files, plus assets, migrations,
  # and the framework's own config files, none of which
  # `craneLib.fileset.commonCargoSources` tracks on its own.
  mkSource =
    path: extraPaths:
    lib.fileset.toSource {
      root = path;
      fileset = lib.fileset.unions (
        [
          (craneCfg.lib.fileset.commonCargoSources path)
          (lib.fileset.maybeMissing (path + "/assets"))
          (lib.fileset.maybeMissing (path + "/migrations"))
          (lib.fileset.maybeMissing (path + "/Dioxus.toml"))
          (lib.fileset.maybeMissing (path + "/diesel.toml"))
        ]
        ++ lib.optional cfg.tailwind.enable (lib.fileset.maybeMissing (path + "/${cfg.tailwind.input}"))
        ++ map (p: lib.fileset.maybeMissing (path + "/${p}")) extraPaths
      );
    };

  # builds a fullstack Dioxus bundle: a dual-target (server + wasm client)
  # cargoArtifacts derivation feeding a single `dx bundle --fullstack` run.
  #
  # dx drives cargo directly for both targets, so unlike a typical crane
  # package we cannot let `craneLib.buildDepsOnly` infer a single target on
  # its own; instead its build command is overridden to warm the cache for
  # both. for that cache to actually be reused by `dx bundle`, the feature
  # flags used here must match what dx itself passes for each side (see
  # `serverFeatures`/`clientFeatures`) -- if they ever drift, `dx bundle`
  # still succeeds, it just falls back to compiling the mismatched crates
  # itself.
  import' =
    path: args:
    let
      crossSystem = args.crossSystem or null;
      craneLib = craneCfg.mkLib { inherit crossSystem; };
      targetPkgs = craneCfg.mkPkgs { inherit crossSystem; };
      serverTarget = targetPkgs.stdenv.hostPlatform.rust.rustcTarget;

      inherit (craneLib.crateNameFromCargoToml { cargoToml = path + "/Cargo.toml"; })
        pname
        version
        ;

      src = args.src or (mkSource path (args.extraPaths or [ ]));
      cargoVendorDir = args.cargoVendorDir or (craneLib.vendorCargoDeps { inherit src; });

      splicedArgs = targetPkgs.callPackage (args.crateExpression or (_: { })) { };
      buildInputs = (args.buildInputs or [ ]) ++ (splicedArgs.buildInputs or [ ]);
      extraNativeBuildInputs = (args.nativeBuildInputs or [ ]) ++ (splicedArgs.nativeBuildInputs or [ ]);

      serverFeatureArgs = "--no-default-features --features ${lib.concatStringsSep "," cfg.serverFeatures}";
      clientFeatureArgs = "--no-default-features --features ${lib.concatStringsSep "," cfg.clientFeatures}";

      depsArgs = {
        inherit
          src
          cargoVendorDir
          buildInputs
          ;
        pname = "${pname}-dioxus-deps";
        inherit version;
        strictDeps = true;
        doCheck = false;
        nativeBuildInputs = extraNativeBuildInputs;

        # build (and check) dependencies for both the server and wasm
        # client targets, so a single cargoArtifacts output warms the
        # cache dx will consume for both sides of the fullstack build.
        buildPhaseCargoCommand = ''
          cargo check --profile release --target ${serverTarget} ${serverFeatureArgs}
          cargo build --profile release --target ${serverTarget} ${serverFeatureArgs}
          cargo check --profile release --target ${cfg.clientTarget} ${clientFeatureArgs}
          cargo build --profile release --target ${cfg.clientTarget} ${clientFeatureArgs}
        '';
      };

      cargoArtifacts = args.cargoArtifacts or (craneLib.buildDepsOnly depsArgs);

      # dx bundle's wasm-opt invocation SIGABRTs under the nix sandbox
      # because binaryen's thread pool spawning is blocked by the seccomp
      # profile. intercept it with a passthrough stub so dx succeeds, then
      # run a real wasm-opt pass afterwards with threading disabled.
      wasmOptStub = pkgs.writeShellScript "fake-wasm-opt" ''
        input=""
        output=""
        next_is_output=0
        for arg in "$@"; do
          if [ "$next_is_output" = 1 ]; then
            output="$arg"
            next_is_output=0
          elif [ "$arg" = "-o" ]; then
            next_is_output=1
          elif [ -f "$arg" ]; then
            input="$arg"
          fi
        done
        if [ -n "$input" ] && [ -n "$output" ] && [ "$input" != "$output" ]; then
          cp "$input" "$output"
        fi
      '';

      dxTargetArgs = "@client --target ${cfg.clientTarget} @server --target ${serverTarget}";
    in
    craneLib.mkCargoDerivation (
      {
        inherit
          src
          cargoArtifacts
          cargoVendorDir
          pname
          version
          buildInputs
          ;

        strictDeps = true;
        doInstallCargoArtifacts = false;

        nativeBuildInputs = [
          cfg.cliPackage
          cfg.wasmBindgenPackage
          pkgs.binaryen
          pkgs.makeWrapper
        ]
        ++ lib.optional cfg.tailwind.enable cfg.tailwind.package
        ++ extraNativeBuildInputs;

        buildPhaseCargoCommand = ''
          export HOME=$TMPDIR
          export DIOXUS_TELEMETRY_ENABLED=false
          export CARGO_NET_OFFLINE=true
          # tell dx to use the PATH wasm-opt instead of downloading its own copy
          export NO_DOWNLOADS=1

          ${lib.optionalString cfg.tailwind.enable ''
            mkdir -p "$(dirname ${lib.escapeShellArg cfg.tailwind.output})"
            tailwindcss -i ${lib.escapeShellArg cfg.tailwind.input} -o ${lib.escapeShellArg cfg.tailwind.output} --minify
          ''}

          fakeOptDir="$TMPDIR/fake-wasm-opt"
          mkdir -p "$fakeOptDir"
          ln -sf ${wasmOptStub} "$fakeOptDir/wasm-opt"
          export PATH="$fakeOptDir:$PATH"

          dx bundle --package ${pname} --release --fullstack --locked --offline ${dxTargetArgs} ${args.dxExtraArgs or ""}

          # run the real wasm-opt on the bundled wasm without --enable-threads
          wasm=$(find "target/dx/${pname}/release/web/public/assets" -name '*.wasm' -print -quit)
          if [ -n "$wasm" ]; then
            wasmTmp=$(mktemp "$TMPDIR/wasm-opt-XXXXXX.wasm")
            wasm-opt "$wasm" -Oz -o "$wasmTmp" \
              --enable-reference-types \
              --enable-bulk-memory \
              --enable-mutable-globals \
              --enable-nontrapping-float-to-int \
              --strip-debug
            mv "$wasmTmp" "$wasm"
          fi
        '';

        installPhaseCommand = ''
          mkdir -p $out/bin

          dxOut="target/dx/${pname}/release/web"
          cp "$dxOut/server" $out/bin/${pname}
          cp -r "$dxOut/public" $out/bin/public

          wrapProgram $out/bin/${pname} \
            --set-default IP 0.0.0.0 \
            --set-default PORT 8080
        '';
      }
      // lib.optionalAttrs (args ? env) { inherit (args) env; }
    );
in
{
  options.languages.rust.dioxus = {
    enable = lib.mkEnableOption "building fullstack Dioxus apps with crane and `dx bundle`";

    cliPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.dioxus-cli;
      defaultText = lib.literalExpression "pkgs.dioxus-cli";
      description = "The `dx` (dioxus-cli) package used to bundle fullstack apps.";
    };

    wasmBindgenPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.wasm-bindgen-cli;
      defaultText = lib.literalExpression "pkgs.wasm-bindgen-cli";
      description = ''
        The `wasm-bindgen-cli` package used by `dx bundle`. Its version must
        match the `wasm-bindgen` dependency pinned in Cargo.lock exactly, or
        the wasm build will fail. Override this with a pinned package (e.g.
        via an overlay) rather than relying on nixpkgs' default version.
      '';
    };

    clientTarget = lib.mkOption {
      type = lib.types.str;
      default = "wasm32-unknown-unknown";
      description = "The cargo target triple used to build the web client.";
    };

    serverFeatures = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "server" ];
      description = ''
        Cargo features to build the server binary with (via
        `--no-default-features --features ...`), matching whatever `dx
        bundle --fullstack` uses to select its server-side code. Must stay
        in sync with dx's own feature selection for the dependency cache to
        be reused; see the `dioxus new` project template's `[features]`
        table for the convention this follows.
      '';
    };

    clientFeatures = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "web" ];
      description = ''
        Cargo features to build the web client with (via
        `--no-default-features --features ...`), matching whatever `dx
        bundle --fullstack` uses to select its client-side code.
      '';
    };

    tailwind = {
      enable = lib.mkEnableOption "pre-generating a Tailwind CSS bundle before `dx bundle` runs";

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.tailwindcss_4;
        defaultText = lib.literalExpression "pkgs.tailwindcss_4";
        description = "The `tailwindcss` package used to pre-generate CSS.";
      };

      input = lib.mkOption {
        type = lib.types.str;
        default = "tailwind.css";
        description = "Path (relative to the project root) of the Tailwind input stylesheet.";
      };

      output = lib.mkOption {
        type = lib.types.str;
        default = "assets/tailwind.css";
        description = ''
          Path (relative to the project root) to write the generated
          stylesheet to. Dioxus's `asset!` macro validates this path exists
          at compile time, so it must match wherever the app's `asset!`
          call points.
        '';
      };
    };

    import = lib.mkOption {
      type = lib.types.functionTo (lib.types.functionTo lib.types.package);
      readOnly = true;
      description = ''
        Import a fullstack Dioxus project, building it with `dx bundle
        --fullstack` on top of crane-cached dependency artifacts.

        This function takes a path to a directory containing the project's
        Cargo.toml and Dioxus.toml, and returns a derivation with
        `$out/bin/<pname>` (the server binary, wrapped with `IP`/`PORT`
        defaults) alongside `$out/bin/public` (the prebuilt web assets).

        The `args` attribute set accepts:

        - `crossSystem`: a Nixpkgs `crossSystem` value to cross-compile the
          server binary for. The web client always targets
          `dioxus.clientTarget` regardless.
        - `crateExpression`: a `pkgs.callPackage`-style function returning
          extra `buildInputs`/`nativeBuildInputs`, spliced onto the correct
          build/host/target `pkgs` when cross-compiling.
        - `extraPaths`: additional project-relative paths to keep in the
          source filter (beyond `assets/`, `migrations/`, `Dioxus.toml`,
          and `diesel.toml`, which are always included if present).
        - `dxExtraArgs`: extra arguments appended to the `dx bundle`
          invocation.

        Example usage:
        ```nix
        let
          mywebapp = config.languages.rust.dioxus.import ./. { };
        in {
          languages.rust = {
            enable = true;
            dioxus.enable = true;
          };
          packages = [ mywebapp ];
        }
        ```
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.elem cfg.clientTarget config.languages.rust.targets;
        message = ''
          languages.rust.dioxus requires '${cfg.clientTarget}' in languages.rust.targets
          so the toolchain can build the web client.
        '';
      }
    ];

    packages = [ cfg.cliPackage ];

    languages.rust.dioxus.import = import';
  };
}
