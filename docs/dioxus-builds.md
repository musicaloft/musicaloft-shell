# Building fullstack Dioxus apps

`languages.rust.dioxus` builds fullstack [Dioxus](https://dioxuslabs.com)
apps on top of the crane integration described in
[crane-builds.md](./crane-builds.md). It's optional; enabling
`languages.rust` doesn't require touching it.

## Usage

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

## Why this needs its own builder

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

## Cross-compiling the server

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
using dx's `@client`/`@server` target-override syntax (dx ≥0.7). See
[crane-builds.md](./crane-builds.md#cross-compiling) for how
`crossSystem` is handled.

## Sandbox workarounds baked in

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

- **`dioxus.import` targets a single crate**, matching the
  `dioxus new --fullstack` template's layout. Workspace-split fullstack
  projects (separate client/server/shared crates) aren't handled by this
  builder; compose `crane.importWorkspace` with your own `dx` invocation
  instead.
- The crane caveats in [crane-builds.md](./crane-builds.md#known-caveats)
  (such as source naming sensitivity) apply here too.
