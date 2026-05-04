{ pkgs, ... }:
{
  cachix = {
    pull = [ "municorn" ];
    push = "municorn";
  };

  # your configuration here
  packages = [ pkgs.hello ];
}
