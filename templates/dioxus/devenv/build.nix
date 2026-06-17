{
  config,
  pkgs,
  ...
}:
let
  cargo-toml = fromTOML (builtins.readFile ../Cargo.toml);
  pname = cargo-toml.workspace.package.name;
  version = cargo-toml.package.version;

  # the nightly toolchain with both linux and wasm32 targets, as configured by
  # the devenv rust language module (devenv.nix / languages.rust)
  toolchain = config.languages.rust.toolchainPackage;

  # native build inputs for the server (linux) compilation
  serverNativeBuildInputs = with pkgs; [
    autoPatchelfHook
    clang
    gcc
    libclang
    pkg-config
  ];

  # runtime/library deps linked into the server binary
  serverBuildInputs = with pkgs; [
    aws-lc.dev
    libressl.dev
    postgresql.lib
  ];

  # source filter for the dx bundle build: includes all rust source, assets,
  # config files, and the tailwind input stylesheet that manganis validates at
  # compile time via the asset! macro.
  # the workspace has three crates; all are included.
  bundleSrc = pkgs.lib.cleanSourceWith {
    src = ../.;
    filter =
      path: type:
      # include directories so cleanSourceWith can traverse into them
      (type == "directory")
      || (pkgs.lib.hasInfix "/assets/" path)
      || (pkgs.lib.hasInfix "/src/" path)
      || (pkgs.lib.hasInfix "/migrations/" path)
      || (pkgs.lib.hasSuffix "Cargo.toml" path)
      || (pkgs.lib.hasSuffix "Cargo.lock" path)
      || (pkgs.lib.hasSuffix "Dioxus.toml" path)
      || (pkgs.lib.hasSuffix "diesel.toml" path)
      # tailwind input file: manganis validates /assets/tailwind.css at
      # compile time, which we generate from this source before dx bundle runs
      || (pkgs.lib.hasSuffix "tailwind.css" path)
      || (pkgs.lib.hasSuffix "tailwind.scss" path);
  };

  # ---------------------------------------------------------------------------
  # Single-derivation fullstack bundle
  #
  # Runs `dx bundle --release --fullstack` to produce a combined server and
  # web-asset bundle in one step, replacing the previous three-derivation
  # pipeline (serverBin + clientWasm + assembly).
  #
  # dx 0.7.x outputs to: target/dx/<pname>/release/web/
  #   server              ← the axum server binary
  #   public/index.html
  #   public/assets/      ← wasm, js glue, css, and static assets (all hashed)
  #
  # The final $out layout mirrors the old assembly derivation so dioxus-server
  # can discover public/ without any env-var override:
  #   $out/bin/musicaloft-web     ← wrapped server binary
  #   $out/bin/public/            ← pre-built web assets
  #
  # Sandbox notes:
  #   - CARGO_NET_OFFLINE=true and --locked/--offline prevent any network use.
  #   - NO_DOWNLOADS=1 tells dx to use the PATH wasm-opt instead of downloading.
  #   - binaryen's thread pool SIGABRTs under the nix seccomp sandbox, so we
  #     intercept dx's wasm-opt call with a passthrough stub and run our own
  #     wasm-opt afterwards with the threading flags omitted.
  #   - tailwind.css must exist before dx bundle because manganis validates the
  #     asset! macro path at compile time.
  # ---------------------------------------------------------------------------
  musicaloft-web = pkgs.stdenvNoCC.mkDerivation {
    inherit pname version;
    src = bundleSrc;

    cargoDeps = pkgs.rustPlatform.importCargoLock { lockFile = ../Cargo.lock; };

    nativeBuildInputs = [
      toolchain
      pkgs.dioxus-cli
      pkgs.wasm-bindgen-cli_0_2_121
      pkgs.binaryen
      pkgs.tailwindcss_4
      pkgs.makeWrapper
      pkgs.gcc
      pkgs.pkg-config
      pkgs.cmake
      pkgs.perl
      pkgs.rustPlatform.cargoSetupHook
    ]
    ++ serverNativeBuildInputs;

    buildInputs = serverBuildInputs;

    dontConfigure = true;

    buildPhase = ''
      runHook preBuild

      # nix sandbox sets HOME to /homeless-shelter; move it somewhere writable
      export HOME=$TMPDIR
      export CARGO_HOME=$TMPDIR/cargo-home

      export DIOXUS_APP_TITLE="Musicaloft"
      export DIOXUS_PRODUCT_NAME="MusicaloftWeb"
      export DIOXUS_TELEMETRY_ENABLED=false
      export CARGO_NET_OFFLINE=true
      # tell dx to use the PATH wasm-opt instead of downloading its own copy
      export NO_DOWNLOADS=1

      # manganis validates asset paths at compile time; pre-generate the
      # tailwind output so the asset!("/assets/tailwind.css") macro resolves
      mkdir -p web/assets
      tailwindcss -i ./web/tailwind.css -o web/assets/tailwind.css --minify

      # dx's wasm-opt invocation triggers SIGABRT under the nix sandbox because
      # binaryen's thread pool spawning is blocked by the seccomp profile.
      # intercept it with a passthrough stub so dx succeeds, then run our own
      # wasm-opt below with threading flags omitted.
      FAKE_OPT="$TMPDIR/fake-wasm-opt/bin"
      mkdir -p "$FAKE_OPT"

      cat > "$FAKE_OPT/wasm-opt" << 'EOF'
      #!/bin/sh
      # passthrough stub: copies input to -o output so dx reports success.
      # real wasm optimization runs after dx bundle with threading flags removed.
      INPUT=""
      OUTPUT=""
      NEXT_IS_OUTPUT=0
      for arg in "$@"; do
        if [ "$NEXT_IS_OUTPUT" = "1" ]; then
          OUTPUT="$arg"
          NEXT_IS_OUTPUT=0
        elif [ "$arg" = "-o" ]; then
          NEXT_IS_OUTPUT=1
        elif [ -f "$arg" ]; then
          INPUT="$arg"
        fi
      done
      if [ -n "$INPUT" ] && [ -n "$OUTPUT" ] && [ "$INPUT" != "$OUTPUT" ]; then
        cp "$INPUT" "$OUTPUT"
      fi
      exit 0
      EOF

      chmod +x "$FAKE_OPT/wasm-opt"
      export PATH="$FAKE_OPT:$PATH"

      dx bundle --package musicaloft-web --release --fullstack --locked --offline

      # run the real wasm-opt on the bundled wasm without --enable-threads
      WASM=$(find "target/dx/${pname}/release/web/public/assets" \
               -name "*_bg-dxh*.wasm" | head -1)
      if [ -n "$WASM" ]; then
        WASM_TMP=$(mktemp "$TMPDIR/wasm-opt-XXXXXX.wasm")
        wasm-opt \
          "$WASM" \
          -Oz \
          -o "$WASM_TMP" \
          --enable-reference-types \
          --enable-bulk-memory \
          --enable-mutable-globals \
          --enable-nontrapping-float-to-int \
          --strip-debug
        mv "$WASM_TMP" "$WASM"
      fi

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin

      DX_OUT="target/dx/${pname}/release/web"

      # place the server binary next to public/ so dioxus-server can discover
      # the assets without any env-var override
      cp "$DX_OUT/server" $out/bin/${pname}
      cp -r "$DX_OUT/public" $out/bin/public

      wrapProgram $out/bin/${pname} \
        --set-default IP   0.0.0.0 \
        --set-default PORT 8080

      runHook postInstall
    '';

    meta = {
      description = "The Musicaloft website pre-built fullstack bundle";
      mainProgram = pname;
    };
  };
in
{
  outputs.default = musicaloft-web;
}
