# Claude Code 安装配置

参考 `../setup_codex/` 的普通用户安装流程，在 Debian / Ubuntu 上通过 nvm、Node.js 24 和 npm 安装 Claude Code，并应用本地配置和 Deoxys 插件。

## 安装前准备

管理员需提前安装 `ca-certificates curl git xz-utils tar`。使用自己的 Linux 用户执行脚本，不需要 sudo；默认使用该用户的 `~/.nvm`。

本目录的 `settings.json` 是本机配置，包含认证信息，已加入 `.gitignore`。需要提供新的认证配置时创建该文件；使用已有配置或终端环境变量时，可以不创建、留空或填写 `{}`：

```bash
cp settings.example.json settings.json
chmod 600 settings.json
```

编辑 `settings.json`，将 `ANTHROPIC_BASE_URL` 和 `ANTHROPIC_AUTH_TOKEN` 替换为实际服务地址和令牌。已有配置时不要用示例覆盖。脚本原样复制配置，不额外关闭权限审批。 `CLAUDE_CODE_ATTRIBUTION_HEADER` 必须设置为字符串 `"1"`，否则当前服务配置无法正常使用。

## 安装与启动

先开启当前终端的代理，再在本目录执行：

```bash
bash setup-user.sh
source ~/.bashrc
claude
```

脚本会要求按回车确认代理可用，没有交互终端时取消安装。它会安装或更新 nvm、Node.js 24、Claude Code，向 `~/.bashrc` 补充 nvm 初始化行（按整行文本去重，已有等价写法仍可能重复），仅在本目录 `settings.json` 为非空 JSON 对象时**覆盖** `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json`。文件缺失、只有空白或为 `{}` 时跳过复制；非法 JSON 会报错停止。请先自行备份目标目录中的个性化配置。

配置目录权限为 `700`，复制的配置文件为 `600`。随后用普通 Git 将 Deoxys 克隆到 `~/.local/share/Deoxys`（已有仓库时执行 `git pull --ff-only`），沿用当前终端的 Git 认证环境，再让 Claude 注册本地市场。已有同名市场会先移除注册，再注册为本地来源。

脚本会在 `~/.bashrc` 末尾追加新的 `claude` 函数覆盖旧定义，并清除同名别名；重复安装不会重复追加。函数保留原有 Google HTTP 响应检查，通过后用 `command claude "$@"` 启动 nvm 的 PATH 中的版本，不再写死 root 的二进制路径。该检查只检查响应首行是否包含 `200`，不保证模型服务可用。安装后执行 `source ~/.bashrc`，使当前终端生效。

最后安装与 `setup_codex` 相同的 14 个插件（user scope）；插件命令可能更新目标 settings.json。重复运行会按上述条件复制配置、更新本地市场并执行插件安装。跳过复制不会删除目标文件中已有的认证设置；插件安装仍可能更新目标文件中的插件配置。如果本地仓库有分叉、origin 不匹配，或目标路径被其他文件占用，脚本会报错停止，不会强制覆盖仓库。

自定义目录时，在安装和启动时使用同一环境变量：

```bash
export CLAUDE_CONFIG_DIR=/path/to/claude-config
bash setup-user.sh
source ~/.bashrc
claude
```

新终端需重新设置 `CLAUDE_CONFIG_DIR`，脚本不会将它写入 Bash 配置。可以用 `NVM_DIR` 指定自己可写的 nvm 目录。

## 检查

不执行安装的本地检查：

```bash
bash -n setup-user.sh
python3 -c 'import json; json.load(open("settings.example.json"))'
```

本地 `settings.json` 允许缺失或留空，不应无条件用 JSON 解析器检查它；安装脚本会检查其非空内容是否为 JSON 对象。

安装后执行 `claude --version` 检查 CLI。此检查不验证模型服务认证和连通性；首次运行 `claude` 时按实际提示完成初始化。

安装命令参考 [Claude Code 官方安装文档](https://code.claude.com/docs/en/setup)。不要提交或输出本地 `settings.json` 中的令牌。
