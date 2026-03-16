# musicaloft-shell

This is the standardized Musicaloft code style for consistent formatting and development practices
across all Musicaloft projects.

This repository is open for you to use on your own projects as well!

## Overview

`musicaloft-shell` provides a devenv module for consistent development environments across projects.

## Features

### Code formatters

Automatically formats code using treefmt with the following tools:

- **kdlfmt** - KDL formatting
- **nixfmt** - Nix code formatting
- **oxfmt** - TypeScript and JavaScript formatting
- **ruff-check** - Python linting
- **ruff-format** - Python formatting
- **rustfmt** - Rust code formatting
- **sqruff** - SQL formatting
- **taplo** - TOML formatting

### Git hooks

Pre-commit hooks powered by git-hooks-nix:

#### Universal hooks

- **treefmt** - Automatically formats staged files before commit
- **commitlint-rs** - Validates commit messages using conventional commit format

#### Rust projects

- **clippy** - Lints Rust code with all features enabled, denying warnings

#### TypeScript projects

- **oxlint** - Type-aware linting with warnings treated as errors

#### Python projects

- **ruff** - Lints Python code
- **ruff-format** - Formats Python code
- **ty** - Type-checks Python code

#### Commit message format

```
type(scope): description under 72 characters
```

**Allowed types**:

| Type       | Description                                      |
| ---------- | ------------------------------------------------ |
| `build`    | Changes the build process                        |
| `chore`    | Doesn't affect source code                       |
| `ci`       | Affects CI/CD pipelines                          |
| `docs`     | Affects comments or documentation                |
| `dx`       | Improves or changes developer experience         |
| `feat`     | Adds a new user-facing feature                   |
| `fix`      | Introduces a user-facing bug fix                 |
| `perf`     | Improves performance                             |
| `refactor` | Changes source code without a new feature or fix |
| `revert`   | Reverts a previous commit                        |
| `style`    | Changes how code or documents are formatted      |
| `test`     | Changes or adds automated testing                |

**Rules**:

- Description must be lowercase
- Maximum 72 characters
- Scope maximum 10 characters (warning)

## Usage

In `devenv.yaml`:

```yaml
inputs:
  musicaloft-shell:
    url: github:musicaloft/musicaloft-shell
    flake: false

    # optional
    inputs:
      nixpkgs:
        follows: nixpkgs

  # you may need to add these dependencies and more, depending on your project
  git-hooks:
    url: github:cachix/git-hooks.nix
    inputs:
      nixpkgs:
        follows: nixpkgs
  treefmt-nix:
    url: github:numtide/treefmt-nix
    inputs:
      nixpkgs:
        follows: nixpkgs

# import the module
imports:
  - musicaloft-shell
```

And that's it!

### Setup

```bash
# clone the repository
git clone git@git.musicaloft.com:musicaloft/musicaloft-shell.git
cd musicaloft-shell

# allow direnv for automatic environment loading
direnv allow

# or manually enter the development shell
devenv shell
```

## License

MIT License - Copyright (c) 2026 Musicaloft LLC

See [LICENSE](./LICENSE) for details.
