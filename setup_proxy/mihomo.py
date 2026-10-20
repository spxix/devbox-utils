#!/usr/bin/env python3
"""User-local Mihomo manager with a Bash startup hint."""
import argparse
import fcntl
import gzip
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shlex
import shutil
import signal
import socket
import subprocess
import sys
import time
import urllib.request
from urllib.parse import parse_qs, unquote, urlsplit
import uuid

BASE = Path(__file__).resolve().parent
STATE = BASE / '.proxy'
BIN = STATE / 'mihomo'
CONFIG = STATE / 'config.json'
PID = STATE / 'process.json'
LOG = STATE / 'mihomo.log'
PORTS = (7897, 7898)


def config_from_link(path):
    lines = [s.strip() for s in path.read_text().splitlines()
             if s.strip() and not s.lstrip().startswith('#')]
    if len(lines) != 1:
        raise ValueError('节点文件必须包含一条 VLESS 链接。')
    u = urlsplit(lines[0])
    q = parse_qs(u.query, keep_blank_values=True)
    allowed = {'type', 'security', 'flow', 'fp', 'pbk', 'sid', 'sni', 'encryption'}
    if set(q) - allowed:
        raise ValueError('存在尚未支持的节点参数：' + ', '.join(sorted(set(q) - allowed)))
    if any(len(v) != 1 for v in q.values()):
        raise ValueError('节点参数不能重复。')
    q = {k: v[0] for k, v in q.items()}
    if u.scheme != 'vless' or not u.hostname or not u.username or not u.port:
        raise ValueError('需要有效的 vless://UUID@服务器:端口 链接。')
    if q.get('type', 'tcp') != 'tcp' or q.get('security') != 'reality':
        raise ValueError('此脚本针对当前节点，仅支持 VLESS + TCP + Reality。')
    if q.get('encryption', 'none') != 'none':
        raise ValueError('不支持该 encryption 参数。')
    if q.get('flow', '') not in ('', 'xtls-rprx-vision'):
        raise ValueError('不支持该 flow 参数。')
    if not q.get('pbk') or not q.get('sni'):
        raise ValueError('Reality 节点缺少 pbk 或 sni。')
    sid = q.get('sid', '')
    if len(sid) > 16 or len(sid) % 2 or not re.fullmatch('[0-9a-fA-F]*', sid):
        raise ValueError('sid 必须是至多 16 位、偶数长度的十六进制字符串。')
    node = {'name': 'my-vless', 'type': 'vless', 'server': u.hostname,
            'port': u.port, 'uuid': str(uuid.UUID(unquote(u.username))),
            'network': 'tcp', 'tls': True, 'servername': q['sni'],
            'client-fingerprint': q.get('fp') or 'chrome',
            'reality-opts': {'public-key': q['pbk'], 'short-id': sid},
            'udp': True}
    if q.get('flow'):
        node['flow'] = q['flow']
    rules = [f'IP-CIDR,{net},DIRECT,no-resolve' for net in
             ('127.0.0.0/8', '10.0.0.0/8', '172.16.0.0/12',
              '192.168.0.0/16', '100.64.0.0/10', '169.254.0.0/16')]
    rules += [f'IP-CIDR6,{net},DIRECT,no-resolve' for net in
              ('::1/128', 'fc00::/7', 'fe80::/10')]
    rules += [f'DOMAIN-SUFFIX,{domain},DIRECT' for domain in
              ('localhost', 'local', 'ivolces.com', 'volces.com',
               'volceapi.com', 'internal.spx', 'tencentcloud.com')]
    rules += ['IP-CIDR,14.103.213.146/32,DIRECT,no-resolve', 'MATCH,my-vless']
    return {'port': PORTS[0], 'socks-port': PORTS[1], 'allow-lan': False,
            'bind-address': '127.0.0.1', 'mode': 'rule', 'log-level': 'info',
            'tun': {'enable': False}, 'proxies': [node], 'rules': rules}


def atomic_write(path, data, mode=0o600):
    temp = path.with_name(path.name + '.tmp')
    temp.write_bytes(data)
    temp.chmod(mode)
    temp.replace(path)


def fetch(url):
    # The copied .bashrc may point to a proxy that has not started yet.
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    req = urllib.request.Request(url, headers={'User-Agent': 'local-mihomo-setup'})
    with opener.open(req, timeout=90) as response:
        return response.read()


