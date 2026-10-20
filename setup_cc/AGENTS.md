# Repository Guidelines

## Project Structure & Module Organization

This directory provides the Claude Code installer within `devbox-utils`:

- `setup-user.sh`: ordinary-user installer for nvm, Node.js 24, Claude Code, Bash initialization, and Deoxys plugins.
- `settings.example.json`: shareable configuration template with placeholder credentials.
- `settings.json`: optional local configuration, excluded by `.gitignore`.
- `README.md`: installation, authentication, and startup instructions.

Sibling directories `../setup_codex/` and `../setup_proxy/` contain separate utilities. There are no application modules, assets, build outputs, or dedicated test directories here.

## Build, Test, and Development Commands

Run checks from this directory:

```bash
bash -n setup-user.sh
python3 -c 'import json; json.load(open("settings.example.json"))'
```

These validate shell syntax and the example JSON without installing anything. There is no build system or configured formatter.

`bash setup-user.sh` performs installation and requires an interactive proxy confirmation. It downloads software, edits `~/.bashrc`, may overwrite Claude settings, and installs plugins. Run it only when installation is intended. After installation, use `source ~/.bashrc` and `claude --version` to check command resolution.

## Coding Style & Naming Conventions

Use four-space indentation, snake_case shell variables, quoted expansions, and arrays for argument lists. Preserve numbered Chinese comments, explicit error handling, `set -eo pipefail`, restrictive permissions, and temporary-directory cleanup. Resolve input files relative to the script directory. Use `command claude` inside the Bash wrapper to avoid recursion.

## Testing Guidelines

No automated framework or coverage threshold is configured. Check shell syntax after every script edit. Use temporary fixtures to verify missing, blank, `{}`, malformed, and populated settings; repeat execution; wrapper argument forwarding; and proxy-check failures. Distinguish network or authentication failures from local logic errors. Do not modify live shell configuration merely to test changes.

## Commit & Pull Request Guidelines

Existing subjects include `Document root and user Codex setup`; use similarly concise imperative subjects. Keep unrelated utilities in separate commits where practical. PRs should describe behavior changes, validation commands and results, configuration impacts, and relevant issues. Screenshots are unnecessary for installer changes.

## Security & Configuration

Never commit or print credentials. Missing, blank, or `{}` settings must preserve existing configuration; nonempty objects replace it. Keep installed directories at `700` and copied settings at `600`. Preserve ordinary Git authentication when fetching Deoxys before registering its local directory with Claude.
