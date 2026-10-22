{ lib, ... }:
{
  # import musicaloft-shell straight from this checkout. consumers get the
  # same module through the `musicaloft-shell` input in their devenv.yaml,
  # but an input would pin a copy of the repository instead of testing the
  # working tree.
  imports = [ ../../devenv.nix ];

  # disable cachix pushing in tests so builds aren't pushed
  cachix.push = lib.mkForce null;
}
