{
  config,
  testLib,
  ...
}:
let
  inherit (config.languages.rust) crane dioxus;

  # dioxus.import builds a single crate, so it's pointed at the app crate,
  # with the whole workspace as its source so the sibling crates and the
  # shared Cargo.lock are there too. a custom source also replaces the
  # default one's assets and tailwind files, so they're listed here.
  package = dioxus.import ./packages/web {
    src = crane.mkSource ./. {
      extraPaths = [
        "packages/ui/assets"
        "packages/web/assets"
        "packages/web/tailwind.css"
      ];
    };
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
