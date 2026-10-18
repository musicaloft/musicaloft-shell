{ config, testLib, ... }:
let
  inherit (config.languages.rust) crane;

  # greeting.txt is read with include_str!, so it has to survive the source
  # filter
  args = {
    extraFileTypes = [ "txt" ];
  };

  package = crane.import ./. args;
  shouting = crane.import ./. (args // { features = [ "shout" ]; });
in
{
  imports = [ ../common ];

  languages.rust = {
    enable = true;
    channel = "stable";
  };

  outputs = {
    default = package;
    inherit shouting;
    checks = package.passthru.checks;

    tests = {
      default = testLib.expectOutput {
        name = "crane-simple";
        command = "${package}/bin/crane-simple";
        expected = "hello from Crane Simple!";
      };

      shouting = testLib.expectOutput {
        name = "crane-simple-shouting";
        command = "${shouting}/bin/crane-simple";
        expected = "HELLO FROM CRANE SIMPLE!";
      };

      shouting-checks = shouting.passthru.checks.nextest;

      source = testLib.expectSource {
        name = "crane-simple";
        src = package.passthru.commonArgs.src;
        includes = [
          "Cargo.lock"
          "Cargo.toml"
          "src/greeting.txt"
          "src/lib.rs"
          "src/main.rs"
        ];
        excludes = [
          ".cargo/config.toml"
          ".devenv"
          ".rustfmt.toml"
          "devenv.lock"
          "devenv.nix"
          "devenv.yaml"
          "target"
        ];
      };
    };
  };
}
