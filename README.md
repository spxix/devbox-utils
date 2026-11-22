# devbox-utils

Linux 开发环境实用工具：配置终端代理，以及安装 Codex CLI、Claude Code 和 Antigravity CLI（含桌面端 SSH 远端支持）。

## 目录

| 目录 | 用途 | 使用说明 |
| --- | --- | --- |
| `setup_proxy/` | 管理 Mihomo 代理、切换终端代理环境变量、检查网络连通性 | [终端代理](setup_proxy/README.md) |
| `setup_codex/` | 通过 root 或普通用户脚本安装 nvm、Node.js 24、Codex CLI 和 Deoxys 插件，应用本地配置 | [Codex 安装配置](setup_codex/README.md) |
| `setup_cc/` | 通过普通用户脚本安装 nvm、Node.js 24、Claude Code 和 Deoxys 插件，可选应用本地配置 | [Claude Code 安装配置](setup_cc/README.md) |
| `setup_agy/` | 通过 root 或普通用户脚本安装 Antigravity CLI（`agy`）并配置桌面端 SSH 远端服务，不预置登录凭据 | [Antigravity 安装说明](setup_agy/README.md) |

四个工具可独立使用。如果安装 CLI 需要代理，先配置代理，再选择对应的安装脚本。

## 使用顺序

以下命令从 `devbox-utils` 目录开始执行。

### 1. 配置终端代理

需要 Linux x86_64、Python 3.8+、Bash 和 curl。在 `setup_proxy/vless.txt` 中准备 VLESS 节点链接；Mihomo 二进制的准备方式见[代理说明](setup_proxy/README.md)。

```bash
cd setup_proxy
python3 mihomo.py start
source ./proxy.sh
proxyon
python3 mihomo.py test
cd ..
```

`start` 启动后台服务并安装 Bash 命令加载提示；`proxyon` 只开启当前终端及其后续子进程的代理。关闭当前终端代理使用 `proxyoff`，停止后台服务使用 `python3 mihomo.py stop`（在 `setup_proxy` 目录执行）。

### 2. 安装 Codex

需要 Debian / Ubuntu。先阅读 [Codex 说明](setup_codex/README.md)，确认实际运行
Codex 的用户和 `CODEX_HOME`。依赖尚未安装时使用 root 脚本；依赖已由管理员准备好时
使用普通用户脚本。

```bash
cd setup_codex
bash setup-root.sh       # root，安装系统依赖
# 或
bash setup-user.sh       # 普通用户，不安装系统依赖
source ~/.bashrc
codex login
codex
```

安装脚本会提示确认代理已开启，并只更新 `${CODEX_HOME:-/SPXvePFS/users/wndai/.codex}` 中的配置文件。
已有的非空 `CODEX_HOME` 优先；脚本会将选定目录保存到 `~/.bashrc`，加载后直接运行
`codex` 即使用该目录。脚本不会自动迁移原 `~/.codex` 的数据。
安装完成后由实际运行用户执行 `codex login`；远程服务器可执行
`codex login --device-auth`。登录和启动时保持同一个 `CODEX_HOME`。Codex 可能自动生成
`auth.json` 登录缓存，请勿提交或分享。

安装会向 `.bashrc` 追加与 Claude Code 相同的代理检查包装函数；加载后执行
`codex` 会先检查 Google HTTP 响应，检查失败时阻止启动。

### 3. 安装 Claude Code（按需选择）

需要 Debian / Ubuntu，且管理员已安装系统依赖。按 [Claude Code 说明](setup_cc/README.md) 准备认证：可以沿用终端环境变量或目标目录的已有配置，也可以从 `settings.example.json` 创建本地 `settings.json`。

以下命令从仓库根目录执行，不要求先安装 Codex：

```bash
cd setup_cc
bash setup-user.sh
source ~/.bashrc
claude
```

本地 `settings.json` 缺失、空白或为 `{}` 时保留目标配置；非空 JSON 对象会覆盖 `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json`，不是合并。脚本使用普通 Git 下载或更新 `~/.local/share/Deoxys`，再注册为 Claude 的本地插件市场。安装会在 `.bashrc` 中追加带代理检查的 Claude 包装函数，通过 PATH 调用 CLI。

### 4. 安装 Antigravity CLI 与桌面端 SSH 远端支持（按需选择）

需要 Linux x86_64 或 ARM64（glibc 2.26+），安装原生 `agy` 二进制并预置桌面端
`~/.antigravity-hub-server`，不依赖 Node.js，无需准备配置文件或登录凭据。
以下命令从仓库根目录执行：

```bash
cd setup_agy
bash setup-user.sh       # 普通用户，系统依赖已准备好
# 或
bash setup-root.sh       # Debian / Ubuntu root，包含系统依赖安装
source ~/.bashrc
agy --version
agy
```

使用实际运行 CLI 或供桌面端 SSH 登录的用户安装。脚本会提示确认代理已开启，安装
`~/.local/bin/agy`，向 `.bashrc` 末尾追加 CLI 代理检查包装函数，并在 `.bashrc`
顶部写入仅针对 Antigravity SSH 引导与环境解析生效的静默代理钩子（不影响日常交互
终端默认直连），同时预下载当前稳定版 Hub Server 二进制。仅需配置桌面端 SSH 远端
环境时可直接运行 `bash setup_agy/setup-ssh-server.sh`。详见
[Antigravity 安装说明](setup_agy/README.md)。

## 本地文件与目录迁移

`setup_codex/auth.json`、`setup_cc/settings.json`、`setup_proxy/vless.txt` 和 `setup_proxy/.proxy/` 是本机认证、节点及运行数据。`auth.json` 由 Codex 登录流程自动生成，可能改为保存在系统凭据存储中；不要提交或分享这些文件。在其他机器使用时需重新完成登录并自行准备其他本机配置。

如果此前已经使用代理工具，移动目录后，已有 `~/.bashrc` 中的 `source` 路径可能仍指向旧目录，需要改为新位置。当前终端可直接 `source ./setup_proxy/proxy.sh` 加载新路径下的命令。运行中的 Mihomo 进程记录也可能保留旧路径；迁移目录不会自动重启代理或修复这些运行记录。
