{ lib, pkgs, ... }:
{
  # import musicaloft-shell straight from this checkout. consumers get the
  # same module through the `musicaloft-shell` input in their devenv.yaml,
  # but an input would pin a copy of the repository instead of testing the
  # working tree.
  imports = [ ../../devenv.nix ];

  # the test projects live inside musicaloft-shell's own git repository, so
  # `devenv test` would otherwise install their hooks over the repository's
  # own, and run every hook and formatter against all of its files
  git-hooks.enable = lib.mkForce false;
  treefmt.enable = lib.mkForce false;

  _module.args.testLib = import ./lib.nix { inherit pkgs; };
}
