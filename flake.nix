{
  description = "The Musicaloft standard shell and Nix templates";

  outputs =
    { self }:
    {
      templates = {
        basic = {
          path = ./templates/basic;
          description = "A simple devenv and flake with musicaloft-shell";
        };
        dioxus = {
          path = ./templates/dioxus;
          description = "A fullstack Dioxus web app with devenv, crane, Tailwind, and fly.io deployment";
        };
        python = {
          path = ./templates/python;
          description = "A Python template with devenv, uv, ruff, ty, and git hooks";
        };
        rust = {
          path = ./templates/rust;
          description = "A Rust nightly template with devenv, treefmt, and git hooks";
        };
      };

      defaultTemplate = self.templates.basic;
    };
}
