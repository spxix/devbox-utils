# Antigravity CLI 与 SSH 远端安装

在 Linux 上安装 Google Antigravity CLI（命令为 `agy`），并同时完成 Antigravity
桌面端 **Connect to SSH Host** 所需的远端代理环境与 `~/.antigravity-hub-server`
预安装。沿用 `../setup_codex/` 的 root / 普通用户双入口，通过
[官方安装器](https://antigravity.google/cli/install.sh) 和官方发布源获取原生二进制，
不需要 nvm、Node.js 或 npm。

本目录负责安装 CLI、SSH Hub Server 运行环境以及 Deoxys 插件集合，不预置登录凭据、
不复制账号配置，也不更改权限策略。首次使用时由实际使用者完成登录。

## 文件说明

- `setup-root.sh`：Debian / Ubuntu root 入口，安装系统依赖、CLI、SSH 远端环境及 Deoxys 插件。
- `setup-user.sh`：普通用户入口，要求系统依赖已安装，不使用 sudo。
- `setup-ssh-server.sh`：可独立运行的 SSH 远端配置脚本，负责写入 `~/.bashrc` 顶部
  SSH 代理钩子并预装 `~/.antigravity-hub-server`。
- `setup-plugins.sh`：可独立运行的 Deoxys 插件安装脚本，负责克隆或更新
  `~/.local/share/Deoxys`，并将与 `setup_codex` / `setup_cc` 一致的 14 个插件分别安装到
  `~/.gemini/config/plugins/`。

`setup-root.sh` 与 `setup-user.sh` 会自动调用 `setup-ssh-server.sh` 和 `setup-plugins.sh`；
仅需修复/升级 SSH 远端环境或同步 Deoxys 插件时，也可单独运行对应脚本。

## 安装前准备

需要 Linux x86_64 或 ARM64（glibc 2.26+）、Bash，以及已开启的代理。脚本会继承当前
终端的代理环境变量，安装前要求按回车确认代理可用；没有交互终端时取消安装。

普通用户安装前，由管理员准备以下系统依赖（Debian / Ubuntu）：

```bash
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl git coreutils tar gzip grep sed procps util-linux mawk
```

请使用实际运行 `agy` 或供桌面端 SSH 登录的用户执行安装。CLI 二进制位于该用户的
`~/.local/bin/agy`，SSH Hub Server 位于 `~/.antigravity-hub-server/`；root 入口
同样安装到 root 自己的用户目录，不是为所有用户进行全局安装。普通用户已有系统依赖时，
直接运行 `setup-user.sh` 即可。

## 安装与启动

从仓库根目录执行：

```bash
cd setup_agy
bash setup-user.sh       # 普通用户，系统依赖已准备好
# 或
bash setup-root.sh       # root，包含系统依赖安装
source ~/.bashrc
agy --version
```

常用可选参数：

```bash
bash setup-root.sh --hub-version 2.34.0     # 指定预安装的桌面端 Hub Server 版本
bash setup-root.sh --skip-hub-download      # 仅写 SSH 代理钩子，跳过 Hub Server 预下载
bash setup-root.sh --skip-plugins           # 跳过 Deoxys 插件安装
bash setup-ssh-server.sh --version 2.34.0   # 仅单独配置/更新桌面端 SSH 远端环境
bash setup-plugins.sh                       # 仅单独安装/更新 14 个 Deoxys 插件
```

### 1. CLI 安装与包装函数

安装器按平台选择发布包并校验 SHA-512，随后配置 shell 环境。版本验证通过后，
脚本还会调用 `agy install --skip-aliases` 检查命令路径，确保已有二进制时也能
补齐 shell 初始化。PATH 由官方 CLI 管理，会更新 `~/.bashrc` 等适用的 shell
配置文件；重复安装不会重复追加相同设置。官方安装器首次安装时可能清理已有的
`agy` / `antigravity` shell 别名。

脚本随后向 `~/.bashrc` 追加 `agy` 包装函数，并清除同名别名；重复安装不会重复
追加。加载 `.bashrc` 后，每次执行 `agy`（包括带参数的命令）都先进行与
`setup_cc` 相同的 Google HTTP 响应检查，最多等待 5 秒。检查失败时提示
“VPN 未生效，不能使用 agy”并返回非零状态，通过后用 `command agy "$@"` 启动
PATH 中的 CLI。该检查只判断响应首行是否包含 `200`，不直接检测 VPN 进程，
也不保证模型服务可用；直接调用二进制或未加载 `.bashrc` 的 shell 不经过此检查。

安装完成后，在项目目录中运行：

```bash
agy
```

按终端提示完成首次设置和 Google 账号登录。远程 SSH 环境按 CLI 提示，在本地
浏览器打开登录链接并回填授权码；不需要提前放置任何凭据文件。详见
[官方认证说明](https://antigravity.google/docs/install?tab=cli)。

### 2. Antigravity Desktop SSH 远端适配说明

桌面端连接 SSH 主机时执行非交互式 `ssh -T ... <host> sh -s` 拉取服务端二进制（约
200MB+），随后通过 `ANTIGRAVITY_RESOLVING_ENVIRONMENT=1` 启动交互式登录 Shell（限时
10 秒）抓取环境变量并启动常驻 `language_server`。在受限网络环境中：

- 非交互 `sh -s` 不会触发 `~/.bashrc` 交互区段，若直连 Google Cloud Storage 处于
  慢速状态（≥ 1 KB/s 但 15 分钟内无法下完），既不会触发本地上传回退（`NEED_UPLOAD`），
  又会在 15 分钟超时后清理 `.partial.*` 临时文件；
- 在 `~/.bashrc` 中直接调用带外部 IP 查询的 `proxyon` 可能超过 10 秒限时导致环境读取失败。

`setup-ssh-server.sh` 通过两步解决上述问题，且**不改变日常交互式 SSH 终端默认直连、
手动 `proxyon` / `proxyoff` 的行为**：

1. **`~/.bashrc` 顶部精准代理钩子**：在非交互退出守卫（如 `[ -z "$PS1" ] && return`）
   之前写入带起止标记的幂等代码块，仅在 `ANTIGRAVITY_RESOLVING_ENVIRONMENT=1`
   或 SSH 执行 `sh -s` 时静默导出代理变量（优先固化
   运行脚本时的当前终端代理地址，缺省回退 `127.0.0.1:7897` / `7898` 及内网绕过规则）。
   这样后续桌面端自动升级新版本时远端也能直接走代理秒级下载；若本机 Mihomo 未启动，
   本地端口立即拒绝连接并触发桌面端自带的本地回退上传。
2. **预拉取并校验当前版本 `language_server`**：查询官方发布列表（默认取最新稳定版，
   也可通过 `AGY_HUB_VERSION` 或 `--version` 指定与本地桌面端一致的版本），下载到
   `~/.antigravity-hub-server/bin/<version>-<arch>/language_server` 并校验 64 位 ELF
   文件头，实现首次连接零等待，同时兼容非 Bash 默认登录 Shell。

## 配置与数据目录

默认 CLI 设置保存在 `~/.gemini/antigravity-cli/settings.json`，共享配置保存在
`~/.gemini/config/`，详见[官方配置说明](https://antigravity.google/docs/settings?tab=cli)。
桌面端 SSH 常驻服务安装在 `~/.antigravity-hub-server/`，进程发现与多机共享租约文件位于
`~/.gemini/antigravity/daemon/`。若多个远程主机共享同一个 `$HOME`（如网络文件系统），
同一时刻只有一台主机运行该 `$HOME` 对应的常驻服务，切换主机连接时按桌面端提示接管即可。

需要类似 `CODEX_HOME` 的目录覆盖时，当前 CLI 提供 `--gemini_dir` 参数：

```bash
agy --gemini_dir=/SPXvePFS/users/wndai/.agy
```

该目录是数据根目录，其下使用 `antigravity-cli/` 保存 CLI 设置和运行数据，使用
`config/` 保存共享配置。首次登录及以后启动、管理 MCP 等操作需传入同一参数。
这不会改变二进制的安装位置，也不会自动迁移默认目录中的数据。

`--gemini_dir` 已用官方 `1.5.14` 二进制在隔离容器中验证；当前公开的 CLI 参数表
尚未列出它。未确认到可在所有 CLI 子命令中等价替代它的环境变量，不能直接套用
`AGY_HOME` 或 `ANTIGRAVITY_GEMINI_DIR`。登录缓存仍由官方登录流程和凭据存储管理。

## 重复运行与检查

- 官方 CLI 安装器检测到 `~/.local/bin/agy` 已存在时会跳过下载，日常更新由 CLI 自身处理。
- `setup-ssh-server.sh` 检测到目标版本的 `language_server` 已存在且通过 ELF 校验时同样
  跳过下载，并原地幂等刷新 `~/.bashrc` 顶部的代理钩子与清理死进程残留的 `.partial.*`。

只检查脚本语法，不执行安装：

```bash
bash -n setup-root.sh setup-user.sh setup-ssh-server.sh setup-plugins.sh
```

安装完成后可执行 `~/.local/bin/agy --version` 验证 CLI 二进制。

官方参考：[CLI 入门](https://antigravity.google/docs/getting-started?tab=cli)。
