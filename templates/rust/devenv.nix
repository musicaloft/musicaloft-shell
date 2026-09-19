{
  config,
  lib,
  pkgs,
  ...
}:
let
  buildInputs = [ ];
  nativeBuildInputs = with pkgs; [ pkg-config ];
  libraryPath = lib.makeLibraryPath buildInputs;
in
{
  languages.rust = {
    enable = true;
    channel = "nightly";
    wild.enable = true;

    # needed for dynamic linking at runtime
    rustflags = lib.mkForce "-C link-args=-Wl,-fuse-ld=wild,-rpath,${libraryPath}";
  };

  packages = buildInputs ++ nativeBuildInputs;

  outputs.default = config.languages.rust.crane.import ./. { inherit buildInputs nativeBuildInputs; };
}
