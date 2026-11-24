#!/usr/bin/env bash
set -eo pipefail
umask 022

marketplace_dir="$HOME/.local/share/Deoxys"
marketplace_url="https://github.com/spxix/Deoxys.git"
agy_bin="${AGY_BIN:-$HOME/.local/bin/agy}"

if [[ ! -x "$agy_bin" ]]; then
    echo "未找到可执行的 agy：$agy_bin" >&2
    exit 1
fi

# 1. 下载或更新本地 Deoxys 仓库（与 setup_cc 共用目录）
if [[ -d "$marketplace_dir/.git" ]]; then
    git -C "$marketplace_dir" pull --ff-only
else
    mkdir -p -- "$(dirname -- "$marketplace_dir")"
    git clone "$marketplace_url" "$marketplace_dir"
fi

# 2. 分别安装 14 个 Deoxys 插件
plugins=(
    service-foundation
    service-delivery
    ml-platform-ops
    service-observability
    integrations
    information
    domain-nanocc
    domain-abra
    obsidian
    project-closeout
    general
    harness-design
    ml-data-viewer
    autoresearch
)
for i in "${!plugins[@]}"; do
    printf '\n==> [%d/%d] 安装插件 %s\n' "$((i + 1))" "${#plugins[@]}" "${plugins[i]}"
    "$agy_bin" plugin install "$marketplace_dir/plugins/${plugins[i]}"
done
