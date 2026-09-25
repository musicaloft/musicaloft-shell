{ config, lib, ... }:
let
  cfg = config.languages.rust.crane;

  # expands a single cargo workspace member entry into a list of relative
  # directories. only trailing `/*` globs are supported (e.g. "crates/*"),
  # which covers the common workspace convention; anything else is
  # returned as-is.
  expandMemberGlob =
    root: pattern:
    if lib.hasSuffix "/*" pattern then
      let
        dir = lib.removeSuffix "/*" pattern;
      in
      map (name: "${dir}/${name}") (
        builtins.attrNames (
          lib.filterAttrs (_: type: type == "directory") (builtins.readDir (root + "/${dir}"))
        )
      )
    else
      [ pattern ];

  # resolves the list of member directories for a cargo workspace rooted at
  # `root`, expanding `workspace.members`/`workspace.exclude` globs.
  resolveMembers =
    root:
    let
      cargoToml = builtins.fromTOML (builtins.readFile (root + "/Cargo.toml"));
      expand = lib.concatMap (expandMemberGlob root);
      members = lib.unique (expand (cargoToml.workspace.members or [ ]));
      excluded = expand (cargoToml.workspace.exclude or [ ]);
    in
    lib.subtractLists excluded members;

  # imports a single Cargo package (crate) using crane.
  import' =
    path: args:
    let
      # doCheck only defaults to false for the package itself: the deps
      # build keeps crane's default so it also caches dev-dependencies for
      # the clippy/nextest checks, which run separately.
      result = cfg.mkArgs path args;
      pkg = result.craneLib.buildPackage (result.commonArgs // { doCheck = args.doCheck or false; });
    in
    pkg.overrideAttrs (old: {
      passthru = (old.passthru or { }) // {
        craneLib = result.craneLib;
        commonArgs = result.commonArgs;
        cargoArtifacts = result.cargoArtifacts;
        checks = cfg.mkChecks result;
      };
    });

  # imports every member of a cargo workspace using crane, sharing a single
  # `cargoArtifacts`/`cargoVendorDir` pair (built once, for the whole
  # workspace with `--all-targets`) across every member package and check.
  importWorkspace =
    path: args:
    let
      rootCargoToml = builtins.fromTOML (builtins.readFile (path + "/Cargo.toml"));
    in
    assert lib.assertMsg (!(rootCargoToml ? package && rootCargoToml ? workspace)) ''
      languages.rust.crane.importWorkspace: ${toString path}/Cargo.toml defines both
      [package] and [workspace]. cargo silently operates on just that package unless
      every invocation passes --workspace, which breaks crane's dependency caching
      across members. define only [workspace] in the root Cargo.toml instead. see:
      https://crane.dev/faq/constant-rebuilds.html#mixing-package-and-workspace-definitions-in-the-top-level-cargo-toml
    '';
    let
      members = args.members or (resolveMembers path);

      # everything but `members` is forwarded to crane, and from there into
      # the derivation's environment
      buildArgs = builtins.removeAttrs args [ "members" ];

      # `--all-targets` is deliberately left out: buildDepsOnly already adds
      # it to its `cargo check` (doCheck defaults to true there), cargo
      # rejects the flag twice, and `cargo doc` rejects it outright.
      deps = cfg.mkArgs path (
        {
          # a [workspace]-only root has no package name, so without these
          # crane would warn and fall back to its "cargo-package" placeholder
          pname = rootCargoToml.workspace.metadata.crane.name or "workspace";
          version = rootCargoToml.workspace.package.version or "0.0.0";
        }
        // buildArgs
        // {
          cargoExtraArgs = "--workspace " + (args.cargoExtraArgs or "");
        }
      );

      buildMember =
        dir:
        let
          memberCargoToml = builtins.fromTOML (builtins.readFile (path + "/${dir}/Cargo.toml"));
          pname = memberCargoToml.package.name;

          # crane's crateNameFromCargoToml only reads the member's own
          # Cargo.toml, so `version.workspace = true` would fall back to its
          # placeholder. resolve inheritance the way cargo does, with
          # cargo's own default when no version is set at all.
          memberVersion = memberCargoToml.package.version or null;
          version =
            if builtins.isString memberVersion then
              memberVersion
            else
              rootCargoToml.workspace.package.version or "0.0.0";
          memberArgs = cfg.mkArgs path (
            (builtins.removeAttrs buildArgs [ "cargoExtraArgs" ])
            // {
              inherit pname version;
              inherit (deps) pkgs craneLib;
              cargoArtifacts = deps.cargoArtifacts;
              cargoVendorDir = deps.cargoVendorDir;
              cargoExtraArgs = lib.concatStringsSep " " (
                [
                  "-p"
                  pname
                ]
                ++ lib.optional (args ? cargoExtraArgs) args.cargoExtraArgs
              );
              doCheck = args.doCheck or false;
            }
          );
          pkg = memberArgs.craneLib.buildPackage memberArgs.commonArgs;
        in
        lib.nameValuePair pname (
          pkg.overrideAttrs (old: {
            passthru = (old.passthru or { }) // {
              craneLib = memberArgs.craneLib;
              commonArgs = memberArgs.commonArgs;
            };
          })
        );
    in
    {
      packages = lib.listToAttrs (map buildMember members);
      deps = deps.cargoArtifacts;
      checks = cfg.mkChecks deps;
    };
