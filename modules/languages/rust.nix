{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf config.languages.rust.enable {
  git-hooks.hooks.clippy =
    let
      toolchain = config.languages.rust.toolchainPackage;
    in
    {
      enable = true;
      packageOverrides = {
        cargo = toolchain;
        clippy = toolchain;
      };
      settings = {
        allFeatures = true;
        denyWarnings = true;
      };
    };

  packages = with pkgs; [
    bacon
    cargo-outdated
    cargo-machete
    cargo-nextest
  ];

  treefmt.config.programs = {
    rustfmt.enable = true;
    taplo.enable = true;
  };
}
