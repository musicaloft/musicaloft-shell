# Build system tests

The `tests/` directory holds small Rust and Dioxus projects that are built
with musicaloft-shell's [crane](./crane-builds.md) and
[Dioxus](./dioxus-builds.md) integrations, checking that the builds work
and that what they produce actually runs.

## Running the tests

```bash
# every project
tests/run.sh

# only some projects
tests/run.sh crane-simple dioxus-simple
```

The runner builds every output of each project with `devenv build`, which
includes its packages, crane checks, and tests, and prints a summary at
the end. A failing build doesn't stop the rest of the project from
building, so one run reports every failure.

To build a single output instead, run `devenv build` from the project's
directory:

```bash
cd tests/crane-cross
devenv build outputs.linux.tests.aarch64
```

The tests expect an `x86_64-linux` machine, since the cross-compilation
tests compare against the triples they expect to cross-compile _to_ from
there. The Dioxus projects and the cross toolchains need several
gigabytes of free space in the Nix store.

## What's tested

| Project            | Builder                                     | What it covers                                                                                                                                                                                                                              |
| ------------------ | ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `crane-simple`     | `crane.import`                              | A single crate on stable Rust with a dependency, feature flags, a non-Rust source file kept with `extraFileTypes`, the source filter, and every crane check.                                                                                |
| `crane-workspace`  | `crane.importWorkspace`                     | A workspace on nightly Rust with glob and explicit members, an excluded member that fails to compile if it's ever built, version inheritance, a lib-only member, a single shared dependency build, and a WASI build of the whole workspace. |
| `crane-cross`      | `crane.import`                              | Cross-compiling to aarch64 (run under qemu) and static musl through `crossSystem`, a C dependency spliced in with `crateExpression`, and bare `wasm32-unknown-unknown` and `wasm32-wasip1` builds (run with wasmtime).                      |
| `dioxus-simple`    | `dioxus.import`                             | A single-crate fullstack app with Tailwind, server-side rendering with server function data, and crane checks alongside the bundle.                                                                                                         |
| `dioxus-workspace` | `dioxus.import` and `crane.importWorkspace` | A fullstack app split into `web`, `ui`, and `api` crates, as `dx new` lays out workspaces, with assets in a library crate and Tailwind sources from a sibling crate.                                                                        |

The Dioxus apps are tested by starting their servers inside the build
sandbox and fetching pages, a server function, and the wasm client from
them.

## How the projects are put together

Every project is a normal devenv project, laid out the way a consumer of
musicaloft-shell would lay it out, with two differences:

- Instead of a `musicaloft-shell` input, each project imports
  `tests/common`, which imports this checkout's `devenv.nix` directly. That
  way the tests always run against the working tree.
- `tests/common` turns off git hook installation, since the projects live
  inside musicaloft-shell's own repository.

The Dioxus projects also import `tests/common/dioxus.nix`, which reuses
the Dioxus template's overlay so they're pinned to the same `dx` and
`wasm-bindgen-cli` versions as the template. Their `Cargo.lock` files pin
the same `dioxus` and `wasm-bindgen` versions as the template's.

Each project's outputs follow the same shape:

- its packages, with `outputs.default` as the main one
- `outputs.checks`: the crane checks (`clippy`, `doc`, `fmt`, `nextest`,
  `taplo`)
- `outputs.tests`: checks that the packages are correct, built with the
  helpers in `tests/common/lib.nix`

`crane-cross` namespaces its outputs under `outputs.linux` and
`outputs.wasm` instead, one for each of its modules, since devenv doesn't
merge nested `outputs` attributes defined in more than one module.

### Test helpers

`tests/common/lib.nix` is passed to every project as the `testLib` module
argument:

- `expectOutput`: runs a command and compares its output to a string.
- `expectEqual`: compares two Nix values, failing at build time rather
  than evaluation time, so a mismatch is reported alongside the other
  failures.
- `expectSource`: checks which files made it through a source filter.
- `expectServer`: starts a fullstack Dioxus server and checks the pages it
  serves, and that it serves its wasm client.

## Updating inputs

Every project has its own `devenv.lock`, and they're all kept identical so
the projects share one Rust toolchain and one nixpkgs. To update them,
update one and copy it to the rest:

```bash
(cd tests/crane-simple && devenv update)
for dir in tests/*/; do
  if [ -f "$dir/devenv.nix" ] && [ "$dir" != tests/crane-simple/ ]; then
    cp tests/crane-simple/devenv.lock "$dir"
  fi
done
```

When the Dioxus template's pinned `dx` or `wasm-bindgen-cli` versions
change, update the `dioxus` and `wasm-bindgen` versions in the Dioxus
projects' `Cargo.lock` files to match.

## Adding a project

1. Create a directory under `tests/` with a Cargo project in it.
2. Copy `devenv.yaml` and `devenv.lock` from another project.
3. Write a `devenv.nix` that imports `../common` (and
   `../common/dioxus.nix` for Dioxus apps) and defines the outputs above.

`tests/run.sh` picks up every directory with a `devenv.nix` automatically.
