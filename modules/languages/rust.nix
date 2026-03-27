{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf config.languages.rust.enable {
  files = {
    ".cargo/config.toml".toml.alias.cover = "llvm-cov nextest";
    ".cargo/mutants.toml".toml.test_tool = "nextest";
  };

  languages.rust.components = lib.mkOptionDefault [ "llvm-tools-preview" ];

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
    cargo-llvm-cov
    cargo-machete
    cargo-mutants
    cargo-nextest
  ];

  treefmt.config.programs = {
    rustfmt.enable = true;
    taplo.enable = true;
  };
}
