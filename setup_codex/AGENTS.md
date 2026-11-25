# Repository Guidelines

## Project Structure & Module Organization

This directory contains a small Codex bootstrap kit for Debian/Ubuntu environments:

- `setup-root.sh`: root installer, including system dependencies.
- `setup-user.sh`: ordinary-user installer; system dependencies must already be available.
- `config.toml`: source template for model, provider, permissions, and terminal settings.
- `README.md`: user-facing instructions for authentication, configuration, installation, and startup.
- `.gitignore`: keeps `auth.json` excluded from Git as a safety net against accidental commits (login caches live in the system credential store or `${CODEX_HOME}/auth.json`, not in this directory).

There are no application modules, asset directories, build outputs, or automated test suites.

## Build, Test, and Development Commands

- `bash -n setup-root.sh setup-user.sh`: check both installer scripts without executing installation steps.
- `python3 -c 'import tomllib; tomllib.load(open("config.toml", "rb"))'`: validate TOML syntax with Python 3.11 or later.
- `bash setup-root.sh`: run the root installer on a suitable Debian/Ubuntu machine. It displays the configured default model (`model` and optional `review_model`), prompts for interactive model/proxy confirmation, installs packages, updates `$HOME/.bashrc` (nvm, `CODEX_HOME`, and the `codex` VPN wrapper), updates the destination `config.toml`, preserves any existing Codex login cache, and installs plugins.
- `bash setup-user.sh`: run the ordinary-user installer when system dependencies are already installed. It displays the configured default model, prompts for interactive model/proxy confirmation, updates the current user's `$HOME/.bashrc` (nvm, `CODEX_HOME`, and the `codex` VPN wrapper), updates the destination `config.toml`, preserves any existing Codex login cache, and installs plugins.
- `source ~/.bashrc`, followed by `codex login` and `codex`: load the installed Node environment and the persisted `CODEX_HOME`, authenticate the actual runtime user, and launch Codex. Set the same `CODEX_HOME` explicitly in environments that do not load `.bashrc`.

There is no separate build step. Do not run the installer merely to validate documentation changes.

## Coding Style & Naming Conventions

Use Bash with four-space indentation, quoted variable expansions, and descriptive snake_case variables. Preserve `set -eo pipefail`, temporary-directory cleanup, and explicit error handling around nvm commands. Follow the existing numbered Chinese section comments and progress messages.

Keep global TOML settings above named tables. Preserve plugin identifiers in the `name@deoxys` format. No formatter or linter configuration is currently included.

## Testing Guidelines

Run syntax checks after shell or configuration edits. For installer changes, use a disposable environment and verify installation, configuration file permissions, and repeat execution without duplicate Bash initialization lines. Record the environment and commands tested. No coverage threshold or test naming convention exists yet.

## Commit & Pull Request Guidelines

Use concise imperative subjects, such as `Fix configuration copy permissions`. Describe the change, its installation impact, validation performed, and any linked issue. Screenshots are unnecessary for this command-line project.

## Security & Configuration

Never include authentication values in commits, logs, or review descriptions. Codex creates and manages its login cache after `codex login`; it may use the system credential store or `${CODEX_HOME}/auth.json`. Installed configuration directories use mode `700`; the copied configuration file uses `600`. The current template enables Full Access with approvals disabled. Review permission changes explicitly. Edit this directory’s template for installer defaults; installation copies it to `${CODEX_HOME:-/SPXvePFS/users/wndai/.codex}` without replacing the login cache. The installer persists the selected `CODEX_HOME` in `.bashrc` on a line marked `# setup_codex`, updating that line when the destination changes. Existing data is not migrated automatically.
