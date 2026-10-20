# Repository Guidelines

## Project Structure & Module Organization

This repository contains two independent Linux development-environment utilities:

- `setup_codex/` — Debian/Ubuntu installer for nvm, Node.js 24, Codex CLI, local Codex configuration, and Deoxys plugins.
- `setup_proxy/` — Mihomo lifecycle manager, VLESS configuration handling, shell proxy helpers, and connectivity diagnostics.
- `README.md` — repository-level usage and migration instructions.

Runtime data lives under `setup_proxy/.proxy/`. Treat `setup_codex/auth.json` and `setup_proxy/vless.txt` as secrets; do not publish their contents.

## Build, Test, and Development Commands

There is no build system or package manager for this repository. Run focused checks from the relevant directory:

```bash
bash -n setup_codex/setup.sh
python3 -c 'import tomllib; tomllib.load(open("setup_codex/config.toml", "rb"))'
bash -n setup_proxy/proxy.sh setup_proxy/test_connection.sh
python3 setup_proxy/mihomo.py check
```

Use `python3 setup_proxy/mihomo.py start`, `proxyon`, and `proxyoff` only in an environment where starting the local proxy is intended. Do not run the Codex installer merely to validate documentation changes.

## Coding Style & Naming Conventions

Use four-space indentation in Python and Bash, quote shell expansions, and use arrays for multi-argument shell commands. Python functions and variables use `snake_case`; shell functions use lower-case names such as `proxyon` and `proxyoff`. Preserve existing Chinese section comments and explicit error handling. Keep path resolution relative to each script’s own directory so the utilities remain movable.

## Testing Guidelines

No automated test framework or coverage threshold is configured. Every shell change should pass `bash -n`; Python changes should pass the relevant CLI validation or a focused manual command. Network-dependent checks (`mihomo.py test`, `test_connection.sh`) may fail because of the execution environment; record the actual result and distinguish network failure from syntax or logic failure.

## Commit & Pull Request Guidelines

This checkout currently has no Git history, so no established commit convention can be inferred. Use concise imperative commit subjects, for example `Improve proxy startup validation`. Pull requests should explain the affected utility, list validation commands and results, and call out configuration or security implications. Never include API keys, VLESS links, generated logs, or runtime state in commits.

## Security & Configuration

Keep `auth.json`, `vless.txt`, generated proxy configuration, and logs mode-restricted. Review changes to installer defaults, proxy bypass rules, external download URLs, and Codex permission settings carefully. Do not edit a user’s `~/.bashrc` or restart services during routine documentation review.
