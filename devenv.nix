{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cocoa = if inputs ? cocoa then inputs.cocoa.packages.${pkgs.stdenv.system}.default else null;
in
{
  imports = [ ./modules ];

  # always enable nix for downstream shells
  languages.nix.enable = true;

  # hooks that apply to all projects
  git-hooks.hooks = {
    treefmt.enable = true;
    cocoa-lint = {
      enable = cocoa != null;
      name = "cocoa-lint";
      package = cocoa;
      description = "Validates commit messages with cocoa";
      entry = "${lib.getExe config.git-hooks.hooks.cocoa-lint.package} lint";
      pass_filenames = true;
      stages = [ "commit-msg" ];
    };
  };

  packages = [ cocoa ];

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
