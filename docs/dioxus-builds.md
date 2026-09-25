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

`languages.rust.dioxus.import` builds a fullstack Dioxus app with a
single `dx bundle --fullstack` run. The result has `$out/bin/<pname>`
(the server binary, wrapped with `IP`/`PORT` defaults) alongside
`$out/bin/public` (the prebuilt web assets).

## Why there's no dependency cache

`dx bundle --fullstack` drives cargo itself for two targets, the native
server and the wasm client, and builds each under its own generated
cargo profile (`server-release` and `web-release`). Cargo keeps a
separate `target/<profile>/` directory per profile, so dependencies
prebuilt by a crane `buildDepsOnly` step under any other profile are
never reused; `dx` recompiles them all anyway, and the prebuild only adds
a second full dependency build.

Because of that, every change to the project's sources rebuilds the whole
bundle, dependencies included. The source filter still keeps unrelated
edits (`devenv.nix`, `README.md`, ...) from triggering a rebuild at all.

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
