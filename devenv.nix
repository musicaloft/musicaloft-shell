{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [ ./modules ];

  # always enable nix for downstream shells
  languages.nix.enable = true;

  # hooks that apply to all projects
  git-hooks.hooks = {
    cocoa-generate.enable = true;
    cocoa-lint.enable = true;
    treefmt.enable = true;
  };

  # treefmt for all projects
  treefmt = {
    enable = true;
    config.programs = {
      kdlfmt.enable = true;
      nixfmt.enable = true;

      # for formatting Markdown files
      oxfmt.enable = true;
    };
  };
}
