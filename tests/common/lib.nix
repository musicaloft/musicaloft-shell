/**
  Helpers shared by every test project, available to their modules as the
  `testLib` module argument.
*/
{ pkgs }:
{
  expectEqual = pkgs.callPackage ./expect-equal.nix { };
  expectOutput = pkgs.callPackage ./expect-output.nix { };
  expectServer = pkgs.callPackage ./expect-server.nix { };
  expectSource = pkgs.callPackage ./expect-source.nix { };
}
