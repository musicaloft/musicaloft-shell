{ pkgs, ... }:
{
  cachix.push = "municorn";

  # your configuration here
  packages = [ pkgs.hello ];
}
