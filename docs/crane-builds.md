# Building Rust projects with crane

`languages.rust.crane` builds Cargo projects using [crane](https://crane.dev)
instead of devenv's default crate2nix integration (`languages.rust.import`).
It's optional; enabling `languages.rust` doesn't require touching it.

For fullstack Dioxus apps, see [dioxus-builds.md](./dioxus-builds.md), which
builds on top of the crane integration described here.

## Why crane instead of crate2nix

crate2nix generates a Nix expression per dependency crate via IFD, which
gives fine-grained caching but pays for it with slow, fragile evaluation.
crane instead builds the whole dependency graph with a single `cargo
build` inside one derivation (`cargoArtifacts`), then reuses that
derivation's `target/` directory for the real build. This module leans
hard on that model: every builder here computes its source, craneLib, and
`cargoArtifacts`/`cargoVendorDir` exactly once and threads them through
explicitly, so identical inputs always produce identical (and therefore
cache-hitting) dependency builds. See crane's own
[constant rebuilds FAQ](https://crane.dev/faq/constant-rebuilds.html) for
the failure modes this avoids.

## Building a single crate

```nix
{ config, ... }:
{
  languages.rust.enable = true;

  outputs.default = config.languages.rust.crane.import ./. { };
}
```

`import` returns a normal package. It also carries:

- `passthru.checks.{clippy,doc,fmt,nextest,taplo}` — all built against the
  same `cargoArtifacts` as the package itself.
- `passthru.craneLib`, `passthru.commonArgs`, `passthru.cargoArtifacts` —
  escape hatches for composing further crane derivations by hand.

Checks are returned, not auto-wired into `git-hooks` or `enterTest` — wire
them up yourself if you want them:

```nix
outputs = {
  default = mypackage;
  clippy = mypackage.passthru.checks.clippy;
};
```

### Extra arguments

`args` accepts everything `craneLib.buildPackage` does, plus:

- `features`, `noDefaultFeatures`, `allFeatures` — folded into
  `cargoExtraArgs` consistently between the dependency build and every
  check, avoiding the feature-mismatch rebuilds crane's FAQ warns about.
- `crossSystem` — a Nixpkgs `crossSystem` value to cross-compile for.
- `crateExpression` — a `pkgs.callPackage`-style function returning extra
  `buildInputs`/`nativeBuildInputs`, spliced onto the correct
  build/host/target `pkgs` when cross-compiling (see below).

## Building a workspace

```nix
let
  workspace = config.languages.rust.crane.importWorkspace ./. { };
in
{
  languages.rust.enable = true;
  packages = builtins.attrValues workspace.packages;
}
```

Members are resolved from the root `Cargo.toml`'s
`workspace.members`/`workspace.exclude` (trailing `/*` globs are
expanded), or given explicitly via `args.members` (a list of relative
directories) if your workspace layout needs something more exotic.

Dependencies are built exactly **once**, for the whole workspace with
`--all-targets`, and that single `cargoArtifacts`/`cargoVendorDir` pair is
reused by every member package and every check. `importWorkspace` returns:

- `packages`: `{ <crate name> = package; ... }`
- `checks`: `clippy`, `doc`, `fmt`, `nextest`, `taplo`, run once across the
  whole workspace
- `deps`: the shared `cargoArtifacts` derivation

The root `Cargo.toml` must define only `[workspace]`. Cargo silently
scopes itself to a single package if the root also defines `[package]`,
which breaks the dependency caching this function relies on —
`importWorkspace` asserts against this and points at crane's FAQ.

## Cross-compiling

```nix
config.languages.rust.crane.import ./. {
  crossSystem = "aarch64-linux";
  crateExpression = { openssl, pkg-config, lib, stdenv }: {
    nativeBuildInputs = [ pkg-config ];
    buildInputs = [ openssl ];
  };
}
```

Setting `crossSystem` re-instantiates nixpkgs for that target (carrying
over this shell's overlays and nixpkgs config) and pins crane's toolchain
override to a function, matching
[crane's cross-rust-overlay example](https://crane.dev/examples/cross-rust-overlay.html).
Nixpkgs' own cross toolchain env (linker, `CC`/`CXX`/`AR`, an emulator
`RUNNER` if available) is injected automatically by crane's
`mkCargoDerivation`.

`crateExpression` exists because plain `buildInputs = [ pkgs.openssl ]`
would pull `openssl` for the _build_ platform, not the cross target. The
function's parameter names are looked up against the cross-instantiated
`pkgs` the same way `pkgs.callPackage` would, but without
`pkgs.callPackage` itself: callPackage wraps every result in
`makeOverridable`, which injects an `override` function into whatever
attrset the function returns — harmless for a real package, fatal for a
plain `buildInputs`/`nativeBuildInputs` fragment merged into `commonArgs`.

The escape hatches `languages.rust.crane.mkLib { crossSystem }` and
`.mkPkgs { crossSystem }` are available if you want to build crane
derivations by hand instead of going through `import`/`importWorkspace`.

## Known caveats

- **Source naming sensitivity.** `mkSource` uses `lib.fileset.toSource`,
  which (unlike `craneLib.cleanCargoSource`) names its output after the
  root directory's basename. Renaming a checkout directory changes the
  resulting store path's derivation inputs, though not usually the build
  outcome.
- **Workspace member globs.** `importWorkspace`'s member resolution only
  expands a single trailing `/*` (e.g. `"crates/*"`), matching the common
  convention. Nested or multi-level globs aren't expanded — pass
  `args.members` explicitly if you need that.
