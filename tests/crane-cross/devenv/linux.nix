{
  config,
  pkgs,
  testLib,
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

    tests = {
      native = testLib.expectOutput {
        name = "crane-cross-native";
        command = "${native}/bin/crane-cross";
        expected = "hello from x86_64-unknown-linux-gnu with zlib ${pkgs.zlib.version}, 2 + 3 = 5";
      };

      # runs under qemu's user mode emulation
      aarch64 = testLib.expectOutput {
        name = "crane-cross-aarch64";
        command = "${aarch64Pkgs.stdenv.hostPlatform.emulator pkgs} ${aarch64}/bin/crane-cross";
        expected = "hello from aarch64-unknown-linux-gnu with zlib ${aarch64Pkgs.zlib.version}, 2 + 3 = 5";
      };

      # x86_64 machines run musl binaries natively
      musl = testLib.expectOutput {
        name = "crane-cross-musl";
        command = "${musl}/bin/crane-cross";
        expected = "hello from ${muslSystem}, 2 + 3 = 5";
      };

      # rust links musl binaries statically, which is what makes them
      # portable
      musl-static = testLib.expectOutput {
        name = "crane-cross-musl-static";
        command = "file --brief ${musl}/bin/crane-cross | grep --only-matching static | head -n 1";
        expected = "static";
        nativeBuildInputs = [ pkgs.file ];
      };
    };
  };
}
