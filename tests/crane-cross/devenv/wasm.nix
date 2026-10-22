{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.languages.rust) crane;

  # wasm targets have no nixpkgs stdenv worth cross-compiling with, so
  # cargo is pointed at the target directly (as crane's own wasm examples
  # do), linking with the toolchain's bundled rust-lld
  wasm32 = crane.import ../. { CARGO_BUILD_TARGET = "wasm32-unknown-unknown"; };
  wasi = crane.import ../. { CARGO_BUILD_TARGET = "wasm32-wasip1"; };
in
{
  languages.rust.targets = [
    "wasm32-unknown-unknown"
    "wasm32-wasip1"
  ];

  outputs.wasm = {
    inherit wasm32 wasi;
  };

  # what .test.sh inspects. these are only set while testing, so entering
  # the shell normally doesn't build them
  packages = lib.mkIf config.devenv.isTesting [ pkgs.wasmtime ];
  env = lib.mkIf config.devenv.isTesting {
    TEST_WASM32 = "${wasm32}";
    TEST_WASI = "${wasi}";
  };
}
