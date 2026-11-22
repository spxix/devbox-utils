#!/usr/bin/env bash
set -eo pipefail
umask 022

# 1. 检查系统依赖；普通用户无需 sudo
for dependency in curl tar gzip sha512sum grep sed mktemp; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
        echo "缺少系统依赖：$dependency，请由管理员安装后重试。" >&2
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
binary_path="$HOME/.local/bin/agy"

# 2. 下载并执行官方安装器，不需要 Node.js
echo "==> 下载 Antigravity CLI 官方安装脚本"
curl -fSL --retry 5 --retry-all-errors --connect-timeout 20 --max-time 180 \
    "https://antigravity.google/cli/install.sh" \
    -o "$temp_dir/install-agy.sh"
bash -n "$temp_dir/install-agy.sh"

echo "==> 安装 Antigravity CLI，正在获取平台二进制包，请耐心等待"
bash "$temp_dir/install-agy.sh"

# 3. 验证安装，不启动登录
echo "==> 验证安装"
if [[ ! -x "$binary_path" ]]; then
    echo "未找到可执行文件：$binary_path" >&2
    exit 1
fi
if ! "$binary_path" --version; then
    echo "Antigravity CLI 版本检查失败，请检查上方错误。" >&2
    exit 1
fi

# 4. 由 CLI 管理 shell 配置；已有二进制时官方安装器会提前返回
echo "==> 检查 shell 命令路径"
"$binary_path" install --skip-aliases

# 追加启动函数，沿用 setup_cc 的代理检查，避免重复追加。
touch "$HOME/.bashrc"
if ! grep -Fqx '# setup_agy: Antigravity CLI VPN wrapper' "$HOME/.bashrc"; then
    cat >> "$HOME/.bashrc" <<'BASHRC'

# setup_agy: Antigravity CLI VPN wrapper
unalias agy 2>/dev/null || true
agy() {
    if curl -sI --max-time 5 www.google.com 2>/dev/null | head -1 | grep -q "200"; then
        command agy "$@"
    else
        echo -e "\033[31mVPN 未生效，不能使用 agy\033[0m" >&2
        return 1
    fi
}
BASHRC
fi

printf '\n安装完成。请在实际运行 Antigravity CLI 的用户当前终端执行：\n'
printf '  source %q\n' "$HOME/.bashrc"
printf '  agy --version\n'
printf '然后进入项目目录并运行 agy，按提示完成首次登录。\n'
