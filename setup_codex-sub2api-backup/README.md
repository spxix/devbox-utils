# Codex 安装配置（已废弃 / Sub2API 历史备份）

> [!WARNING]
> **本目录已废弃，不再维护。**
> 这里保留的是旧版通过 Sub2API / API Key（`auth.json`）配置 Codex CLI 的历史备份。
> 当前请改用 [`../setup_codex/`](../setup_codex/README.md)（基于 ChatGPT 账号登录、内置 `openai` provider，并包含 `CODEX_HOME` 持久化与代理检查包装函数）。

在 Debian / Ubuntu 上安装 Codex CLI，并应用本目录的旧版配置和 Deoxys 插件（仅作历史参考）。

## 文件说明

- `setup-root.sh`：root 版本，包含系统依赖安装。
- `setup-user.sh`：普通用户版本，要求系统依赖已安装。
- `config.toml`：安装时使用的配置模板，可修改模型、服务地址、权限和终端设置。
- `auth.example.json`：仅含占位密钥的认证示例，可复制为 `auth.json` 后填写。
- `auth.json`：自行创建的认证文件，已通过 `.gitignore` 忽略，不应提交。
- `AGENTS.md`：贡献与维护指南。

## 安装前准备

两种脚本都需要 Bash 和网络；脚本会继承当前终端的代理环境变量。根据权限选择 `setup-root.sh`（root）或 `setup-user.sh`（普通用户，依赖已安装）。

1. 进入本项目目录。
2. 从示例创建 `auth.json`，再将 `YOUR_API_KEY` 替换为所用模型服务的 API Key。已有认证文件时不要覆盖：

   ```bash
   cp -n auth.example.json auth.json
   chmod 600 auth.json
   ```

3. 检查 `config.toml` 中的 `model`、`review_model` 和 `[model_providers.OpenAI]` 下的 `base_url`。当前模板指向第三方服务；请按实际服务修改地址和模型，并使用对应的 Key。

当前模板默认开启 **Full Access**，禁用沙箱和命令审批：

```toml
sandbox_mode = "danger-full-access"
approval_policy = "never"
```

这两项位于文件顶层，应写在第一个 `[配置段]` 之前。

## 安装与启动

在项目目录执行对应脚本：

```bash
bash setup-root.sh       # root，安装系统依赖
# 或
bash setup-user.sh       # 普通用户，不安装系统依赖
source ~/.bashrc
codex
```

脚本会配置 Bash 的 nvm 初始化，并将配置文件覆盖复制到 `${CODEX_HOME:-$HOME/.codex}`；请用运行 Codex 的用户执行。

安装操作开始前，脚本会提示开启代理。请确认当前终端的代理可用后按回车继续；否则按 Ctrl+C 退出。此步骤为人工确认，不会自动检测代理连通性；没有交互终端时会取消安装。

如需指定配置目录，在安装和后续启动时使用同一个 `CODEX_HOME`：

```bash
export CODEX_HOME=/path/to/codex-config
bash setup-root.sh  # 或 bash setup-user.sh
source ~/.bashrc
codex
```

新终端也需要设置这个环境变量。脚本不会自动保存自定义 `CODEX_HOME`。

## 修改配置与检查

本目录的 `config.toml` 是安装模板；修改它不会自动更新已经安装的配置。重新运行安装脚本会再次安装/更新 CLI 和插件，并覆盖目标配置。

仅检查脚本语法，无需实际安装：

```bash
bash -n setup-root.sh setup-user.sh
```

使用 Python 3.11 或更高版本检查 TOML：

```bash
python3 -c 'import tomllib; tomllib.load(open("config.toml", "rb"))'
```

不要在日志、提交或问题描述中包含 API Key。`.gitignore` 不会取消对已被 Git 跟踪文件的跟踪；若曾提交 `auth.json`，需另行移除跟踪，并更换已泄露的 Key。
