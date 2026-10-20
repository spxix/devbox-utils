# Repository Guidelines

## Project Structure & Module Organization

This directory contains a small Codex bootstrap kit for Debian/Ubuntu environments:

- `setup.sh`: root-only installer for system dependencies, nvm, Node.js 24, Codex CLI, and Deoxys plugins. It also initializes Bash and installs configuration files.
- `config.toml`: source template for model, provider, permissions, and terminal settings.
- `auth.json`: authentication input; treat its contents as sensitive.
- `README.md`: user-facing instructions for authentication, configuration, installation, and startup.
- `.gitignore`: excludes the local authentication file `auth.json` from Git.

There are no application modules, asset directories, build outputs, or automated test suites.

## Build, Test, and Development Commands

- `bash -n setup.sh`: check Bash syntax without executing installation steps.
- `python3 -c 'import tomllib; tomllib.load(open("config.toml", "rb"))'`: validate TOML syntax with Python 3.11 or later.
- `bash setup.sh`: run the installer as root on a suitable Debian/Ubuntu machine. This installs packages, updates `$HOME/.bashrc`, overwrites destination configuration, and installs plugins.
- `source ~/.bashrc` followed by `codex`: load the installed Node environment and launch Codex. Set `CODEX_HOME` when using a custom configuration destination.

There is no separate build step. Do not run the installer merely to validate documentation changes.

## Coding Style & Naming Conventions

Use Bash with four-space indentation, quoted variable expansions, and descriptive snake_case variables. Preserve `set -eo pipefail`, temporary-directory cleanup, and explicit error handling around nvm commands. Follow the existing numbered Chinese section comments and progress messages.

Keep global TOML settings above named tables. Preserve plugin identifiers in the `name@deoxys` format. No formatter or linter configuration is currently included.

## Testing Guidelines

Run syntax checks after shell or configuration edits. For installer changes, use a disposable environment and verify installation, configuration file permissions, and repeat execution without duplicate Bash initialization lines. Record the environment and commands tested. No coverage threshold or test naming convention exists yet.

## Commit & Pull Request Guidelines

This checkout contains no Git metadata, so established commit conventions cannot be verified. Use concise imperative subjects, such as `Fix configuration copy permissions`. Describe the change, its installation impact, validation performed, and any linked issue. Screenshots are unnecessary for this command-line project.

## Security & Configuration

Never include authentication values in commits, logs, or review descriptions. Installed configuration directories use mode `700`; configuration and authentication files use `600`. The current template enables Full Access with approvals disabled. Review permission changes explicitly. Edit this directory’s template for installer defaults; installation copies it to `${CODEX_HOME:-$HOME/.codex}`.
