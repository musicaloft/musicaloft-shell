# Building Rust projects with crane

`languages.rust.crane` and `languages.rust.dioxus` build Cargo projects
using [crane](https://crane.dev) instead of devenv's default crate2nix
integration (`languages.rust.import`). Both are optional; enabling
`languages.rust` doesn't require touching either.

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

## Fullstack Dioxus apps

```nix
{ config, pkgs, ... }:
{
  languages.rust = {
    enable = true;
    targets = [ "wasm32-unknown-unknown" ]; # plus your server's target
    dioxus = {
      enable = true;
      # must match the wasm-bindgen version pinned in Cargo.lock exactly
      wasmBindgenPackage = pkgs.wasm-bindgen-cli_0_2_128;
      tailwind.enable = true; # if your project uses Tailwind
    };
  };

  outputs.default = config.languages.rust.dioxus.import ./. { };
}
```

`languages.rust.dioxus.import` builds a fullstack Dioxus app with `dx
bundle --fullstack` on top of crane-cached dependency artifacts. The
result has `$out/bin/<pname>` (the server binary, wrapped with
`IP`/`PORT` defaults) alongside `$out/bin/public` (the prebuilt web
assets).

### Why this needs its own builder

`dx bundle --fullstack` drives cargo directly for two targets — the
native server and the wasm client — in one invocation. crane's
`buildDepsOnly` only warms one target by default, so this builder
overrides its build command to compile dependencies for **both** targets
into a single `cargoArtifacts` output before `dx bundle` ever runs.

For that cache to actually help, the feature flags used to warm each
target must match what `dx` itself uses internally:
`languages.rust.dioxus.serverFeatures`/`.clientFeatures` default to
`[ "server" ]`/`[ "web" ]`, matching the `dioxus new` project template's
`[features]` convention (`default = ["web"]`, plus optional
`server`/`desktop`/`mobile` features gating each platform's `dioxus`
feature). If your project's features drift from that convention, update
these options to match.

**This warming is inherently best-effort, and in practice buys less than
the equivalent `crane.import`/`importWorkspace` caching does.** `dx`
builds each platform under its own generated cargo profile (observed as
`server-release`/`web-release`, each `inherits = "release"`), which lives
in its own `target/<profile>/` directory — a detail of `dx`'s `pub(crate)`
internals, not a stable interface. This module's warming step uses the
plain `release` profile instead, so `dx bundle`'s own invocation ends up
compiling most dependency crates itself regardless, even though the
`cargoArtifacts` derivation itself stays stable (and thus skips a
redundant _nix-level_ rebuild/cache-download) across unrelated changes.
If `dx` ever exposes its per-platform profile names as something other
than an implementation detail, warming with the matching profile would
close this gap; until then, treat the wasm/server dependency warm-up here
as reducing eval/store-level churn rather than as a guarantee that `dx
bundle` itself skips recompiling dependencies.

### Cross-compiling the server

```nix
config.languages.rust.dioxus.import ./. {
  crossSystem = "aarch64-linux";
}
```

The web client always targets `languages.rust.dioxus.clientTarget`
(`wasm32-unknown-unknown` by default) regardless of `crossSystem`, since
it's cross-compiled at the cargo level rather than the nixpkgs stdenv
level. The server target is cross-compiled properly (via
`crane.mkLib`/`mkPkgs`, same as `crane.import`) and passed to `dx bundle`
using dx's `@client`/`@server` target-override syntax (dx ≥0.7).

### Sandbox workarounds baked in

- `HOME`, `CARGO_NET_OFFLINE`, `DIOXUS_TELEMETRY_ENABLED=false`,
  `NO_DOWNLOADS=1` are all set so `dx bundle` never touches the network or
  the real `$HOME`.
- `dx`'s own `wasm-opt` invocation SIGABRTs under the Nix sandbox because
  binaryen's thread pool spawning is blocked by the seccomp profile. A
  passthrough stub intercepts it so `dx bundle` succeeds, then a real
  `wasm-opt -Oz` pass runs afterwards with threading disabled.
- If `tailwind.enable` is set, the Tailwind stylesheet is pre-generated
  before `dx bundle` runs, since Dioxus's `asset!` macro validates the
  asset path exists at compile time.

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
- **`dioxus.import` targets a single crate**, matching the
  `dioxus new --fullstack` template's layout. Workspace-split fullstack
  projects (separate client/server/shared crates) aren't handled by this
  builder; compose `crane.importWorkspace` with your own `dx` invocation
  instead.
