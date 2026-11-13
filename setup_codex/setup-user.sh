#!/usr/bin/env bash
set -eo pipefail
umask 022

# 1. 检查运行用户和配置文件
# if [[ "$(id -u)" != 0 ]]; then
#     echo "请以 root 用户执行。" >&2
#     exit 1
# fi

script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
config_dir="${CODEX_HOME:-/SPXvePFS/users/wndai/.codex}"
nvm_version="v0.40.8"
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

for file in config.toml; do
    if [[ ! -f "$script_dir/$file" || ! -r "$script_dir/$file" ]]; then
        echo "缺少或无法读取：$script_dir/$file" >&2
        exit 1
    fi
done

# 安装前确认代理已开启
echo "运行前请先开启代理，并确保当前终端已配置代理环境变量。"
echo "确认代理可用后，按回车继续安装；未开启请按 Ctrl+C 退出。"
if ! read -r -p "已开启代理，按回车继续：" </dev/tty; then
    echo "未收到代理确认，已取消安装。" >&2
    exit 1
fi

temp_dir="$(mktemp -d)"
trap 'rm -rf -- "$temp_dir"' EXIT

# 2. 安装系统依赖；不用 apt 安装旧版 Node.js
# user 没有权限执行 apt-get install，而且这些一般已经装好了，没装好的话只能在root下安装

# echo "==> 安装系统依赖"
# apt-get update
# DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
#     ca-certificates curl git xz-utils bubblewrap

# 3. 使用官方安装脚本，通过 Git 安装 nvm；继承当前终端的代理设置
# user home 下默认没有 .nvm/ 目录，如果不指定 NVM_DIR 的话就在 user home 下安装，当然也可以指定 root home 的 NVM_DIR

if [[ ! -s "$NVM_DIR/nvm.sh" || ! -x "$NVM_DIR/nvm-exec" ||
      ! -s "$NVM_DIR/bash_completion" ]] || ! bash -n "$NVM_DIR/nvm.sh"; then
    echo "==> 安装 nvm"
    curl -fSL --retry 5 --retry-all-errors --connect-timeout 20 --max-time 180 \
        "https://raw.githubusercontent.com/nvm-sh/nvm/$nvm_version/install.sh" \
        -o "$temp_dir/install-nvm.sh"
    METHOD=git PROFILE=/dev/null bash "$temp_dir/install-nvm.sh"
fi

# 4. 安装并启用 Node.js 24；显式检查退出码，兼容 nvm
echo "==> 安装并启用 Node.js 24"
. "$NVM_DIR/nvm.sh" --no-use || exit 1
nvm install -b 24 || exit 1
nvm use 24 || exit 1
nvm alias default 24 || exit 1
hash -r

# 5. 安装 Codex；二进制包下载可能较慢，请等待 npm 输出完成信息
echo "==> 安装 Codex，正在获取平台二进制包，请耐心等待"
npm install -g @openai/codex@latest --bin-links=true --loglevel=info
hash -r

# 6. 添加 nvm 和 CODEX_HOME 的 Bash 初始化配置，避免重复追加
touch "$HOME/.bashrc"

nvm_path_line="$(printf 'export NVM_DIR=%q' "$NVM_DIR")"
nvm_load_line='[ ! -s "$NVM_DIR/nvm.sh" ] || . "$NVM_DIR/nvm.sh"'
for line in "$nvm_path_line" "$nvm_load_line"; do
    grep -Fqx -- "$line" "$HOME/.bashrc" || printf '\n%s\n' "$line" >> "$HOME/.bashrc"
done

codex_home_line="$(printf 'export CODEX_HOME=%q # setup_codex' "$config_dir")"
if ! grep -Fqx -- "$codex_home_line" "$HOME/.bashrc"; then
    sed '/^export CODEX_HOME=.* # setup_codex$/d' "$HOME/.bashrc" > "$temp_dir/bashrc"
    printf '\n%s\n' "$codex_home_line" >> "$temp_dir/bashrc"
    cat -- "$temp_dir/bashrc" > "$HOME/.bashrc"
fi

# 7. 复制配置，覆盖同名文件；权限设为仅当前用户可读写
echo "==> 复制 Codex 配置"
mkdir -p -- "$config_dir"
chmod 700 -- "$config_dir"
for file in config.toml; do
    if [[ ! "$script_dir/$file" -ef "$config_dir/$file" ]]; then
        install -m 600 -- "$script_dir/$file" "$config_dir/$file"
    fi
    chmod 600 -- "$config_dir/$file"
done

# 8. 验证安装，并添加 Deoxys 插件市场
echo "==> 验证安装"
node --version
npm --version
CODEX_HOME="$config_dir" codex --version
bwrap --version

echo "==> 添加 Deoxys 插件市场"
CODEX_HOME="$config_dir" codex plugin marketplace remove deoxys || true
CODEX_HOME="$config_dir" codex plugin marketplace add spxix/Deoxys

plugins=(
    service-foundation@deoxys
    service-delivery@deoxys
    ml-platform-ops@deoxys
    service-observability@deoxys
    integrations@deoxys
    information@deoxys
    domain-nanocc@deoxys
    domain-abra@deoxys
    obsidian@deoxys
    project-closeout@deoxys
    general@deoxys
    harness-design@deoxys
    ml-data-viewer@deoxys
    autoresearch@deoxys
)
for i in "${!plugins[@]}"; do
    printf '\n==> [%d/%d] 安装插件 %s\n' "$((i + 1))" "${#plugins[@]}" "${plugins[i]}"
    CODEX_HOME="$config_dir" codex plugin add "${plugins[i]}"
done

printf '\n安装完成。请在实际运行 Codex 的用户当前终端执行：\n'
printf '  source %q\n' "$HOME/.bashrc"
printf '然后登录 ChatGPT 订阅账号：\n  codex login\n'
printf '远程服务器可使用设备授权：\n  codex login --device-auth\n'
printf '登录状态检查：\n  codex login status\n'
printf '登录后启动：\n  codex\n'
