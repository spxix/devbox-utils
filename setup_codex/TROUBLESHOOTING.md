# Codex 常见问题与修复

## 1. 工作区路由发现超时

```text
Error: account/read failed: account/read failed: workspace routing discovery timed out
```

先保存各个 Codex 会话中的工作，再在普通终端中依次执行以下两条命令。第一条会终止当前用户有权限结束且命令行中含有 `codex` 的进程，第二条重新启动 Codex。

```bash
pkill -f codex
codex
```
