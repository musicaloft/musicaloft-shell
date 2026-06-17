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
    };
  };

  # tools available in the dev shell
  packages = with pkgs; [
    cargo-machete
    cargo-outdated
    cargo-watch
    dioxus-cli
    flyctl
    wasm-bindgen-cli_0_2_121
  ];

  services = {
    # connect via $PGHOST env var
    postgres = {
      enable = true;
      listen_addresses = "localhost";
      initialDatabases = [
        {
          name = "app";
          user = "app";
          pass = "sillylittlepassword";
        }
        {
          name = "app_dev";
          user = "app";
          pass = "sillylittlepassword";
        }
      ];
    };

    # connect via 127.0.0.1:6379
    redis.enable = true;
  };

  processes = {
    tailwind = {
      exec = "${lib.getExe pkgs.tailwindcss_4} -i ./tailwind.css -o ./web/assets/tailwind.css";
      cwd = config.git.root;
      watch = {
        # watch all crate src dirs so tailwind rebuilds on any component change
        paths = [
          ./.
        ];
        extensions = [
          "css"
          "rs"
          "toml"
        ];
        ignore = [ "target" ];
      };
    };
    dx-serve = {
      exec = "secretspec run -- ${lib.getExe pkgs.dioxus-cli} serve --package app-web";
      cwd = config.git.root;
      after = [
        "devenv:processes:postgres"
        "devenv:processes:redis"
      ];
      ready.http.get.port = 8080;
    };
  };

  # add `dx fmt` to the treefmt config provided by musicaloft-shell. all
  # other formatters (nixfmt, oxfmt, kdlfmt, typos) come from there.
  treefmt.config.settings.formatter.dx-fmt =
    let
      dx = lib.getExe pkgs.dioxus-cli;
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
