{
  config,
  lib,
  pkgs,
  ...
}:
let
  pname = "a-rust-app";
  buildInputs = [ ];
  nativeBuildInputs = with pkgs; [
    autoPatchelfHook
    pkg-config
  ];
  libraryPath = lib.makeLibraryPath buildInputs;
in
{
  languages.rust = {
    enable = true;
    channel = "nightly";
    mold.enable = true;

    # needed for dynamic linking at runtime
    rustflags = lib.mkForce "-C link-args=-Wl,-fuse-ld=mold,-rpath,${libraryPath}";
  };

  packages = buildInputs ++ nativeBuildInputs;

  outputs.default =
    let
      args = {
        crateOverrides = pkgs.defaultCrateOverrides // {
          ${pname} = attrs: {
            inherit buildInputs nativeBuildInputs;
            runtimeDependencies = buildInputs;
          };
        };
      };
    in
    config.languages.rust.import ./. args;
}
