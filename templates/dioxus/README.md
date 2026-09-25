# dioxus-app

A fullstack [Dioxus](https://dioxuslabs.com) web app, built and deployed with
[devenv](https://devenv.sh) and musicaloft-shell.

## Project layout

```
.
├─ assets/          # static assets, referenced with the asset! macro
├─ devenv/          # nix build, deployment, and overlay configuration
├─ src/
│  ├─ main.rs       # entrypoint and route definitions
│  ├─ components/   # shared components (hero, server function echo)
│  └─ views/        # one component per route, plus the navbar layout
├─ Cargo.toml       # dependencies and the web/server features dx uses
├─ Dioxus.toml      # dx configuration
└─ tailwind.css     # tailwind input stylesheet
```

## Developing

Enter the dev shell with `devenv shell`, then
start the dev server with hot reloading:

```bash
devenv up
```

This runs `dx serve`, which builds both the wasm client and the server and
serves the app on port 8080. The shell provides `dx`, `tailwindcss`,
`wasm-opt`, and a `wasm-bindgen` matching the version in `Cargo.lock`.

### Tailwind

dx regenerates `assets/tailwind.css` from `tailwind.css` whenever it builds,
so there's no separate tailwind process to run. The generated stylesheet is
tracked so the `asset!` macro can resolve it before dx has run.

### Updating dependencies

`wasm-bindgen-cli` must match the `wasm-bindgen` version in `Cargo.lock`
exactly, and `dx` should match the `dioxus` version. After updating either
crate, bump the matching packages in `devenv/overlay.nix`.

## Building

```bash
devenv build outputs.default
```

The result contains the server binary at `bin/dioxus-app` and the prebuilt
web assets at `bin/public`. The server listens on `IP` and `PORT` (defaulting
to `0.0.0.0:8080`).

## Deploying

The `deploy-production` and `deploy-staging` scripts build a container image,
load it into docker, and deploy it to [fly.io](https://fly.io) using the
generated `fly.<environment>.toml` files. flyctl authenticates with
`FLY_API_TOKEN`, which is declared in `secretspec.toml`.