def install():
    if BIN.is_file() and os.access(BIN, os.X_OK):
        return
    machine = platform.machine()
    arch = {'x86_64': 'amd64-compatible', 'aarch64': 'arm64'}.get(machine)
    if platform.system() != 'Linux' or not arch:
        raise ValueError('自动安装只支持 Linux x86_64 / aarch64。')
    print('从 GitHub 官方 Release 下载 Mihomo（直连）…', flush=True)
    release = json.loads(fetch('https://api.github.com/repos/MetaCubeX/mihomo/releases/latest'))
    name = f'mihomo-linux-{arch}-{release["tag_name"]}.gz'
    asset = next((a for a in release['assets'] if a['name'] == name), None)
    if not asset:
        raise ValueError('官方 Release 中未找到兼容安装包。可手动放置 .proxy/mihomo。')
    blob = fetch(asset['browser_download_url'])
    digest = asset.get('digest')
    if digest and digest.startswith('sha256:'):
        if hashlib.sha256(blob).hexdigest() != digest.split(':', 1)[1]:
            raise ValueError('安装包 SHA256 校验失败。')
    else:
        print('提示：Release 未提供 SHA256 digest，下载依赖 HTTPS 校验。')
    atomic_write(BIN, gzip.decompress(blob), 0o700)
    print('已安装：' + release['tag_name'])


def identity(pid):
    try:
        proc = Path('/proc') / str(pid)
        fields = (proc / 'stat').read_text().rsplit(')', 1)[1].split()
        if fields[0] == 'Z':
            return None
        return {'pid': pid, 'start': fields[19], 'exe': str((proc / 'exe').resolve(strict=True))}
    except (OSError, IndexError):
        return None


def same_executable(path):
    try:
        actual = os.stat(path)
        expected = os.stat(BIN)
        return (actual.st_dev, actual.st_ino) == (expected.st_dev, expected.st_ino)
    except OSError:
        return False


def running():
    if not PID.exists():
        return None
    try:
        record = json.loads(PID.read_text())
        current = identity(record['pid'])
        if (current and current['start'] == record.get('start')
                and same_executable(current['exe'])):
            if current != record:
                atomic_write(PID, json.dumps(current).encode())
            return current['pid']
    except (ValueError, KeyError, OSError):
        pass
    return None


def start(link):
    if running():
        print('代理已运行。修改节点后请先 stop 再 start。')
        return
    config = config_from_link(link)
    for port in PORTS:
        with socket.socket() as sock:
            try:
                sock.bind(('127.0.0.1', port))
            except OSError:
                raise ValueError(f'端口 {port} 已被占用，请先处理占用进程。') from None
    install()
    link.chmod(0o600)
    atomic_write(CONFIG, json.dumps(config, indent=2).encode())
    env = {k: v for k, v in os.environ.items() if k.lower() not in
           ('http_proxy', 'https_proxy', 'all_proxy')}
    with LOG.open('wb') as log:
        check = subprocess.run([str(BIN), '-t', '-d', str(STATE), '-f', str(CONFIG)],
                               stdout=log, stderr=log, env=env, timeout=30)
        if check.returncode:
            raise ValueError(f'Mihomo 配置校验失败，查看 {LOG}')
        proc = subprocess.Popen([str(BIN), '-d', str(STATE), '-f', str(CONFIG)],
                                stdin=subprocess.DEVNULL, stdout=log, stderr=log,
                                start_new_session=True, env=env)
    try:
        for _ in range(100):
            if proc.poll() is not None:
                raise ValueError(f'Mihomo 启动失败，查看 {LOG}')
            record = identity(proc.pid)
            ready = True
            for port in PORTS:
                try:
                    with socket.create_connection(('127.0.0.1', port), timeout=0.1):
                        pass
                except OSError:
                    ready = False
            if ready and record:
                atomic_write(PID, json.dumps(record).encode())
                print(f'代理已启动，PID {proc.pid}；HTTP 7897 / SOCKS5 7898。')
                print('当前终端启用代理：')
                print(f'source {shlex.quote(str(BASE / "proxy.sh"))} && proxyon')
                return
            time.sleep(0.1)
        raise ValueError(f'等待代理端口超时，查看 {LOG}')
    except BaseException:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()
        raise


