#!/usr/bin/env bash

command -v curl >/dev/null 2>&1 || {
    echo "请先安装 curl"
    exit 1
}

echo "===== 8 项连通性测试 ====="

# 默认使用终端的代理环境变量和系统路由。
# 每项最多等待 8 秒，检查预期状态码和正文。
while IFS='|' read -r name url expected_code expected_body; do
    if ! result=$(curl -q -sS --connect-timeout 3 --max-time 8 \
        -w $'\n%{http_code}' "$url"); then
        echo "[失败] $name：请求未完成"
        continue
    fi

    code=${result##*$'\n'}
    body=${result%$'\n'*}
    body=${body%$'\n'}

    if [[ ",$expected_code," == *",$code,"* &&
          "$body" == "$expected_body" ]]; then
        echo "[通过] $name：HTTP $code，正文符合预期"
    else
        echo "[异常] $name：HTTP $code，状态码或正文不符合预期"
    fi
done <<'SITES'
Google-gstatic|https://www.gstatic.com/generate_204|204|
Google-HTTPS|https://www.google.com/generate_204|204|
Android-HTTP|http://connectivitycheck.gstatic.com/generate_204|204|
Microsoft|http://www.msftconnecttest.com/connecttest.txt|200|Microsoft Connect Test
Microsoft-NCSI|http://www.msftncsi.com/ncsi.txt|200|Microsoft NCSI
Firefox|http://firefox-portal-detection.com/generate_204|200,204|
Ubuntu|http://connectivity-check.ubuntu.com/|204|
Fedora|http://fedoraproject.org/static/hotspot.txt|200|OK
SITES

echo
echo "===== 出口 IPv4 查询 ====="
curl -q -sS --connect-timeout 3 --max-time 8 \
    -w '\nHTTP %{http_code}\n' \
    "https://api.ipify.org"

echo
echo "===== Cloudflare 连接诊断 ====="
curl -q -sS --connect-timeout 3 --max-time 8 \
    -w '\nHTTP %{http_code}\n' \
    "https://www.cloudflare.com/cdn-cgi/trace"