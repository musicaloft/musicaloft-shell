{ ... }:
{
  imports = [
    ./hooks.nix
    ./treefmt.nix
  ];

  languages.nix.enable = true;
}
