{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.languages.rust.dioxus;
  craneCfg = config.languages.rust.crane;

  # builds a fullstack Dioxus bundle with a single `dx bundle --fullstack`
  # run, which drives cargo itself for both the server and wasm client.
  #
  # there's deliberately no crane `buildDepsOnly` step: dx compiles each
  # side under its own generated cargo profile (`server-release`,
  # `web-release`), so dependencies prebuilt under any other profile would
  # never be reused and would only add a second full dependency build.
  import' =
    path: args:
    let
      crossSystem = args.crossSystem or null;
      targetPkgs = craneCfg.mkPkgs { inherit crossSystem; };
      craneLib = craneCfg.mkLib { pkgs = targetPkgs; };
      serverTarget = targetPkgs.stdenv.hostPlatform.rust.rustcTarget;

      inherit (craneLib.crateNameFromCargoToml { cargoToml = path + "/Cargo.toml"; })
        pname
        version
        ;

      tailwind = cfg.mkTailwindSteps path;

      # Dioxus.toml is already covered by crane's toml filter; assets are
      # read by the `asset!` macro at compile time
      src =
        args.src or (craneCfg.mkSource path {
          extraPaths = [ "assets" ] ++ tailwind.extraPaths ++ (args.extraPaths or [ ]);
          extraFileTypes = args.extraFileTypes or [ ];
        });
      cargoVendorDir = args.cargoVendorDir or (craneLib.vendorCargoDeps { inherit src; });

      splicedArgs = craneCfg.spliceCrateExpression targetPkgs (args.crateExpression or (_: { }));
      buildInputs = (args.buildInputs or [ ]) ++ splicedArgs.buildInputs;
      extraNativeBuildInputs = (args.nativeBuildInputs or [ ]) ++ splicedArgs.nativeBuildInputs;

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

      # the platform flags matter: an explicit @server only overrides dx's
      # bundle format, so without --server it autodetects the platform from
      # default features (usually "web") and builds the server with the web
      # renderer, which panics at startup
      dxTargetArgs = "@client --web --target ${cfg.clientTarget} @server --server --target ${serverTarget}";
    in
    craneLib.mkCargoDerivation (
      {
        inherit
          src
          cargoVendorDir
          pname
          version
          buildInputs
          ;

        # see above for why nothing is prebuilt
        cargoArtifacts = null;
        strictDeps = true;
        doInstallCargoArtifacts = false;

        nativeBuildInputs = [
          cfg.cliPackage
          cfg.wasmBindgenPackage
          pkgs.binaryen
          # a compiled wrapper built for the server's platform, unlike
          # makeWrapper's bash script, whose shebang points at the build
          # platform's bash (and which would need bash in container images)
          targetPkgs.makeBinaryWrapper
          # std's panic locations and dependencies' file!() paths otherwise
          # keep the whole toolchain and every vendored crate in the runtime
          # closure; craneLib.buildPackage adds these hooks, but
          # mkCargoDerivation doesn't
          craneLib.removeReferencesToRustToolchainHook
          craneLib.removeReferencesToVendoredSourcesHook
        ]
        ++ tailwind.nativeBuildInputs
        ++ extraNativeBuildInputs;

        buildPhaseCargoCommand = ''
          export HOME=$TMPDIR
          export DIOXUS_TELEMETRY_ENABLED=false
          export CARGO_NET_OFFLINE=true
          # tell dx to use the PATH wasm-opt instead of downloading its own copy
          export NO_DOWNLOADS=1

          ${tailwind.preBundle}

          fakeOptDir="$TMPDIR/fake-wasm-opt"
          mkdir -p "$fakeOptDir"
          ln -sf ${wasmOptStub} "$fakeOptDir/wasm-opt"
          export PATH="$fakeOptDir:$PATH"

          dx bundle --package ${pname} --release --fullstack --locked --offline ${dxTargetArgs} ${args.dxExtraArgs or ""}

          ${tailwind.postBundle}

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

        meta.mainProgram = pname;
      }
      // lib.optionalAttrs (args ? env) { inherit (args) env; }
    );
in
{
  imports = [ ./dioxus/tailwind.nix ];

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

    import = lib.mkOption {
      type = lib.types.functionTo (lib.types.functionTo lib.types.package);
      readOnly = true;
      description = ''
        Import a fullstack Dioxus project, building it with a single `dx
        bundle --fullstack` run inside a crane derivation.

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
        - `extraPaths`, `extraFileTypes`: extra files to keep in the source
          filter, as for `languages.rust.crane.import`. `assets/` and toml
          files (including `Dioxus.toml`) are always included.
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

  config = lib.mkMerge [
    {
      # defined unconditionally so forgetting `enable` gets a clear error
      # instead of an undefined option
      languages.rust.dioxus.import =
        path: args:
        lib.throwIfNot cfg.enable ''
          languages.rust.dioxus.import was called, but languages.rust.dioxus.enable isn't set.
          set `languages.rust.dioxus.enable = true;` so the dioxus cli and wasm target checks are set up.
        '' (import' path args);
    }

    (lib.mkIf cfg.enable {
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
    })
  ];
}
