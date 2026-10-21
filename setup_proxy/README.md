# 终端代理

## 每次进入环境

例如：

```bash
export DEVBOX_UTILS_DIR=/path/to/devbox-utils
```

```bash
cd "$DEVBOX_UTILS_DIR/setup_proxy"
python3 mihomo.py start
```

脚本使用现有的 `.proxy/mihomo`，读取 `vless.txt` 并在后台启动代理。若本脚本管理的代理已经运行，重复执行不会再次启动。

新终端通过以下命令开启当前终端的代理：

```bash
proxyon
```

当前已打开的终端需先执行一次 `source "$DEVBOX_UTILS_DIR/setup_proxy/proxy.sh"`，再执行 `proxyon`。加载文件只定义命令，不自动启用代理；`proxyon` / `proxyoff` 仅影响当前终端及后续启动的程序，不启动或停止后台服务。

代理只监听本机 HTTP `7897` / SOCKS5 `7898`，供支持代理设置的程序使用；内网 IP 和配置中的公司域名直连，其余经过节点，不自动按国内外网站分流。

**文件持久化，进程不持久化。** 容器或机器重启后需要重新执行 `start`；仅重新打开终端时，后台服务可能仍在运行。

`proxyon` 会打印切换前的直连 IP 和切换后的代理 IP；`proxyoff` 会打印切换前的代理 IP 和切换后的直连 IP。查询失败显示 `n/a`，查询可能需要等待网络超时。

## 新终端显示代理提示

`python3 mihomo.py start` 成功后自动向当前用户的 `$HOME/.bashrc` 安装命令加载配置和提示。代理已经运行时也会补上配置，重复执行不会重复添加，并会升级旧提示。

新开交互式 Bash 终端会显示：

```text
当前终端代理： 开启 proxyon / 关闭 proxyoff
```

提示不会自动启用代理或启动服务。若要将提示写入其他文件：

```bash
python3 mihomo.py start --bashrc $HOME/.bashrc
```

## 查看状态与测试

```bash
python3 mihomo.py status
python3 mihomo.py test
```

`test` 需要 curl，会分别通过 HTTP 和 SOCKS 代理访问 Google HTTPS 测试地址。两项均返回 `204` 表示测试成功。`start` 成功只表示本地代理端口就绪。

出现问题时查看日志：

```bash
tail -n 50 .proxy/mihomo.log
```

## VPN 连通性检查

`test_connection.sh` 用于在 Linux 上检查网络连通性并查看公网出口信息，依赖 Bash 和 curl。脚本包含 8 项连通性测试，以及公网 IPv4 查询、Cloudflare 连接诊断，共 10 次请求。每次请求连接超时为 3 秒，总超时为 8 秒。

在项目目录中运行：

```bash
bash test_connection.sh
```

脚本默认使用 curl 支持的代理环境变量和系统路由。可在 `proxyon` 或 `proxyoff` 后运行，结合公网出口 IP 比较访问路径；`python3 mihomo.py test` 则显式测试本机 HTTP 和 SOCKS 代理端口。

### 输出说明

前 8 项连通性测试按以下规则显示结果，之后单独输出公网 IPv4 和 Cloudflare 诊断信息：

- **通过**：HTTP 状态码和响应正文均符合预期。
- **异常**：收到了响应，但状态码或正文不符合预期。
- **失败**：请求未完成，可能涉及 DNS、连接、超时或证书问题。

### 修改检测地址

修改 `test_connection.sh` 中的 `SITES` 配置区，每行格式为：

```text
名称|检测地址|预期状态码|预期正文
```

多个允许的状态码用逗号分隔；预期正文为空时，保留行末的 `|`。结束标记 `SITES` 必须单独占一行。

### 注意事项

- 保留 HTTPS 证书校验，不自动跟随重定向。
- 检测通过仅说明对应地址访问正常，不代表所有流量都经过 VPN，也不保证 AI 服务可用。
- 请结合公网出口 IP 判断访问路径。
- Cloudflare 的 `warp` 字段只表示其 WARP 服务状态，不代表其他 VPN 的状态。

## 停止代理

仅关闭当前终端的代理，执行 `proxyoff`。同时停止后台服务则执行：

```bash
python3 mihomo.py stop
proxyoff
```

`stop` 停止后台服务；`proxyoff` 清除当前终端的代理变量，避免程序继续连接已关闭的端口。

## 更新节点

修改 `vless.txt` 中的 VLESS 链接后执行：

```bash
python3 mihomo.py check
python3 mihomo.py stop
python3 mihomo.py start
```

当前脚本支持 VLESS + TCP + Reality（含 Vision）。也可通过 `python3 mihomo.py start --vless-file /path/to/vless.txt` 指定其他节点文件。

## 目录内容

| 文件 | 用途 |
| --- | --- |
| `reference/.bashrc-cf2` | 来自已确认能连接 VPN 的机器的 `.bashrc`，作为当前参考，不参与代理脚本运行 |
| `mihomo.py` | 启动、停止、状态查询和测试 |
| `proxy.sh` | 定义 proxyon / proxyoff 命令，不含节点凭据 |
| `test_connection.sh` | 8 项连通性测试、公网 IPv4 查询及 Cloudflare 连接诊断 |
| `install_mihomo.sh` | 校验并安装上传到当前目录的 Mihomo 压缩包，不启动代理 |
| `vless.txt` | VLESS 节点链接 |
| `.proxy/mihomo` | 已安装的 Linux x86_64 代理程序，后续直接复用 |
| `.proxy/config.json` | 启动时根据节点生成的配置 |
| `.proxy/process.json` | 当前运行进程的记录 |
| `.proxy/mihomo.log` | 启动和运行日志，每次启动覆盖 |

`start` 会向 `.bashrc` 安装终端代理命令加载配置和提示，其他命令不修改它。无需 sudo、systemd 或 TUN。运行时目录权限为 700，节点、生成配置和日志权限为 600。

## 没有 Mihomo 时：下载、上传并启动

在 **MacBook** 执行，将 `端口号`、`用户名` 和 `服务器地址` 替换为实际连接信息：

```bash
cd ~/Downloads
curl -fL --retry 3 --connect-timeout 20 \
  -o mihomo-linux-amd64-compatible-v1.19.32.gz \
  https://github.com/MetaCubeX/mihomo/releases/download/v1.19.32/mihomo-linux-amd64-compatible-v1.19.32.gz &&
scp -P 端口号 mihomo-linux-amd64-compatible-v1.19.32.gz \
  用户名@服务器地址:/path/to/devbox-utils/setup_proxy/
```

在 **服务器** 的 `setup_proxy` 目录执行（校验成功后才会继续解压）：

```bash
cd /path/to/devbox-utils/setup_proxy
bash install_mihomo.sh
python3 mihomo.py start &&
source proxy.sh &&
proxyon &&
python3 mihomo.py test
```

`install_mihomo.sh` 会校验压缩包、停止旧进程、解压到 `.proxy/mihomo` 并设置权限；它不启动代理，完成后再执行 `python3 mihomo.py start`。

安装后文件保存在持久化目录中，后续直接运行 `python3 mihomo.py start`。
