{
  config,
  lib,
  testLib,
  ...
}:
let
  inherit (config.languages.rust) crane;

  workspace = crane.importWorkspace ./. { };
  inherit (workspace) packages;
in
{
  imports = [ ../common ];

  languages.rust = {
    enable = true;
    channel = "nightly";
  };

  outputs = packages // {
    inherit (workspace) checks deps;

    tests = {
      # crates/experimental matches the `crates/*` glob, but is excluded
      members = testLib.expectEqual {
        name = "crane-workspace-members";
        actual = lib.attrNames packages;
        expected = [
          "workspace-cli"
          "workspace-core"
          "workspace-stats"
        ];
      };

      # cargo only inherits the workspace version when a member opts in, and
      # defaults to 0.0.0 when a member sets no version at all
      versions = testLib.expectEqual {
        name = "crane-workspace-versions";
        actual = lib.mapAttrs (_: package: package.version) packages;
        expected = {
          workspace-cli = "1.2.3";
          workspace-core = "0.3.0";
          workspace-stats = "0.0.0";
        };
      };

      # every member must reuse the single workspace-wide dependency build
      shared-deps = testLib.expectEqual {
        name = "crane-workspace-shared-deps";
        actual = lib.mapAttrs (_: package: package.passthru.commonArgs.cargoArtifacts.drvPath) packages;
        expected = lib.mapAttrs (_: _: workspace.deps.drvPath) packages;
      };

      cli = testLib.expectOutput {
        name = "workspace-cli";
        command = "${packages.workspace-cli}/bin/workspace-cli";
        expected = "[Workspace Cli] ready";
      };

      stats = testLib.expectOutput {
        name = "workspace-stats";
        command = "${packages.workspace-stats}/bin/workspace-stats";
        expected = "5 words";
      };

    };
  };
}
