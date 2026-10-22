# Runs a fullstack Dioxus app's server while `devenv test` runs, so test
# scripts can fetch pages from it.
#
# The project must set `outputs.default` to the app's package, as built by
# `languages.rust.dioxus.import`. Test scripts get these variables:
#
# - `TEST_PACKAGE`: the app's package.
# - `TEST_SERVER_URL`: the url the server is listening on.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  package = config.outputs.default;

  # devenv looks for a free port, starting here, so the server doesn't
  # collide with whatever else is running
  port = config.processes.server.ports.http.value;
in
{
  config = lib.mkIf config.devenv.isTesting {
    packages = [ pkgs.curl ];

    processes.server = {
      exec = lib.getExe package;
      ports.http.allocate = 8123;

      # the server reads its address from these, listening on the loopback
      # interface only
      env = {
        IP = "127.0.0.1";
        PORT = toString port;
      };

      ready.http.get = {
        inherit port;
        path = "/";
      };
    };

    env = {
      TEST_PACKAGE = "${package}";
      TEST_SERVER_URL = "http://127.0.0.1:${toString port}";
    };
  };
}
