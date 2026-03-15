{
  config,
  lib,
  pkgs,
  ...
}:
{
  git-hooks.hooks = {
    # clippy for rust projects
    clippy = lib.mkIf config.languages.rust.enable {
      enable = true;
      settings = {
        allFeatures = true;
        denyWarnings = true;
      };
    };

    # for typescript projects
    oxlint = lib.mkIf config.languages.typescript.enable {
      name = "oxlint";
      description = "Uses oxlint to catch any linting errors or warnings before committing";
      entry = "oxlint --type-aware --type-check --deny-warnings";
      types_or = [
        "javascript"
        "ts"
        "json"
      ];
    };

    # for python projects
    ruff.enable = config.languages.python.enable;
    ruff-format.enable = config.languages.python.enable;
    ty = lib.mkIf config.languages.python.enable {
      enable = true;
      entry = "ty check";
      name = "python type checking with `ty`";
      pass_filenames = true;
      types = [ "python" ];
    };

    # hooks that can apply to all projects
    treefmt.enable = true;
    commitlint-rs = {
      enable = true;
      name = "commitlint-rs";
      package = pkgs.commitlint-rs;
      description = "Validate commit messages with commitlint-rs";
      entry = "${pkgs.lib.getExe pkgs.commitlint-rs} -e";
      pass_filenames = true;
      stages = [ "commit-msg" ];
    };
  };
}
