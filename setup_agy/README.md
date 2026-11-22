# Antigravity CLI 安装

在 Linux 上安装 Google Antigravity CLI（命令为 `agy`），沿用 `../setup_codex/`
的 root / 普通用户双入口。通过[官方安装器](https://antigravity.google/cli/install.sh)
下载原生二进制，不需要 nvm、Node.js 或 npm。

本目录只负责安装 CLI，不预置登录凭据，不复制账号配置，也不安装插件或更改权限策略。
首次运行时由实际使用者完成登录。

## 文件说明

- `setup-root.sh`：Debian / Ubuntu root 入口，先安装系统依赖。
- `setup-user.sh`：普通用户入口，要求系统依赖已安装，不使用 sudo。

两个脚本各自独立执行安装流程。

## 安装前准备

需要 Linux x86_64 或 ARM64、Bash，以及已开启的代理。脚本会继承当前终端的
代理环境变量，安装前要求按回车确认代理可用；没有交互终端时取消安装。

普通用户安装前，由管理员准备以下系统依赖（Debian / Ubuntu）：

```bash
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl coreutils tar gzip grep sed
```

请使用实际运行 `agy` 的用户安装。二进制位于该用户的 `~/.local/bin/agy`；root
入口同样安装到 root 自己的用户目录，不是为所有用户进行全局安装。普通用户已有
系统依赖时，直接运行 `setup-user.sh` 即可。

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

## 配置与数据目录

默认 CLI 设置保存在 `~/.gemini/antigravity-cli/settings.json`，共享配置保存在
`~/.gemini/config/`，详见[官方配置说明](https://antigravity.google/docs/settings?tab=cli)。
安装脚本沿用默认目录，不创建配置模板，也不迁移已有数据。

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

当前官方安装器检测到 `~/.local/bin/agy` 已存在时会跳过下载，日常更新由 CLI
自身处理。本脚本仍会验证版本并检查 shell PATH。版本检查不验证账号或模型服务
连通性；已有二进制无法执行时会报错，不会自动删除它或重置用户数据。

只检查脚本语法，不执行安装：

```bash
bash -n setup-root.sh
bash -n setup-user.sh
```

安装完成后可直接执行 `~/.local/bin/agy --version` 验证二进制。

官方参考：[CLI 入门](https://antigravity.google/docs/getting-started?tab=cli)。
