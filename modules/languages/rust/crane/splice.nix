{ lib, ... }:
{
  options.languages.rust.crane.spliceCrateExpression = lib.mkOption {
    type = lib.types.functionTo (lib.types.functionTo lib.types.raw);
    readOnly = true;
    internal = true;
    description = ''
      Calls a `crateExpression` function with arguments looked up by name
      in the given `pkgs`, like `pkgs.callPackage` but without the
      `override` attributes it injects. Returns the function's result with
      `buildInputs` and `nativeBuildInputs` always present.
    '';
  };

  # auto-fills a caller's crateExpression from `pkgs` by parameter name,
  # the same way `pkgs.callPackage` would, so buildInputs/nativeBuildInputs
  # are spliced onto the correct build/host/target pkgs when
  # cross-compiling. see:
  # https://crane.dev/examples/cross-rust-overlay.html
  #
  # `pkgs.callPackage` itself isn't used here: it wraps every result in
  # `makeOverridable`, which injects an `override` function into any
  # attrset it returns -- fine for a package, fatal for a plain
  # buildInputs/nativeBuildInputs fragment merged into a derivation's args.
  config.languages.rust.crane.spliceCrateExpression =
    pkgs: crateExpression:
    {
      buildInputs = [ ];
      nativeBuildInputs = [ ];
    }
    // crateExpression (builtins.intersectAttrs (builtins.functionArgs crateExpression) pkgs);
}
