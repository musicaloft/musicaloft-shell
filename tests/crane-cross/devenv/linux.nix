{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.languages.rust) crane;

  # crateExpression's arguments are looked up in the target's pkgs, so a
  # cross build should run the build machine's pkg-config and link the
  # target's zlib. the build script fails outright if pkg-config can't run
  # or find zlib, and the zlib version printed at runtime shows which zlib
  # was linked, since libz-sys bundles its own copy as a fallback.
  zlibArgs = {
    features = [ "zlib" ];
    crateExpression =
      { pkg-config, zlib }:
      {
        nativeBuildInputs = [ pkg-config ];
        buildInputs = [ zlib ];
      };
  };

  aarch64System = "aarch64-linux";
  aarch64Pkgs = crane.mkPkgs { crossSystem = aarch64System; };
  muslSystem = "x86_64-unknown-linux-musl";

  native = crane.import ../. zlibArgs;
  aarch64 = crane.import ../. (zlibArgs // { crossSystem = aarch64System; });
  musl = crane.import ../. { crossSystem = muslSystem; };
in
{
  languages.rust.targets = [
    aarch64Pkgs.stdenv.hostPlatform.rust.rustcTarget
    muslSystem
  ];

  outputs.default = native;

  outputs.linux = {
    inherit native aarch64 musl;
    checks = native.passthru.checks;
  };

  # what .test.sh inspects. these are only set while testing, so entering
  # the shell normally doesn't build them
  packages = lib.mkIf config.devenv.isTesting [ pkgs.file ];
  env = lib.mkIf config.devenv.isTesting {
    TEST_NATIVE = "${native}";
    TEST_AARCH64 = "${aarch64}";
    TEST_MUSL = "${musl}";
    TEST_MUSL_SYSTEM = muslSystem;

    TEST_ZLIB_VERSION = pkgs.zlib.version;
    TEST_AARCH64_ZLIB_VERSION = aarch64Pkgs.zlib.version;

    # runs the aarch64 binary under qemu's user mode emulation
    TEST_AARCH64_EMULATOR = aarch64Pkgs.stdenv.hostPlatform.emulator pkgs;
  };
}
