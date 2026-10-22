# Build system tests

The `tests/` directory holds small Rust and Dioxus projects that are built
with musicaloft-shell's [crane](./crane-builds.md) and
[Dioxus](./dioxus-builds.md) integrations, checking that the builds work
and that what they produce actually runs.

## Running the tests

```bash
# every project, with devenv's own test command
devenv test

# or with the runner directly, which can run only some projects
tests/run.sh
tests/run.sh crane-simple dioxus-simple
```

`devenv test` in this repository's root runs `.test.sh`, which calls
`tests/run.sh`. Only this repository does: consumers of musicaloft-shell
import its `devenv.nix` and never see the root `.test.sh`.

For each project, the runner does two things and prints a summary at the
end:

1. `devenv build` builds every output, which includes the project's
   packages and crane checks. A failing build doesn't stop the rest of the
   project from building, so one run reports every failure.
2. `devenv test` runs the project's `.test.sh`, which checks that what was
   built is correct.

To work on one project, run the same commands from its directory:

```bash
cd tests/crane-cross
devenv build outputs.linux.aarch64
devenv test
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
| `dioxus-workspace` | `dioxus.import` and `crane.importWorkspace` | A fullstack app split into `web`, `ui`, and `api` crates, as `dx new` lays out workspaces, built from the default workspace source, with assets in a library crate and Tailwind sources from a sibling crate.                               |

The Dioxus apps are tested by running their servers as devenv processes
and fetching pages, a server function, and the wasm client from them.

## How the projects are put together

Every project is a normal devenv project, laid out the way a consumer of
musicaloft-shell would lay it out, with two differences:

- Instead of a `musicaloft-shell` input, each project imports
  `tests/common`, which imports this checkout's `devenv.nix` directly. That
  way the tests always run against the working tree.
- `tests/common` turns off git hooks and treefmt. The projects live inside
  musicaloft-shell's own git repository, so `devenv test` would otherwise
  install their hooks over the repository's and run every hook and
  formatter against all of its files.

The Dioxus projects also import `tests/common/dioxus.nix`, which reuses
the Dioxus template's overlay so they're pinned to the same `dx` and
`wasm-bindgen-cli` versions as the template. Their `Cargo.lock` files pin
the same `dioxus` and `wasm-bindgen` versions as the template's.

Each project's outputs follow the same shape:

- its packages, with `outputs.default` as the main one
- `outputs.checks`: the crane checks (`clippy`, `doc`, `fmt`, `nextest`,
  `taplo`)

`crane-cross` namespaces its outputs under `outputs.linux` and
`outputs.wasm` instead, one for each of its modules, since devenv doesn't
merge nested `outputs` attributes defined in more than one module.

### Test scripts

Every project has a `.test.sh`, which devenv runs inside the project's
shell during `devenv test`. A script checks the built packages with the
helpers in `tests/common/lib.sh`, and ends with `finish`:

```bash
#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../common/lib.sh"

expect_output "default" "hello" "$TEST_PACKAGE/bin/hello"

finish
```

A failed assertion is counted but doesn't stop the script, so one run
reports every failure. That's why scripts use `set -uo pipefail` without
`-e`.

A project's `devenv.nix` hands the script what it needs through `TEST_*`
environment variables: store paths for the packages under test, and strings
for anything only Nix knows, like a dependency's version. The variables,
and any tools the script uses, are only set when `config.devenv.isTesting`
is true. That keeps the packages from being built, and the tools from being
fetched, every time someone enters a project's shell.

The helpers in `tests/common/lib.sh`:

- `expect_equal`: compares two strings.
- `expect_output`: runs a command and compares its output to a string.
- `expect_files` and `expect_no_files`: check which files made it through a
  source filter.
- `expect_page`: fetches a page from a running server and checks that it
  contains a string.
- `expect_wasm_client`: checks that a running server serves its wasm
  client with the right content type.
- `finish`: exits non-zero if any assertion failed.

### Dioxus servers

`tests/common/server.nix`, imported by `tests/common/dioxus.nix`, runs
`outputs.default` as a devenv process while testing. devenv starts it
before the script and stops it afterwards. It listens on a free port, so
scripts get its address from `TEST_SERVER_URL` and should call
`wait_for_processes` before fetching pages.

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
   Set the `TEST_*` variables the script needs, gated on
   `config.devenv.isTesting`.
4. Write an executable `.test.sh` that sources `../common/lib.sh`.

`tests/run.sh` picks up every directory with a `devenv.nix` automatically.
