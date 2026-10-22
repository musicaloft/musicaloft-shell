{ config, lib, ... }:
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
  };

  # what .test.sh inspects. these are only set while testing, so entering
  # the shell normally doesn't build them
  env = lib.mkIf config.devenv.isTesting {
    TEST_PNAME = package.pname;
    TEST_VERSION = package.version;
    TEST_SOURCE = "${package.src}";
  };
}
