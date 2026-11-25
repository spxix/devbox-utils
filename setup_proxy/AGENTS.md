# Repository Guidelines

## Project Structure & Module Organization

This is a small Linux terminal proxy toolkit with no build step.

- `mihomo.py`: Python CLI for Mihomo lifecycle, configuration, status, and connectivity checks.
- `proxy.sh`: sourced Bash functions `proxyon`, `proxyoff`, and `print_ip_info`; sourcing defines commands without enabling the proxy.
- `test_connection.sh`: eight connectivity checks, public IPv4 lookup, and Cloudflare diagnostics.
- `install_mihomo.sh`: validates and extracts an uploaded Mihomo `.gz` archive into `.proxy/mihomo` without starting the proxy.
- `reference/.bashrc-cf2`: reference from a working VPN machine; not executed by the toolkit.
- `.proxy/`: local binary, generated configuration, process records, and logs.
- `README.md`: Chinese user documentation; keep command examples synchronized with implementation.

## Build, Test, and Development Commands

Use Linux x86_64, Python 3.8+, Bash, and curl.

```bash
bash -n proxy.sh test_connection.sh install_mihomo.sh  # Validate shell syntax
python3 mihomo.py check            # Validate node configuration offline
python3 mihomo.py status           # Inspect the managed process
python3 mihomo.py start            # Start service and install Bash startup configuration
source ./proxy.sh                  # Define terminal commands
proxyon                           # Enable terminal proxy; print IP information
proxyoff                          # Disable terminal proxy; print IP information
python3 mihomo.py test             # Explicit HTTP/SOCKS proxy checks
bash test_connection.sh            # Check connectivity using current environment
python3 mihomo.py stop             # Stop the managed service
```

## Coding Style & Naming Conventions

Use four-space Python indentation and snake_case functions. Match surrounding Bash indentation, quote variable expansions, and use arrays for command arguments. Keep changes focused. No formatter or linter configuration is currently provided.

## Testing Guidelines

There is no automated test framework or coverage threshold. Validate shell syntax and relevant CLI behavior. For shell changes, verify loading has no network side effects, switching clears all proxy variable variants, and bypass rules remain idempotent. Test startup-block migration and repeated installation against temporary files. Network failures may reflect environment conditions; report actual results without equating port readiness with connectivity.

## Commit & Pull Request Guidelines

Use concise imperative commit subjects. Describe changed behavior, verification commands and results, and configuration implications in pull requests; link relevant issues when available.

## Security & Agent Instructions

Never commit or expose `vless.txt`, generated credentials, or runtime logs; existing ignore rules exclude `.proxy/`, `vless.txt`, and Python caches. Do not directly edit the user's `~/.bashrc` unless explicitly requested. Update the installer in `mihomo.py`; let the user run `start` to apply it. Avoid restarting services merely to validate documentation or shell helpers.
