{
  config,
  testLib,
  ...
}:
let
  inherit (config.languages.rust) crane dioxus;

  # pointed at the app crate, but built from the workspace root. the app's
  # own assets and tailwind files are kept automatically, but the ui
  # crate's assets have to be listed, since `asset!` reads them at compile
  # time.
  package = dioxus.import ./packages/web {
    extraPaths = [ "packages/ui/assets" ];
  };

  # dx doesn't run clippy, tests, or docs, so they come from crane, as
  # docs/dioxus-builds.md suggests for workspaces
  workspace = crane.importWorkspace ./. {
    extraPaths = [
      "packages/ui/assets"
      "packages/web/assets"
    ];
  };
in
{
  imports = [
    ../common
    ../common/dioxus.nix
  ];

  outputs = {
    default = package;
    inherit (workspace) checks;

    tests = {
      # cargo resolves `version.workspace = true` from the workspace root
      name = testLib.expectEqual {
        name = "dioxus-workspace-name";
        actual = {
          inherit (package) pname version;
        };
        expected = {
          pname = "web";
          version = "0.1.0";
        };
      };

      # the default source must hold the whole workspace, not just the app
      source = testLib.expectSource {
        name = "dioxus-workspace";
        inherit (package) src;
        includes = [
          "Cargo.lock"
          "Cargo.toml"
          "packages/api/src/lib.rs"
          "packages/ui/assets/banner.css"
          "packages/ui/src/lib.rs"
          "packages/web/Dioxus.toml"
          "packages/web/assets/tailwind.css"
          "packages/web/src/main.rs"
          "packages/web/tailwind.css"
        ];
        excludes = [
          ".devenv"
          "devenv.lock"
          "devenv.nix"
          "devenv.yaml"
          "target"
        ];
      };

      server = testLib.expectServer {
        name = "dioxus-workspace";
        inherit package;
        pages = [
          {
            path = "/";
            contains = "hello from the web crate";
          }
          {
            path = "/";
            contains = "hello from the ui crate";
          }
          # rendered on the server through use_server_future
          {
            path = "/";
            contains = "the api crate says hello";
          }
          {
            path = "/api/greeting";
            contains = "the api crate says hello";
          }
        ];
      };

      # the stylesheet must include classes from both the app crate and the
      # ui crate, which tailwind.css pulls in with @source
      tailwind = testLib.expectOutput {
        name = "dioxus-workspace-tailwind";
        command = "cat ${package}/bin/public/assets/tailwind-*.css | grep --only-matching --fixed-strings --regexp .italic --regexp .text-3xl | sort --unique | tr '\\n' ' '";
        expected = ".italic .text-3xl ";
      };
    };
  };
}
