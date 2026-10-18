{ lib, ... }:
let
  # finds the directory cargo builds the crate at `path` from: the crate
  # itself when it's standalone, or the root of the workspace it belongs
  # to. cargo keeps Cargo.lock in exactly that directory, so the search
  # walks up from the crate to the nearest Cargo.lock, which also keeps it
  # inside the project's own source tree.
  workspaceRoot =
    path:
    if builtins.pathExists (path + "/Cargo.lock") then
      path
    else if dirOf path == path then
      throw ''
        languages.rust.crane couldn't find a Cargo.lock for the crate at ${toString path}.
        run `cargo generate-lockfile` in the crate's directory (or its workspace's root)
        so its dependencies are locked.
      ''
    else
      workspaceRoot (dirOf path);

  # resolves the version of the crate at `path` the way cargo does: only an
  # explicit `version.workspace = true` inherits the workspace's version,
  # and a crate with no version at all gets cargo's own default.
  crateVersion =
    path:
    let
      version = (lib.importTOML (path + "/Cargo.toml")).package.version or "0.0.0";
      root = workspaceRoot path;
    in
    if builtins.isAttrs version then
      (lib.importTOML (root + "/Cargo.toml")).workspace.package.version or (throw ''
        ${toString path}/Cargo.toml inherits its version from the workspace, but
        ${toString root}/Cargo.toml doesn't set workspace.package.version.
      '')
    else
      version;
in
{
  options.languages.rust.crane = {
    workspaceRoot = lib.mkOption {
      type = lib.types.functionTo lib.types.path;
      readOnly = true;
      internal = true;
      description = ''
        Finds the directory cargo builds the crate at the given path from:
        the crate itself when it's standalone, or the root of its workspace.
        This is the nearest directory containing a Cargo.lock, starting at
        the crate itself.
      '';
    };

    crateVersion = lib.mkOption {
      type = lib.types.functionTo lib.types.str;
      readOnly = true;
      internal = true;
      description = ''
        Resolves the version of the crate at the given path the way cargo
        does, including `version.workspace = true` inheritance, and
        defaulting to `0.0.0` when no version is set.
      '';
    };
  };

  config.languages.rust.crane = {
    inherit crateVersion workspaceRoot;
  };
}
