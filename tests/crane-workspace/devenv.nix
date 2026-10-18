{
  config,
  lib,
  pkgs,
  testLib,
  ...
}:
let
  inherit (config.languages.rust) crane;

  workspace = crane.importWorkspace ./. { };
  inherit (workspace) packages;

  # cross-compiled at the cargo level, like crane-cross's wasm builds
  wasi = crane.importWorkspace ./. { CARGO_BUILD_TARGET = "wasm32-wasip1"; };

  # the sandbox has no writable home for wasmtime's compilation cache
  wasmtimeRun = "${pkgs.wasmtime}/bin/wasmtime run -C cache=n";
in
{
  imports = [ ../common ];

  languages.rust = {
    enable = true;
    channel = "nightly";
    targets = [ "wasm32-wasip1" ];
  };

  outputs = packages // {
    inherit (workspace) checks deps;
    wasi = wasi.packages;

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

      wasi-cli = testLib.expectOutput {
        name = "workspace-cli-wasi";
        command = "${wasmtimeRun} ${wasi.packages.workspace-cli}/bin/workspace-cli.wasm";
        expected = "[Workspace Cli] ready";
      };

      wasi-stats = testLib.expectOutput {
        name = "workspace-stats-wasi";
        command = "${wasmtimeRun} ${wasi.packages.workspace-stats}/bin/workspace-stats.wasm";
        expected = "5 words";
      };
    };
  };
}
