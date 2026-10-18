{
  imports = [
    ../common
    ./devenv/linux.nix
  ];

  languages.rust = {
    enable = true;
    channel = "stable";
  };
}
