{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.languages.rust) crane;

  # zlib is never linked, only loaded with dlopen, so cargo and the linker
  # never see it. autoPatchelfHook adds the runtimeDependencies to the
  # binary's rpath after the build, which is what lets dlopen find them.
  # the arguments also reach the dependency build and the checks, where
  # there's nothing for the hook to patch.
  loaded = crane.import ./. {
    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    # the hook insists on finding every library the binary needs, and rust
    # binaries want libgcc_s from the compiler's runtime
    buildInputs = [ pkgs.stdenv.cc.cc.lib ];
    runtimeDependencies = [ pkgs.zlib ];
  };
in
{
  imports = [ ../common ];

  languages.rust = {
    enable = true;
    channel = "stable";
  };

  outputs = {
    default = loaded;
    checks = loaded.passthru.checks;
  };

  # what .test.sh inspects. these are only set while testing, so entering
  # the shell normally doesn't build them
  env = lib.mkIf config.devenv.isTesting {
    TEST_PACKAGE = "${loaded}";
    TEST_ZLIB_VERSION = pkgs.zlib.version;
  };
}
