{
  config,
  inputs,
  lib,
  ...
}:
{
  imports = [ ./modules ] ++ lib.optional (inputs ? cocoa) "${inputs.cocoa}/devenv/devenv.nix";

  # use muni's binary cache (only outside of testing)
  cachix.push = lib.mkDefault "municorn";

  # always enable nix for downstream shells
  languages.nix.enable = true;

  # hooks that apply to all projects
  git-hooks = {
    enable = lib.mkOverride 999 (!config.devenv.isTesting);
    hooks = {
      cocoa-generate.enable = inputs ? cocoa;
      cocoa-lint.enable = inputs ? cocoa;
      treefmt.enable = true;
    };
  };

  # treefmt for all projects
  treefmt = {
    enable = lib.mkDefault (!config.devenv.isTesting);
    config.programs = {
      kdlfmt.enable = true;
      nixfmt.enable = true;

      # for formatting Markdown files
      oxfmt.enable = true;

      # for catching typos
      typos.enable = true;
    };
  };
}
