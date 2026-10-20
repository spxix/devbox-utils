#!/usr/bin/env bash
set -eo pipefail
umask 077

# 1. 检查运行用户和配置文件
script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
export CLAUDE_CONFIG_DIR="$config_dir"
nvm_version="v0.40.8"
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

# 安装前确认代理已开启
echo "运行前请先开启代理，并确保当前终端已配置代理环境变量。"
echo "确认代理可用后，按回车继续安装；未开启请按 Ctrl+C 退出。"
if ! read -r -p "已开启代理，按回车继续：" </dev/tty; then
    echo "未收到代理确认，已取消安装。" >&2
    exit 1
fi

temp_dir="$(mktemp -d)"
trap 'rm -rf -- "$temp_dir"' EXIT

# 2. 检查系统依赖；普通用户不执行 apt-get
for command in curl git xz tar; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "缺少依赖：$command。请管理员安装 ca-certificates curl git xz-utils tar。" >&2
        exit 1
    fi
done

# 3. 安装 nvm；继承当前终端的代理设置
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

# 5. 安装 Claude Code；二进制包下载可能较慢，请等待 npm 输出完成信息
echo "==> 安装 Claude Code，正在获取平台二进制包，请耐心等待"
npm install -g @anthropic-ai/claude-code@latest --bin-links=true --loglevel=info
hash -r

# 安装配置前验证 JSON，不输出可能含认证信息的文件内容
copy_settings="$(node -e '
try {
    const fs = require("fs");
    let contents;
    try {
        contents = fs.readFileSync(process.argv[1], "utf8").trim();
    } catch (error) {
        if (error.code !== "ENOENT") throw error;
    }
    if (!contents) {
        console.log("no");
        process.exit(0);
    }
    const settings = JSON.parse(contents);
    if (!settings || typeof settings !== "object" || Array.isArray(settings)) throw new Error();
    console.log(Object.keys(settings).length ? "yes" : "no");
} catch (_) {
    console.error("无法读取 settings.json，或内容不是有效的 JSON 对象。");
    process.exit(1);
}
' "$script_dir/settings.json")"

# 6. 添加 nvm 的 Bash 初始化配置，避免重复追加
touch "$HOME/.bashrc"

nvm_path_line="$(printf 'export NVM_DIR=%q' "$NVM_DIR")"
nvm_load_line='[ ! -s "$NVM_DIR/nvm.sh" ] || . "$NVM_DIR/nvm.sh"'
for line in "$nvm_path_line" "$nvm_load_line"; do
    grep -Fqx -- "$line" "$HOME/.bashrc" || printf '\n%s\n' "$line" >> "$HOME/.bashrc"
done

# 追加同名函数覆盖旧定义，保留代理检查，通过 PATH 启动当前版本。
if ! grep -Fqx '# setup_cc: Claude CLI VPN wrapper' "$HOME/.bashrc"; then
    cat >> "$HOME/.bashrc" <<'BASHRC'

# setup_cc: Claude CLI VPN wrapper
unalias claude 2>/dev/null || true
claude() {
    if curl -sI --max-time 5 www.google.com 2>/dev/null | head -1 | grep -q "200"; then
        command claude "$@"
    else
        echo -e "\033[31mVPN 未生效，不能使用 claude\033[0m" >&2
        return 1
    fi
}
BASHRC
fi

# 7. 仅复制用户提供的非空配置；否则保留目标配置和环境变量。
mkdir -p -- "$config_dir"
chmod 700 -- "$config_dir"
if [[ "$copy_settings" == yes ]]; then
    echo "==> 复制 Claude Code 配置"
    if [[ ! "$script_dir/settings.json" -ef "$config_dir/settings.json" ]]; then
        install -m 600 -- "$script_dir/settings.json" "$config_dir/settings.json"
    fi
    chmod 600 -- "$config_dir/settings.json"
else
    echo "==> 未提供非空 settings.json，保留现有配置"
fi

# 8. 验证安装，并添加 Deoxys 插件市场
echo "==> 验证安装"
node --version
npm --version
claude --version

echo "==> 下载或更新本地 Deoxys 插件市场"
marketplace_dir="$HOME/.local/share/Deoxys"
marketplace_url="https://github.com/spxix/Deoxys.git"
if [[ -d "$marketplace_dir/.git" ]]; then
    if [[ "$(git -C "$marketplace_dir" remote get-url origin)" != "$marketplace_url" ]]; then
        echo "本地 Deoxys 仓库的 origin 与预期不一致，请检查：$marketplace_dir" >&2
        exit 1
    fi
    git -C "$marketplace_dir" pull --ff-only
elif [[ -e "$marketplace_dir" ]]; then
    echo "目标路径已存在且不是 Git 仓库，请检查：$marketplace_dir" >&2
    exit 1
else
    mkdir -p -- "$(dirname -- "$marketplace_dir")"
    git clone "$marketplace_url" "$marketplace_dir"
fi

# 使用普通 Git 的认证环境下载，再注册本地目录，避免 Claude 下载时清空 GIT_ASKPASS。
echo "==> 注册本地 Deoxys 插件市场"
claude plugin marketplace list --json > "$temp_dir/marketplaces.json"
if node -e '
    const markets = require(process.argv[1]);
    process.exit(markets.some(market => market.name === "deoxys") ? 0 : 1);
' "$temp_dir/marketplaces.json"; then
    claude plugin marketplace remove deoxys
fi
claude plugin marketplace add "$marketplace_dir"

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
    claude plugin install "${plugins[i]}" --scope user
done

printf '\n安装完成。当前终端执行：\n  source %q\n' "$HOME/.bashrc"
printf '然后启动：\n  CLAUDE_CONFIG_DIR=%q claude\n' "$config_dir"
