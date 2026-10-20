# devbox-utils

Linux 开发环境实用工具：配置终端代理，以及安装、配置 Codex CLI。

## 目录

| 目录 | 用途 | 使用说明 |
| --- | --- | --- |
| `setup_proxy/` | 管理 Mihomo 代理、切换终端代理环境变量、检查网络连通性 | [终端代理](setup_proxy/README.md) |
| `setup_codex/` | 安装系统依赖、nvm、Node.js 24、Codex CLI 和 Deoxys 插件，应用本地配置 | [Codex 安装配置](setup_codex/README.md) |

两个工具可独立使用。如果安装 Codex 需要代理，先配置代理，再运行 Codex 安装脚本。

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

需要 Debian / Ubuntu 和 root 权限。先按 [Codex 说明](setup_codex/README.md) 准备 `setup_codex/auth.json`，并检查 `config.toml` 中的模型、服务地址和权限配置。

```bash
cd setup_codex
bash setup.sh
source ~/.bashrc
codex
```

安装脚本会提示确认代理已开启，并覆盖 `${CODEX_HOME:-$HOME/.codex}` 中的认证和配置文件。

## 本地文件与目录迁移

`setup_codex/auth.json`、`setup_proxy/vless.txt` 和 `setup_proxy/.proxy/` 是本机认证、节点及运行数据，不是通用示例配置。当前机器已有的这些文件随工具目录一起保留；在其他机器使用时需自行准备。

如果此前已经使用代理工具，移动目录后，已有 `~/.bashrc` 中的 `source` 路径可能仍指向旧目录，需要改为新位置。当前终端可直接 `source ./setup_proxy/proxy.sh` 加载新路径下的命令。运行中的 Mihomo 进程记录也可能保留旧路径；迁移目录不会自动重启代理或修复这些运行记录。
