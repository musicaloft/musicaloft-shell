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

      wasm-bindgen-cli_0_2_121 =
        let
          src = final.fetchCrate {
            pname = "wasm-bindgen-cli";
            version = "0.2.121";
            hash = "sha256-ZOMgFNOcGkO66Jz/Z83eoIu+DIzo3Z/vq6Z5g6BDY/w=";
          };
        in
        final.buildWasmBindgenCli {
          inherit src;
          cargoDeps = prev.rustPlatform.fetchCargoVendor {
            inherit src;
            inherit (src) pname version;
            hash = "sha256-DPdCDPTAPBrbqLUqnCwQu1dePs9lGg85JCJOCIr9qjU=";
          };
        };
    })
  ];
}
