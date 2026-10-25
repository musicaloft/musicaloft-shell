{ config, lib, ... }:
let
  inherit (config.languages.rust) crane;

  # greeting.txt is read with include_str!, so it has to survive the source
  # filter
  args = {
    extraFileTypes = [ "txt" ];
  };

  package = crane.import ./. args;
  shouting = crane.import ./. (args // { features = [ "shout" ]; });
  overridden = crane.import ./. (args // { meta.mainProgram = "custom-name"; });
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

    # the features change what the tests compile, so they're checked again
    shouting-nextest = shouting.passthru.checks.nextest;
  };

  # what .test.sh inspects. these are only set while testing, so entering
  # the shell normally doesn't build them
  env = lib.mkIf config.devenv.isTesting {
    TEST_PACKAGE = "${package}";
    TEST_SHOUTING = "${shouting}";
    TEST_SOURCE = "${package.passthru.commonArgs.src}";

    # the inferred main program, one set by the caller, and the dependency
    # build's, which must not claim one
    TEST_MAIN_PROGRAM = package.meta.mainProgram;
    TEST_MAIN_PROGRAM_OVERRIDE = overridden.meta.mainProgram;
    TEST_DEPS_MAIN_PROGRAM = package.passthru.cargoArtifacts.meta.mainProgram or "none";
  };
}
