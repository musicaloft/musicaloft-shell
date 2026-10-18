{
  config,
  testLib,
  ...
}:
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

    tests = {
      server = testLib.expectServer {
        name = "dioxus-simple";
        inherit package;
        pages = [
          {
            path = "/";
            contains = "hello from dioxus simple";
          }
          # rendered on the server through use_server_future
          {
            path = "/";
            contains = "the server says hello";
          }
          {
            path = "/api/greeting";
            contains = "the server says hello";
          }
        ];
      };

      # dx regenerates the stylesheet with tailwind, which only emits the
      # utility classes it finds in the sources
      tailwind = testLib.expectOutput {
        name = "dioxus-simple-tailwind";
        command = "grep --recursive --files-with-matches --include='*.css' --fixed-strings .text-3xl ${package}/bin/public | wc -l";
        expected = "1";
      };
    };
  };
}
