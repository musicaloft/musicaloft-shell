{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [ ./devenv ];

  env = {
    PORT = 8080;
    # RUST_LOG = "info,dioxus_app=debug";
  };

  languages = {
    opentofu.enable = true;
    rust = {
      enable = true;
      channel = "nightly";

      components = [
        "cargo"
        "clippy"
        "rust-analyzer"
        "rust-src"
        "rust-std"
        "rustc"
        "rustfmt"
      ];

      targets = [
        "x86_64-unknown-linux-gnu"
        "wasm32-unknown-unknown"
      ];

      dioxus = {
        enable = true;
        # must match the wasm-bindgen version pinned in Cargo.lock exactly
        wasmBindgenPackage = pkgs.wasm-bindgen-cli_0_2_128;
      };
    };
  };

  # extra tools for the dev shell. dx, wasm-bindgen, tailwindcss, and
  # wasm-opt come from languages.rust.dioxus, and the usual cargo tools
  # from musicaloft-shell's rust module.
  packages = with pkgs; [
    cargo-watch
    flyctl
  ];

  processes = {
    dx-serve = {
      exec = "secretspec run -- ${lib.getExe config.languages.rust.dioxus.cliPackage} serve";
      cwd = config.git.root;
      ready.http.get.port = 8080;
    };
  };

  # add `dx fmt` to the treefmt config provided by musicaloft-shell. all
  # other formatters (nixfmt, oxfmt, kdlfmt, typos) come from there.
  treefmt.config.settings.formatter.dx-fmt =
    let
      dx = lib.getExe config.languages.rust.dioxus.cliPackage;
    in
    {
      command = lib.getExe pkgs.bash;
      options = [
        "-euc"
        ''
          for file in "$@"; do
            cat "$file" | ${dx} fmt -c -f - || ${dx} fmt -f "$file"
          done
        ''
        "--" # bash swallows the second argument when using -c
      ];
      includes = [ "*.rs" ];
    };
}
