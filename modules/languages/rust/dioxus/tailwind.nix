{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.languages.rust.dioxus.tailwind;

  # files whose presence makes dx run tailwind before building, checked in
  # the same order dx 0.7's `TailwindCli::autodetect` uses (config files
  # mean tailwind v3, a bare tailwind.css means v4)
  detectionFiles = [
    "tailwind.config.js"
    "tailwind.config.ts"
    "tailwind.css"
  ];

  # computes the build pieces needed to verify dx's own tailwind step for
  # the project at `path`.
  #
  # dx runs tailwind itself during `dx bundle`, but discards both its
  # output and its exit status, so a broken stylesheet would otherwise
  # ship as an empty (or stale) css file without any error.
  mkTailwindSteps =
    path:
    let
      dioxusTomlPath = path + "/Dioxus.toml";
      dioxusToml = lib.optionalAttrs (builtins.pathExists dioxusTomlPath) (lib.importTOML dioxusTomlPath);

      # dx's defaults when Dioxus.toml doesn't override them
      input = dioxusToml.application.tailwind_input or "tailwind.css";
      output = dioxusToml.application.tailwind_output or "assets/tailwind.css";

      enabled = builtins.any (file: builtins.pathExists (path + "/${file}")) detectionFiles;

      input' = lib.escapeShellArg input;
      output' = lib.escapeShellArg output;
    in
    {
      extraPaths = detectionFiles ++ [ input ];

      nativeBuildInputs = lib.optional enabled cfg.package;

      # start from an empty output so a stale or placeholder stylesheet
      # can't pass the check below. it must still exist, since the `asset!`
      # macro validates it at compile time.
      preBundle = lib.optionalString enabled ''
        mkdir -p "$(dirname ${output'})"
        : > ${output'}
      '';

      # rerun tailwind on failure purely to surface the error dx swallowed
      postBundle = lib.optionalString enabled ''
        if [ ! -s ${output'} ]; then
          echo "error: dx bundle didn't generate the tailwind stylesheet at ${output}." >&2
          echo "rerunning tailwindcss directly to show what went wrong:" >&2
          tailwindcss --input ${input'} --output ${output'} >&2 || true
          exit 1
        fi
      '';
    };
in
{
  options.languages.rust.dioxus = {
    tailwind.package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.tailwindcss_4;
      defaultText = lib.literalExpression "pkgs.tailwindcss_4";
      description = ''
        The `tailwindcss` package `dx bundle` runs for projects that use
        Tailwind, detected the same way dx does: a `tailwind.css` (or
        `tailwind.config.js`/`.ts`) next to `Cargo.toml`. Input and output
        paths follow `tailwind_input`/`tailwind_output` in `Dioxus.toml`.
      '';
    };

    mkTailwindSteps = lib.mkOption {
      type = lib.types.functionTo lib.types.raw;
      readOnly = true;
      internal = true;
      description = ''
        Computes the source paths, build inputs, and pre/post `dx bundle`
        shell snippets that verify dx generated a project's Tailwind
        stylesheet, failing the build loudly if it didn't.
      '';
    };
  };

  config.languages.rust.dioxus.mkTailwindSteps = mkTailwindSteps;
}
