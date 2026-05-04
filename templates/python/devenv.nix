{ config, pkgs, ... }:
{
  cachix = {
    pull = [ "municorn" ];
    push = "municorn";
  };

  languages.python = {
    enable = true;
    lsp.package = pkgs.ty;
    uv = {
      enable = true;
      sync.enable = true;
    };

    libraries = [ ];
  };

  packages = [ pkgs.ruff ] ++ config.languages.python.libraries;

  outputs.default = config.languages.python.import ./. { };
}
