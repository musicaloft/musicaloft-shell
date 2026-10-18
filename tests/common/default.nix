{ pkgs, ... }:
{
  # import musicaloft-shell straight from this checkout. consumers get the
  # same module through the `musicaloft-shell` input in their devenv.yaml,
  # but an input would pin a copy of the repository instead of testing the
  # working tree.
  imports = [ ../../devenv.nix ];

  # the test projects live inside musicaloft-shell's own git repository, so
  # installing their hooks would replace the repository's own hooks
  git-hooks.install.enable = false;

  _module.args.testLib = import ./lib.nix { inherit pkgs; };
}
