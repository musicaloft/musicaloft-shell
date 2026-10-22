{ config, ... }:
let
  inherit (config.languages.rust) crane dioxus;

  package = dioxus.import ./. { };

  # dx doesn't run clippy, tests, or docs, so they come from crane
  inherit (crane.import ./. { extraPaths = [ "assets" ]; }) passthru;
in
{
  imports = [
    ../common
    ../common/dioxus.nix
  ];

  outputs = {
    default = package;
    inherit (passthru) checks;
  };
}
