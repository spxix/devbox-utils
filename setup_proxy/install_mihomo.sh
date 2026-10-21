#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
archive_name='mihomo-linux-amd64-compatible-v1.19.32.gz'
archive_path="$script_dir/$archive_name"
expected_sha256='ba3ce607747a07f948fc35780e108a4a7c7f552a38b9bd4d115f313ebcb89c20'

cd "$script_dir"
if [[ ! -f "$archive_path" ]]; then
    printf '找不到 Mihomo 压缩包：%s\n' "$archive_path" >&2
    exit 1
fi

printf '%s  %s\n' "$expected_sha256" "$archive_name" | sha256sum -c -
python3 mihomo.py stop
mkdir -p .proxy
chmod 700 .proxy
gzip -dc "$archive_path" > .proxy/mihomo
chmod 700 .proxy/mihomo
printf 'Mihomo 已安装到 %s\n' "$script_dir/.proxy/mihomo"
