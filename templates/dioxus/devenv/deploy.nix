{
  config,
  lib,
  pkgs,
  ...
}:
let
  musicaloft-web = config.outputs.default;

  mkDeployConfig =
    {
      name,
      app,
      tag,
    }:
    let
      image = "musicaloft-web:${tag}";

      docker = pkgs.docker.override { clientOnly = true; };

      binPath = pkgs.lib.makeBinPath [
        docker
        pkgs.flyctl
        pkgs.jq
      ];

      containerOptions = {
        inherit tag;
        name = "musicaloft-web";
        created = "now";
        contents = [ musicaloft-web ];
        config = {
          Env = [
            "IP=0.0.0.0"
            "PORT=8080"
          ];
          ExposedPorts = {
            "8080" = { };
          };
          Entrypoint = [ "${musicaloft-web}/bin/musicaloft-web" ];
        };
      };
    in
    {
      # fly.io configuration expressed in nix, generated into toml at shell activation time
      files."fly.${name}.toml".toml = {
        inherit app;
        primary_region = "sea";

        build.image = image;

        http_service = {
          auto_start_machines = true;
          auto_stop_machines = "stop";
          force_https = true;
          internal_port = 8080;
          processes = [ "app" ];

          # stateless app can scale to zero — no in-process db to worry about
          min_machines_running = 0;
        };

        vm = [
          {
            cpu_kind = "shared";
            cpus = 1;
            memory = "1gb";
          }
        ];
      };

      scripts."deploy-${name}".exec = ''
        set -euxo pipefail
        export PATH="${binPath}:$PATH"

        # build the container stream on demand so the full app derivation is
        # not forced at shell activation time
        stream_path=$(devenv build "outputs.${name}ContainerStream" \
          | jq -r '.["outputs.${name}ContainerStream"]')
        "$stream_path" | docker load

        flyctl deploy -c fly.${name}.toml -i ${image} --local-only
      '';

      outputs = {
        "${name}Container" = pkgs.dockerTools.buildLayeredImage containerOptions;
        "${name}ContainerStream" = pkgs.dockerTools.streamLayeredImage containerOptions;
      };
    };
in
lib.mkMerge [
  (mkDeployConfig {
    name = "production";
    app = "musicaloft";
    tag = "latest";
  })
  (mkDeployConfig {
    name = "staging";
    app = "musicaloft-staging";
    tag = "staging";
  })
]
