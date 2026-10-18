/**
  Helpers shared by every test project, available to their modules as the
  `testLib` module argument.
*/
{ pkgs }:
{
  expectOutput = pkgs.callPackage ./expect-output.nix { };
  expectSource = pkgs.callPackage ./expect-source.nix { };
}
