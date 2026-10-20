# 加载后使用 proxyon / proxyoff；加载本文件不会自动启用代理。
print_ip_info() {
  local label="$1"
  local use_proxy="$2"
  local color_reset="\033[0m"
  local color_start=""
  local curl_base=(curl -s --max-time 7 --connect-timeout 4 --noproxy "*")
  # Explicit proxy curl to avoid relying on env when we want to force socks.
  local curl_proxy_base=(curl -s --max-time 15 --connect-timeout 8 --noproxy "" -x "socks5h://127.0.0.1:${CLASH_SOCKS_PORT:-7898}")
  local ipv4 ipv6 ipv4_geo ipv6_geo

  case "$label" in
    before-proxyon|after-proxyoff) color_start="\033[31m" ;; # red
    after-proxyon|before-proxyoff) color_start="\033[32m" ;; # green
    *)              color_start="" ;;
  esac

  if [ "$use_proxy" = "nopxy" ]; then
    ipv4=$(env -u http_proxy -u https_proxy -u all_proxy "${curl_base[@]}" -4 ipv4.ip.sb 2>/dev/null || true)
    ipv6=$(env -u http_proxy -u https_proxy -u all_proxy "${curl_base[@]}" -6 icanhazip.com 2>/dev/null || true)
  else
    ipv4=$("${curl_proxy_base[@]}" -4 http://ipv4.ip.sb 2>/dev/null || true)
    ipv6=$("${curl_proxy_base[@]}" -6 http://icanhazip.com 2>/dev/null || true)
  fi

  ipv4_geo="n/a"
  ipv6_geo="n/a"

  get_geo() {
    local ip="$1" mode="$2" url resp
    url="https://ipapi.co/json"
    [ -n "$ip" ] && url="https://ipapi.co/${ip}/json"
    if [ "$mode" = "proxy" ]; then
      resp=$("${curl_proxy_base[@]}" "$url" 2>/dev/null || true)
    else
      resp=$(env -u http_proxy -u https_proxy -u all_proxy "${curl_base[@]}" "$url" 2>/dev/null || true)
    fi
    python3 -c 'import sys, json
data = sys.stdin.read()
if not data.strip():
    print("n/a"); sys.exit(0)
try:
    d = json.loads(data)
except Exception:
    print("n/a"); sys.exit(0)
country = d.get("country_name") or d.get("country") or "n/a"
city = d.get("city") or ""
out = (country + " " + city).strip()
print(out or "n/a")' <<<"$resp"
  }

  if [ -n "$ipv4" ]; then
    if [ "$use_proxy" = "nopxy" ]; then
      ipv4_geo=$(get_geo "" "direct")
    else
      ipv4_geo=$(get_geo "" "proxy")
    fi
  fi

  if [ -n "$ipv6" ]; then
    if [ "$use_proxy" = "nopxy" ]; then
      ipv6_geo=$(get_geo "$ipv6" "direct")
    else
      ipv6_geo=$(get_geo "$ipv6" "proxy")
    fi
  fi

  echo -e "${color_start}[IP][$label] IPv4: ${ipv4:-n/a} (${ipv4_geo:-n/a})${color_reset}"
}

unalias proxyon proxyoff 2>/dev/null || true

proxyon() {
    local _proxy_bypass
    print_ip_info "before-proxyon" "nopxy"
    export http_proxy='http://127.0.0.1:7897'
    export https_proxy='http://127.0.0.1:7897'
    export all_proxy='socks5h://127.0.0.1:7898'
    export HTTPS_PROXY="$https_proxy"
    export ALL_PROXY="$all_proxy"
    export HTTP_PROXY="$http_proxy"
    
    # 保留已有绕过规则，重复开启时不重复追加。
    no_proxy=${no_proxy-${NO_PROXY-}}
    for _proxy_bypass in localhost 127.0.0.1 ::1 10.0.0.0/8 172.16.0.0/12 \
        192.168.0.0/16 100.64.0.0/10 local .local ivolces.com .ivolces.com \
        volces.com .volces.com volceapi.com .volceapi.com internal.spx \
        .internal.spx tencentcloud.com .tencentcloud.com 14.103.213.146
    do
        case ",$no_proxy," in
            *",$_proxy_bypass,"*) ;;
            *) no_proxy="${no_proxy:+$no_proxy,}$_proxy_bypass" ;;
        esac
    done
    unset _proxy_bypass
    export no_proxy
    export NO_PROXY="$no_proxy"
    print_ip_info "after-proxyon" "useproxy"
}

proxyoff() {
    print_ip_info "before-proxyoff" "useproxy"
    unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY
    print_ip_info "after-proxyoff" "nopxy"
}
