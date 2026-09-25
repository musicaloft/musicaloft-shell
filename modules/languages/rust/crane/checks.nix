{ lib, ... }:
let
  # builds a set of crane checks that all reuse the same cargoArtifacts as
  # the package they're checking, so running `nix flake check` (or wiring
  # these into `outputs`/`git-hooks` yourself) never triggers a redundant
  # dependency rebuild.
  #
  # returned, not auto-wired: callers decide whether/how these feed into
  # `outputs`, `git-hooks`, or `enterTest`.
  mkChecks =
    {
      craneLib,
      commonArgs,
      cargoArtifacts,
      ...
    }:
    let
      baseArgs = commonArgs // {
        inherit cargoArtifacts;
      };
    in
    {
      clippy = craneLib.cargoClippy (
        baseArgs
        // {
          cargoClippyExtraArgs = "--all-targets -- --deny warnings";
        }
      );

      doc = craneLib.cargoDoc baseArgs;

      fmt = craneLib.cargoFmt { inherit (commonArgs) src; };

      # nextest fails outright when there's nothing to run, which would
      # break the check for freshly generated crates with no tests yet
      nextest = craneLib.cargoNextest (
        baseArgs
        // {
          cargoNextestExtraArgs = "--no-tests=warn";
        }
      );

      taplo = craneLib.taploFmt { inherit (commonArgs) src; };
    };
in
{
  options.languages.rust.crane.mkChecks = lib.mkOption {
    type = lib.types.functionTo lib.types.raw;
    readOnly = true;
    internal = true;
    description = ''
      Builds a set of crane checks (`clippy`, `doc`, `fmt`, `nextest`,
      `taplo`) from the result of `languages.rust.crane.mkArgs`, all reusing
      the same `cargoArtifacts`.
    '';
  };

  config.languages.rust.crane.mkChecks = mkChecks;
}
