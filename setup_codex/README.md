# Codex 安装配置

在 Debian / Ubuntu 上安装 Codex CLI，并应用本目录的配置和 Deoxys 插件。

## 文件说明

- `setup.sh`：安装系统依赖、nvm、Node.js 24、最新版 Codex CLI 和插件。
- `config.toml`：安装时使用的配置模板，可修改模型、服务地址、权限和终端设置。
- `auth.json`：自行创建的认证文件，已通过 `.gitignore` 忽略，不应提交。
- `AGENTS.md`：贡献与维护指南。

## 安装前准备

需要 root 用户、Bash、apt，以及访问系统软件源、GitHub、npm 和模型服务的网络。脚本会继承当前终端的代理环境变量。

1. 进入本项目目录。
2. 在 `setup.sh` 同级目录创建 `auth.json`，填入所用模型服务的真实 API Key：

   ```json
   {
     "OPENAI_API_KEY": "YOUR_API_KEY"
   }
   ```

   ```bash
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

以 root 用户在项目目录执行：

```bash
bash setup.sh
source ~/.bashrc
codex
```

脚本会安装依赖、配置 Bash 的 nvm 初始化，并将本目录的 `config.toml` 和 `auth.json` **覆盖复制**到 `${CODEX_HOME:-$HOME/.codex}`。如目标目录已有配置，请先备份。安装后的目录权限为 `700`，两个配置文件权限为 `600`。

安装操作开始前，脚本会提示开启代理。请确认当前终端的代理可用后按回车继续；否则按 Ctrl+C 退出。此步骤为人工确认，不会自动检测代理连通性；没有交互终端时会取消安装。

安装过程还会重新注册 `spxix/Deoxys` 插件市场，并安装 `setup.sh` 中 `plugins` 数组列出的插件。需要调整插件时，修改该数组。

如需指定配置目录，在安装和后续启动时使用同一个 `CODEX_HOME`：

```bash
export CODEX_HOME=/path/to/codex-config
bash setup.sh
source ~/.bashrc
codex
```

新终端也需要设置这个环境变量。脚本不会自动保存自定义 `CODEX_HOME`。

## 修改配置与检查

本目录的 `config.toml` 是安装模板；修改它不会自动更新已经安装的配置。重新运行安装脚本会再次安装/更新 CLI 和插件，并覆盖目标配置。

仅检查脚本语法，无需实际安装：

```bash
bash -n setup.sh
```

使用 Python 3.11 或更高版本检查 TOML：

```bash
python3 -c 'import tomllib; tomllib.load(open("config.toml", "rb"))'
```

不要在日志、提交或问题描述中包含 API Key。`.gitignore` 不会取消对已被 Git 跟踪文件的跟踪；若曾提交 `auth.json`，需另行移除跟踪，并更换已泄露的 Key。
