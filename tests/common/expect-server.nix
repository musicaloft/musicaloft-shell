{
  curl,
  lib,
  runCommand,
}:
/**
  Builds a check that starts a fullstack Dioxus server, fetches pages from
  it, and verifies that it serves its wasm client.

  The server runs inside the build sandbox, listening on the loopback
  interface only.

  # Arguments

  - `name`: a name for the check, used in its derivation name and errors.
  - `package`: the server package, as built by
    `languages.rust.dioxus.import`.
  - `pages`: a list of `{ path, contains }` attribute sets. Every `path` is
    fetched from the server, and its response body must contain the
    `contains` string.
  - `port`: the port the server listens on.

  # Example

  ```nix
  testLib.expectServer {
    name = "my-app";
    package = config.outputs.default;
    pages = [
      { path = "/"; contains = "Hello"; }
    ];
  }
  ```
*/
{
  name,
  package,
  pages,
  port ? 8123,
}:
let
  expectPage =
    { path, contains }: "expect_page ${lib.escapeShellArg path} ${lib.escapeShellArg contains}";
in
runCommand "${name}-server-test" { nativeBuildInputs = [ curl ]; } ''
  export IP=127.0.0.1
  export PORT=${toString port}
  url="http://$IP:$PORT"

  fail() {
    echo "error: $1" >&2
    echo "the server's output was:" >&2
    cat server.log >&2
    exit 1
  }

  ${lib.getExe package} > server.log 2>&1 &
  server=$!
  trap 'kill "$server" 2>/dev/null || true' EXIT

  # the server takes a moment to bind its port
  for _ in $(seq 1 100); do
    if curl --silent --output /dev/null "$url/"; then
      break
    fi
    if ! kill -0 "$server" 2>/dev/null; then
      fail "${name}'s server exited before it started listening."
    fi
    sleep 0.1
  done

  expect_page() {
    local path="$1" contains="$2" body
    body="$(curl --silent --show-error --fail "$url$path")" \
      || fail "${name} couldn't serve $path. is the route defined?"
    if [[ "$body" != *"$contains"* ]]; then
      echo "$body" >&2
      fail "$path from ${name} is missing '$contains' (its response is above)."
    fi
  }

  ${lib.concatMapStringsSep "\n" expectPage pages}

  # without its wasm client, the page renders but never becomes interactive
  wasm="$(cd ${package}/bin/public && find . -name '*.wasm' -print -quit)"
  if [ -z "$wasm" ]; then
    fail "${name} has no wasm client in bin/public. did dx bundle the web target?"
  fi

  content_type="$(curl --silent --fail --output /dev/null --write-out '%{content_type}' "$url/''${wasm#./}")" \
    || fail "${name} couldn't serve its wasm client at /''${wasm#./}."
  if [ "$content_type" != application/wasm ]; then
    fail "${name} served its wasm client as '$content_type' instead of 'application/wasm'."
  fi

  touch $out
''