in
{
  imports = [
    ./crane/args.nix
    ./crane/checks.nix
    ./crane/lib.nix
    ./crane/source.nix
    ./crane/splice.nix
  ];

  options.languages.rust.crane.import = lib.mkOption {
    type = lib.types.functionTo (lib.types.functionTo lib.types.package);
    readOnly = true;
    description = ''
      Import a single Cargo package using crane.

      This function takes a path to a directory containing a Cargo.toml
      file and returns a derivation that builds the Rust project using
      crane, with dependency artifacts cached in a separate derivation so
      editing the crate's own source never rebuilds its dependencies. The
      returned package carries `passthru.checks` (`clippy`, `doc`, `fmt`,
      `nextest`, `taplo`), `passthru.craneLib`, `passthru.commonArgs`, and
      `passthru.cargoArtifacts`, all reusing the same dependency build.

      The package is built with `doCheck = false` unless `args` says
      otherwise, since tests already run in `passthru.checks.nextest`. The
      dependency build still caches dev-dependencies for those checks.

      The `args` attribute set accepts everything `craneLib.buildPackage`
      does, plus:

      - `crossSystem`: a Nixpkgs `crossSystem` value to cross-compile for.
      - `crateExpression`: a `pkgs.callPackage`-style function returning
        extra `buildInputs`/`nativeBuildInputs`, spliced onto the correct
        build/host/target `pkgs` when cross-compiling.
      - `features`, `noDefaultFeatures`, `allFeatures`: cargo feature
        flags, folded into `cargoExtraArgs` consistently across the
        dependency build and every check.
      - `locked` (default `true`): pass `--locked` to cargo. Set this to
        `false` rather than adding or removing `--locked` in
        `cargoExtraArgs` yourself.

      Example usage:
      ```nix
      let
        mypackage = config.languages.rust.crane.import ./path/to/cargo/project { };
      in {
        languages.rust.enable = true;
        packages = [ mypackage ];
      }
      ```
    '';
  };

  options.languages.rust.crane.importWorkspace = lib.mkOption {
    type = lib.types.functionTo (lib.types.functionTo lib.types.raw);
    readOnly = true;
    description = ''
      Import every member of a Cargo workspace using crane.

      Workspace members are resolved from the root Cargo.toml's
      `workspace.members`/`workspace.exclude` (trailing `/*` globs are
      expanded), or can be given explicitly as a list of relative
      directories via `args.members`. Dependencies are built exactly
      once, for the whole workspace with `--all-targets`, and that same
      `cargoArtifacts`/`cargoVendorDir` pair is reused for every member
      package and every check.

      Returns an attribute set:

      - `packages`: an attrset of `<crate name> = package` for every
        workspace member.
      - `checks`: `clippy`, `doc`, `fmt`, `nextest`, `taplo`, run across
        the whole workspace.
      - `deps`: the shared `cargoArtifacts` derivation.

      The root Cargo.toml must define only `[workspace]`; mixing
      `[package]` and `[workspace]` in the same file breaks crane's
      cross-derivation caching (see crane's FAQ on constant rebuilds).

      Example usage:
      ```nix
      let
        workspace = config.languages.rust.crane.importWorkspace ./. { };
      in {
        languages.rust.enable = true;
        packages = builtins.attrValues workspace.packages;
      }
      ```
    '';
  };

  config.languages.rust.crane = {
    import = import';
    inherit importWorkspace;
  };
}
