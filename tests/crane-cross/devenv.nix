{
  imports = [
    ../common
    ./devenv/linux.nix
    ./devenv/wasm.nix
  ];

  languages.rust = {
    enable = true;
    channel = "stable";
  };
}
