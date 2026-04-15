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
    ".cargo/nextest.toml".toml.profile.ci = {
      fail-fast = false;
      retries = 4;
    };
    ".rustfmt.toml".toml = {
      condense_wildcard_suffixes = true;
      float_literal_trailing_zero = "IfNoPostfix";
      format_code_in_doc_comments = true;
      format_macro_bodies = true;
      format_macro_matchers = true;
      format_strings = true;
      group_imports = "StdExternalCrate";
      hex_literal_case = "Lower";
      imports_granularity = "Crate";
      normalize_comments = true;
      normalize_doc_attributes = true;
      overflow_delimited_expr = true;
      reorder_impl_items = true;
      unstable_features = true;
      use_field_init_shorthand = true;
      use_try_shorthand = true;
      wrap_comments = true;
    };
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
