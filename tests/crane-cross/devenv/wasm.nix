{
  config,
  pkgs,
  testLib,
  ...
}:
let
  inherit (config.languages.rust) crane;

  # wasm targets have no nixpkgs stdenv worth cross-compiling with, so
  # cargo is pointed at the target directly (as crane's own wasm examples
  # do), linking with the toolchain's bundled rust-lld
  wasm32 = crane.import ../. { CARGO_BUILD_TARGET = "wasm32-unknown-unknown"; };
  wasi = crane.import ../. { CARGO_BUILD_TARGET = "wasm32-wasip1"; };

  # the sandbox has no writable home for wasmtime's compilation cache
  wasmtimeRun = "${pkgs.wasmtime}/bin/wasmtime run -C cache=n";
in
{
  languages.rust.targets = [
    "wasm32-unknown-unknown"
    "wasm32-wasip1"
  ];

  outputs.wasm = {
    inherit wasm32 wasi;

    tests = {
      # the bare module has no entry point, so call its exported function
      wasm32 = testLib.expectOutput {
        name = "crane-cross-wasm32";
        command = "${wasmtimeRun} --invoke add ${wasm32}/lib/crane_cross.wasm 2 3";
        expected = "5";
      };

      wasi = testLib.expectOutput {
        name = "crane-cross-wasi";
        command = "${wasmtimeRun} ${wasi}/bin/crane-cross.wasm";
        expected = "hello from wasm32-wasip1, 2 + 3 = 5";
      };
    };
  };
}
