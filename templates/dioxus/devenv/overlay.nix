{
  overlays = [
    (final: prev: {
      dioxus-cli = prev.dioxus-cli.overrideAttrs (
        _:
        let
          version = "0.7.9";
          src = final.fetchCrate {
            pname = "dioxus-cli";
            inherit version;
            hash = "sha256-tLMtUlohSJt3okdJh+ARweQNGmzj/vYiNl8iZhDbSAc=";
          };
        in
        {
          inherit src version;
          cargoDeps = final.rustPlatform.fetchCargoVendor {
            inherit src;
            inherit (src) pname version;
            hash = "sha256-h5wkxHP8ehZLHqcUsro08/dpqSPnPuBbZuUGG8i4nBc=";
          };
        }
      );

      # must match the wasm-bindgen version pinned in Cargo.lock exactly
      wasm-bindgen-cli_0_2_128 =
        let
          src = final.fetchCrate {
            pname = "wasm-bindgen-cli";
            version = "0.2.128";
            hash = "sha256-a7lcXJnnZkYReja+iUO7NqqrWyv3toxnUgQb8s4IS5s=";
          };
        in
        final.buildWasmBindgenCli {
          inherit src;
          cargoDeps = prev.rustPlatform.fetchCargoVendor {
            inherit src;
            inherit (src) pname version;
            hash = "sha256-R1Tas33Ursy8kqsxguAkG0ZhNed2n5uFTAhw1l2qlLY=";
          };
        };
    })
  ];
}
