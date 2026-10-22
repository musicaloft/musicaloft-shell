{ pkgs, ... }:
{
  # the template's overlay pins dx and wasm-bindgen-cli to the versions in
  # its Cargo.lock, and the dioxus test projects pin the same versions, so
  # they're tested against exactly what the template ships with
  imports = [
    ../../templates/dioxus/devenv/overlay.nix
    ./server.nix
  ];

  languages.rust = {
    enable = true;
    channel = "nightly";
    targets = [ "wasm32-unknown-unknown" ];

    dioxus = {
      enable = true;
      # must match the wasm-bindgen version pinned in Cargo.lock exactly
      wasmBindgenPackage = pkgs.wasm-bindgen-cli_0_2_128;
    };
  };
}
