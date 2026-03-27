{ inputs, lib, ... }:
{
  imports = [ ./modules ] ++ lib.optional (inputs ? cocoa) "${inputs.cocoa}/devenv/devenv.nix";

  # use muni's binary cache
  cachix.pull = [ "municorn" ];

  # always enable nix for downstream shells
  languages.nix.enable = true;

  # hooks that apply to all projects
  git-hooks.hooks = {
    cocoa-generate.enable = inputs ? cocoa;
    cocoa-lint.enable = inputs ? cocoa;
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
