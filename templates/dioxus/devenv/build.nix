{ config, ... }:
{
  outputs.default = config.languages.rust.dioxus.import ./.. { };
}
