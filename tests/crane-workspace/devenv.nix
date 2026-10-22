{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.languages.rust) crane;

  workspace = crane.importWorkspace ./. { };
  inherit (workspace) packages;

  # cross-compiled at the cargo level, like crane-cross's wasm builds
  wasi = crane.importWorkspace ./. { CARGO_BUILD_TARGET = "wasm32-wasip1"; };

  # joins `name=value` pairs into a string for .test.sh to compare, which
  # is simpler than parsing json in bash
  toPairs =
    f: lib.concatStringsSep " " (lib.mapAttrsToList (name: package: "${name}=${f package}") packages);
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
  };

  # what .test.sh inspects. these are only set while testing, so entering
  # the shell normally doesn't build them
  packages = lib.mkIf config.devenv.isTesting [ pkgs.wasmtime ];
  env = lib.mkIf config.devenv.isTesting {
    TEST_CLI = "${packages.workspace-cli}";
    TEST_STATS = "${packages.workspace-stats}";
    TEST_WASI_CLI = "${wasi.packages.workspace-cli}";
    TEST_WASI_STATS = "${wasi.packages.workspace-stats}";

    TEST_MEMBERS = lib.concatStringsSep " " (lib.attrNames packages);
    TEST_VERSIONS = toPairs (package: package.version);

    # every member must reuse the single workspace-wide dependency build
    TEST_MEMBER_DEPS = toPairs (package: package.passthru.commonArgs.cargoArtifacts.drvPath);
    TEST_WORKSPACE_DEPS = workspace.deps.drvPath;
  };
}