def stop():
    pid = running()
    if pid:
        os.kill(pid, signal.SIGTERM)
        for _ in range(50):
            if not running():
                break
            time.sleep(0.1)
        else:
            raise ValueError('进程未及时退出，请查看日志。')
    PID.unlink(missing_ok=True)
    print('代理已停止。当前终端还需执行：')
    print('proxyoff')


def install_hint(path):
    marker = '# setup_proxy: terminal hint'
    command = 'source ' + shlex.quote(str(BASE / 'proxy.sh'))
    hint = '设置当前终端代理：' + command
    old_block = (f'\n{marker}\n'
             'case $- in\n'
             f"    *i*) printf '%s\\n' {shlex.quote(hint)} ;;\n"
             'esac\n')
    color_block = (f'\n{marker}\n'
             'case $- in\n'
             f"    *i*) printf '\\033[1;36m设置当前终端代理：\\033[0m\\033[1;32m%s\\033[0m\\n' {shlex.quote(command)} ;;\n"
             'esac\n')
    plain_commands_block = (f'\n{marker}\n'
             'case $- in\n'
             f'    *i*) {command}\n'
             "          printf '\\033[1;36m当前终端代理：\\033[0m 开启 proxyon / 关闭 proxyoff\\n' ;;\n"
             'esac\n')
    block = plain_commands_block.replace(
        '开启 proxyon / 关闭 proxyoff',
        '开启 \\033[1;32mproxyon\\033[0m / 关闭 \\033[1;31mproxyoff\\033[0m')
    fd = os.open(path, os.O_RDWR | os.O_CREAT, 0o600)
    with os.fdopen(fd, 'r+') as file:
        fcntl.flock(file, fcntl.LOCK_EX)
        content = file.read()
        previous_match = re.search(
            rf'\n{re.escape(marker)}\n.*?\nesac\n', content, re.DOTALL)
        if previous_match:
            file.seek(0)
            file.write(content[:previous_match.start()] + block
                       + content[previous_match.end():])
            file.truncate()
            print(f'已更新终端代理命令和提示：{path}')
            return
        if marker in content.splitlines():
            print(f'终端提示已存在：{path}')
            return
        file.write(block)
    print(f'已添加终端提示：{path}；新开的交互式 Bash 终端会显示提示。')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['start', 'stop', 'status', 'test', 'env', 'off', 'check'])
    parser.add_argument('--vless-file', type=Path, default=BASE / 'vless.txt')
    parser.add_argument('--bashrc', type=Path, default=Path.home() / '.bashrc',
                        help='start 写入提示的文件，默认当前用户的 ~/.bashrc')
    args = parser.parse_args()
    os.umask(0o077)
    if args.action == 'check':
        config_from_link(args.vless_file)
        print('节点解析通过：VLESS + TCP + Reality；未联网、未启动服务。')
        return
    if args.action == 'env':
        print((BASE / 'proxy.sh').read_text(), end='')
        return
    if args.action == 'off':
        print('unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY')
        return
    if args.action == 'status':
        pid = running()
        print(f'运行中：PID {pid}，HTTP 7897 / SOCKS5 7898' if pid else '未运行（此脚本管理的代理）。')
        return
    if args.action == 'test':
        curl = shutil.which('curl')
        if not curl:
            raise ValueError('连通性测试需要 curl。')
        for proxy in ('http://127.0.0.1:7897', 'socks5h://127.0.0.1:7898'):
            print(f'测试 {proxy}', flush=True)
            subprocess.run([curl, '--noproxy', '', '--proxy', proxy, '--fail',
                            '--silent', '--show-error', '--connect-timeout', '10',
                            '--max-time', '30', '--output', '/dev/null', '--write-out',
                            'HTTPS 状态码：%{http_code}\n', 'https://www.google.com/generate_204'], check=True)
        return
    STATE.mkdir(mode=0o700, exist_ok=True)
    STATE.chmod(0o700)
    with (STATE / 'lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if args.action == 'start':
            start(args.vless_file)
            install_hint(args.bashrc.expanduser())
        else:
            stop()


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, subprocess.SubprocessError) as exc:
        # Do not echo input links or exception details containing credentials.
        if isinstance(exc, ValueError):
            print(f'错误：{exc}', file=sys.stderr)
        else:
            print(f'操作失败（{type(exc).__name__}）。请检查网络、文件权限或 .proxy/mihomo.log。', file=sys.stderr)
        sys.exit(1)
