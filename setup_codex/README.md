# Codex 安装配置

在 Debian / Ubuntu 上安装 Codex CLI，并应用本目录的配置和 Deoxys 插件。

## 文件说明

- `setup-root.sh`：root 版本，包含系统依赖安装。
- `setup-user.sh`：普通用户版本，要求系统依赖已安装。
- `config.toml`：安装时复制的配置模板，包含模型、权限和终端设置。
- `AGENTS.md`：贡献与维护指南。

登录凭据由 Codex 登录流程管理并自动刷新。登录后，缓存可能保存在系统凭据存储或
`${CODEX_HOME}/auth.json`；它不是安装输入文件，不应提交或分享。

## 安装前准备

两种脚本都需要 Bash 和网络；脚本会继承当前终端的代理环境变量。根据实际运行
Codex 的用户选择 `setup-root.sh`（root）或 `setup-user.sh`（普通用户，依赖已安装）。
请使用实际运行 Codex 的用户安装，以保持 nvm、配置目录权限和登录凭据一致。

两个脚本默认将配置和插件安装到 `/SPXvePFS/users/wndai/.codex`；已有的非空
`CODEX_HOME` 环境变量优先。安装用户需要有目标目录的写权限。脚本不会自动迁移
原 `~/.codex` 中的登录缓存、历史记录或其他数据。

安装脚本会将选定目录写入 `~/.bashrc` 的 `export CODEX_HOME=...`。安装后执行
`source ~/.bashrc`，或打开新的 Bash 终端，即可直接输入 `codex` 使用该目录。
重复安装不会重复追加该设置；更换目录后会更新脚本管理的设置行。

当前模板默认使用 Codex 内置的 `openai` provider 和 `gpt-6-astra`，并开启 Full
Access、禁用命令审批：

```toml
sandbox_mode = "danger-full-access"
approval_policy = "never"
```

## 安装、登录与启动

在本目录执行对应脚本：

```bash
bash setup-root.sh       # root，安装系统依赖
# 或
bash setup-user.sh       # 普通用户，不安装系统依赖
source ~/.bashrc
codex login
codex login status
codex
```

远程服务器没有浏览器时，在服务器上执行设备授权登录：

```bash
codex login --device-auth
```

命令显示网址和一次性验证码后，在其他设备的浏览器中完成 ChatGPT 账号登录。
登录和启动时必须使用同一个 `CODEX_HOME`。安装脚本不会自动执行登录，也不会覆盖
目标目录中已有的登录缓存；重复运行脚本只更新 `config.toml`、CLI 和插件。

安装操作开始前，脚本会提示开启代理。请确认当前终端的代理可用后按回车继续；否则
按 Ctrl+C 退出。此步骤为人工确认，不会自动检测代理连通性；没有交互终端时会取消安装。

脚本也会向 `~/.bashrc` 追加 `codex` 包装函数，并清除同名别名；重复安装不会重复
追加。加载 `.bashrc` 后，每次执行 `codex`（包括登录和版本检查）都先进行与
`setup_cc` 相同的 Google HTTP 响应检查，最多等待 5 秒。检查失败时提示
“VPN 未生效，不能使用 codex”并返回非零状态，通过后用 `command codex "$@"`
启动 PATH 中的 CLI。该检查只判断响应首行是否包含 `200`，不直接检测 VPN 进程，
也不保证模型服务可用；直接调用二进制或未加载 `.bashrc` 的 shell 不经过此检查。

如需指定配置目录，在安装和后续登录、启动时使用同一个 `CODEX_HOME`：

```bash
export CODEX_HOME=/path/to/codex-config
bash setup-root.sh  # 或 bash setup-user.sh
source ~/.bashrc
codex login
codex
```

安装脚本也会把自定义目录保存到 `.bashrc`。对于不加载 `.bashrc` 的环境（如定时
任务或其他 shell），仍需显式设置同一个 `CODEX_HOME`。

## 修改配置与检查

本目录的 `config.toml` 是安装模板；修改它不会自动更新已经安装的配置。重新运行
安装脚本会再次安装或更新 CLI 和插件，并覆盖目标配置，但会保留 Codex 登录缓存。

仅检查脚本语法，无需实际安装：

```bash
bash -n setup-root.sh setup-user.sh
```

使用 Python 3.11 或更高版本检查 TOML：

```bash
python3 -c 'import tomllib; tomllib.load(open("config.toml", "rb"))'
```
