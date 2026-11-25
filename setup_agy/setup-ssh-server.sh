#!/usr/bin/env bash
set -eo pipefail
umask 022

# 配置 Antigravity Desktop SSH 远端环境：
# 1) 在 ~/.bashrc 顶部写入幂等代理钩子（覆盖 SSH 引导下载/自动升级与远端 language_server 启动环境，不影响交互终端默认直连）
# 2) 预下载并校验当前稳定版 ~/.antigravity-hub-server 二进制（已有合法二进制时自动跳过）

usage() {
    cat <<'EOF'
用法: bash setup-ssh-server.sh [选项]

选项:
  --version <ver>       指定预安装的 Antigravity Hub Server 版本（也可通过 AGY_HUB_VERSION 设置；默认取最新稳定版）
  --skip-download       仅写入 ~/.bashrc SSH 代理钩子并清理残留临时文件，跳过二进制预下载
  --bashrc <path>       指定要更新的 bashrc 路径（默认: $HOME/.bashrc）
  --no-confirm          跳过交互式代理确认提示（供外层安装脚本调用）
  -h, --help            显示本帮助信息
EOF
}

sh_quote() {
    local value="$1"
    printf "'%s'" "${value//\'/\'\\\'\'}"
}

validate_no_control_chars() {
    local label="$1"
    local value="$2"
    local LC_ALL=C
    if [[ "$value" == *[[:cntrl:]]* ]]; then
        echo "${label}包含非法控制字符。" >&2
        exit 1
    fi
}

validate_version_string() {
    local ver="$1"
    if [[ ! "$ver" =~ ^[A-Za-z0-9._-]{1,128}$ || "$ver" =~ ^\.+$ ]]; then
        echo "无效的 Hub Server 版本号：$ver" >&2
        exit 1
    fi
}

verify_elf_binary() {
    local file_path="$1"
    local target_arch="$2"
    local header_bytes=""

    [[ -f "$file_path" ]] || return 1
    header_bytes="$(od -An -tu1 -N20 "$file_path" 2>/dev/null </dev/null)" || return 1
    # shellcheck disable=SC2086
    set -- $header_bytes
    [[ "$#" -eq 20 ]] || return 1
    [[ "$1.$2.$3.$4.$5.$6" == "127.69.76.70.2.1" ]] || return 1

    case "$target_arch" in
        x64)
            [[ "${19}.${20}" == "62.0" ]]
            ;;
        arm64)
            [[ "${19}.${20}" == "183.0" ]]
            ;;
        *)
            return 1
            ;;
    esac
}

check_host_platform() {
    local os_name=""
    local machine_arch=""
    local long_bit=""
    local libc_info=""
    local glibc_ver=""
    local glibc_major=""
    local glibc_minor=""

    os_name="$(uname -s 2>/dev/null || true)"
    if [[ "$os_name" != "Linux" ]]; then
        echo "不支持的操作系统：${os_name:-unknown}（仅支持 Linux）。" >&2
        exit 1
    fi

    machine_arch="$(uname -m 2>/dev/null || true)"
    case "$machine_arch" in
        x86_64|amd64)
            agy_arch="x64"
            ;;
        aarch64|arm64)
            agy_arch="arm64"
            ;;
        *)
            echo "不支持的 CPU 架构：${machine_arch:-unknown}（需要 x86_64 或 aarch64）。" >&2
            exit 1
            ;;
    esac

    long_bit="$(getconf LONG_BIT 2>/dev/null || true)"
    if [[ "$long_bit" == "32" ]]; then
        echo "不支持 32 位用户态环境。" >&2
        exit 1
    fi

    libc_info="$(getconf GNU_LIBC_VERSION 2>/dev/null || true)"
    if [[ "$libc_info" == "glibc "* ]]; then
        glibc_ver="${libc_info#glibc }"
    else
        libc_info="$(ldd --version 2>&1 </dev/null | head -n 1 || true)"
        if [[ "$libc_info" == *musl* ]]; then
            echo "不支持 musl libc（需要 glibc 2.26 或更高版本）。" >&2
            exit 1
        elif [[ "$libc_info" == *GLIBC* || "$libc_info" == *"GNU libc"* || "$libc_info" == *"GNU C Library"* ]]; then
            glibc_ver="${libc_info##* }"
        fi
    fi

    if [[ "$glibc_ver" =~ ^([0-9]+)\.([0-9]+) ]]; then
        glibc_major="${BASH_REMATCH[1]}"
        glibc_minor="${BASH_REMATCH[2]}"
        if (( glibc_major < 2 || (glibc_major == 2 && glibc_minor < 26) )); then
            echo "glibc 版本过低（当前 ${glibc_ver}，需要 2.26 或更高版本）。" >&2
            exit 1
        fi
    fi
}

install_bashrc_hook() {
    local target_bashrc="$1"
    local proxy_http="$2"
    local proxy_https="$3"
    local proxy_all="$4"
    shift 4
    local -a bypass_items=("$@")

    local start_marker="# >>> setup_agy: Antigravity SSH Hub proxy >>>"
    local end_marker="# <<< setup_agy: Antigravity SSH Hub proxy <<<"
    local quoted_http=""
    local quoted_https=""
    local quoted_all=""
    local bypass_line=""
    local item=""
    local hook_block=""
    local stripped_file=""
    local merged_file=""

    quoted_http="$(sh_quote "$proxy_http")"
    quoted_https="$(sh_quote "$proxy_https")"
    quoted_all="$(sh_quote "$proxy_all")"

    for item in "${bypass_items[@]}"; do
        bypass_line+="${bypass_line:+ }$(sh_quote "$item")"
    done

    hook_block="$(cat <<EOF
$start_marker
# 仅在 Antigravity SSH 引导（sh -s）及远端服务解析登录环境时静默注入代理；
# 日常交互式 SSH 终端与其他命令不触发，保持默认直连与 proxyon/proxyoff 行为。
if [[ "\${ANTIGRAVITY_RESOLVING_ENVIRONMENT:-}" == "1"
    || ( -n "\${SSH_CLIENT:-}\${SSH_CONNECTION:-}" && "\${BASH_EXECUTION_STRING:-}" == "sh -s" ) ]]; then
    export http_proxy=$quoted_http
    export https_proxy=$quoted_https
    export all_proxy=$quoted_all
    export HTTP_PROXY="\$http_proxy"
    export HTTPS_PROXY="\$https_proxy"
    export ALL_PROXY="\$all_proxy"
    for _agy_bypass in $bypass_line; do
        if [[ ",\${no_proxy:-\${NO_PROXY:-}}," != *",\$_agy_bypass,"* ]]; then
            no_proxy="\${no_proxy:+\$no_proxy,}\$_agy_bypass"
        fi
    done
    unset _agy_bypass
    export no_proxy
    export NO_PROXY="\$no_proxy"
fi
$end_marker
EOF
)"

    mkdir -p -- "$(dirname -- "$target_bashrc")"
    touch -- "$target_bashrc"

    stripped_file="$temp_dir/bashrc.stripped"
    merged_file="$temp_dir/bashrc.merged"

    awk -v start="$start_marker" -v end="$end_marker" '
        $0 == start { skipping = 1; next }
        skipping && $0 == end { skipping = 0; skip_blank = 1; next }
        skipping { next }
        skip_blank {
            skip_blank = 0
            if ($0 == "") {
                next
            }
        }
        { print }
    ' "$target_bashrc" > "$stripped_file"

    if [[ -s "$stripped_file" ]]; then
        printf '%s\n\n' "$hook_block" > "$merged_file"
        cat -- "$stripped_file" >> "$merged_file"
    else
        printf '%s\n' "$hook_block" > "$merged_file"
    fi

    bash -n "$merged_file"
    cat -- "$merged_file" > "$target_bashrc"
}

clean_stale_partials() {
    local root_dir="$1"
    local partial=""
    local pid_part=""

    for partial in "$root_dir"/bin/*/.partial.* "$root_dir"/bin/*/.exec-test.*; do
        [[ -e "$partial" ]] || continue
        case "$partial" in
            */.partial.*)
                pid_part="${partial##*.}"
                if [[ "$pid_part" =~ ^[0-9]+$ ]] && kill -0 "$pid_part" 2>/dev/null; then
                    continue
                fi
                ;;
        esac
        rm -f -- "$partial" 2>/dev/null || true
    done
}

check_exec_mount() {
    local target_dir="$1"
    local probe_script="$target_dir/.exec-test.$$"
    local rc=0

    printf '#!/bin/sh\nexit 0\n' > "$probe_script"
    chmod 755 "$probe_script"
    "$probe_script" </dev/null >/dev/null 2>&1 || rc=$?
    rm -f -- "$probe_script"
    if [[ "$rc" -eq 126 ]]; then
        echo "目录无法执行二进制文件（可能位于 noexec 挂载点）：$target_dir" >&2
        exit 1
    fi
}

resolve_release_entry() {
    local requested_version="$1"
    local releases_url="https://antigravity-hub-auto-updater-974169037036.us-central1.run.app/releases"
    local releases_json=""
    local -a curl_args=(
        -fsSL
        --retry 3
        --retry-all-errors
        --connect-timeout 15
        --max-time 30
        "$releases_url"
    )

    releases_json="$(curl "${curl_args[@]}")"
    awk -v target="$requested_version" '
        BEGIN { RS = "}" }
        {
            ver = ""
            eid = ""
            if (match($0, /"version"[ \t\r\n]*:[ \t\r\n]*"[^"]+"/)) {
                s = substr($0, RSTART, RLENGTH)
                sub(/^"version"[ \t\r\n]*:[ \t\r\n]*"/, "", s)
                sub(/"$/, "", s)
                ver = s
            }
            if (match($0, /"execution_id"[ \t\r\n]*:[ \t\r\n]*"[^"]+"/)) {
                s = substr($0, RSTART, RLENGTH)
                sub(/^"execution_id"[ \t\r\n]*:[ \t\r\n]*"/, "", s)
                sub(/"$/, "", s)
                eid = s
            }
            if (ver == "" || eid == "") {
                next
            }
            if (target == "" || ver == target) {
                printf "%s\t%s\n", ver, eid
                found = 1
                exit 0
            }
        }
        END {
            if (!found) {
                exit 1
            }
        }
    ' <<<"$releases_json"
}

# 1. 解析命令行参数与环境变量
requested_version="${AGY_HUB_VERSION:-}"
skip_download=0
no_confirm=0
bashrc_path=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            if [[ $# -lt 2 ]]; then
                echo "缺少参数值：$1" >&2
                exit 1
            fi
            requested_version="$2"
            shift 2
            ;;
        --version=*)
            requested_version="${1#*=}"
            shift
            ;;
        --skip-download|--skip-hub-download)
            skip_download=1
            shift
            ;;
        --bashrc)
            if [[ $# -lt 2 ]]; then
                echo "缺少参数值：$1" >&2
                exit 1
            fi
            bashrc_path="$2"
            shift 2
            ;;
        --bashrc=*)
            bashrc_path="${1#*=}"
            shift
            ;;
        --no-confirm)
            no_confirm=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "未知选项：$1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [[ -z "${HOME:-}" || "$HOME" != /* ]]; then
    echo "HOME 未设置为绝对路径：${HOME:-}" >&2
    exit 1
fi

if [[ -z "$bashrc_path" ]]; then
    bashrc_path="$HOME/.bashrc"
fi

if [[ -n "$requested_version" ]]; then
    validate_version_string "$requested_version"
fi

# 2. 检查系统依赖与运行平台
for dependency in curl gzip awk od grep sed ps pgrep mktemp; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
        echo "缺少系统依赖：$dependency，请由管理员安装后重试。" >&2
        exit 1
    fi
done

agy_arch=""
check_host_platform

if [[ "$skip_download" -eq 0 && "$no_confirm" -eq 0 ]]; then
    echo "运行前请先开启代理，并确保当前终端已配置代理环境变量。"
    echo "确认代理可用后，按回车继续配置；未开启请按 Ctrl+C 退出。"
    if ! read -r -p "已开启代理，按回车继续：" </dev/tty; then
        echo "未收到代理确认，已取消配置。" >&2
        exit 1
    fi
fi

temp_dir="$(mktemp -d)"
partial_download=""
cleanup() {
    if [[ -n "$partial_download" ]]; then
        rm -f -- "$partial_download" 2>/dev/null || true
    fi
    rm -rf -- "$temp_dir"
}
trap cleanup EXIT

# 3. 解析代理配置并在 ~/.bashrc 顶部写入幂等钩子
default_http_proxy="http://127.0.0.1:${CLASH_HTTP_PORT:-7897}"
default_all_proxy="socks5h://127.0.0.1:${CLASH_SOCKS_PORT:-7898}"

resolved_http_proxy="${http_proxy:-${HTTP_PROXY:-$default_http_proxy}}"
resolved_https_proxy="${https_proxy:-${HTTPS_PROXY:-$resolved_http_proxy}}"
resolved_all_proxy="${all_proxy:-${ALL_PROXY:-$default_all_proxy}}"

validate_no_control_chars "http_proxy" "$resolved_http_proxy"
validate_no_control_chars "https_proxy" "$resolved_https_proxy"
validate_no_control_chars "all_proxy" "$resolved_all_proxy"

default_bypass_items=(
    localhost
    127.0.0.1
    ::1
    10.0.0.0/8
    172.16.0.0/12
    192.168.0.0/16
    100.64.0.0/10
    local
    .local
    ivolces.com
    .ivolces.com
    volces.com
    .volces.com
    volceapi.com
    .volceapi.com
    internal.spx
    .internal.spx
    tencentcloud.com
    .tencentcloud.com
    14.103.213.146
)

merged_bypass_items=()
merged_bypass_csv=","
for candidate in "${default_bypass_items[@]}"; do
    if [[ "$merged_bypass_csv" != *",$candidate,"* ]]; then
        merged_bypass_items+=("$candidate")
        merged_bypass_csv+="${candidate},"
    fi
done

current_no_proxy="${no_proxy:-${NO_PROXY:-}}"
if [[ -n "$current_no_proxy" ]]; then
    IFS=',' read -r -a extra_bypass_items <<<"$current_no_proxy"
    for candidate in "${extra_bypass_items[@]}"; do
        [[ -n "$candidate" ]] || continue
        if [[ "$candidate" =~ ^[A-Za-z0-9._:/-]+$ && "$merged_bypass_csv" != *",$candidate,"* ]]; then
            merged_bypass_items+=("$candidate")
            merged_bypass_csv+="${candidate},"
        fi
    done
fi

echo "==> 更新 $bashrc_path 顶部 Antigravity SSH 代理钩子"
install_bashrc_hook \
    "$bashrc_path" \
    "$resolved_http_proxy" \
    "$resolved_https_proxy" \
    "$resolved_all_proxy" \
    "${merged_bypass_items[@]}"

# 自检非交互 sh -s 钩子生效情况（当目标为当前用户默认 ~/.bashrc 时）
if [[ "$bashrc_path" == "$HOME/.bashrc" && -x /bin/bash ]]; then
    sh_s_proxy="$(
        env -i HOME="$HOME" PATH="/usr/bin:/bin" SSH_CLIENT="127.0.0.1 1 22" \
            /bin/bash -c "sh -s" <<<'printf "%s" "${http_proxy:-}"'
    )"
    if [[ "$sh_s_proxy" != "$resolved_http_proxy" ]]; then
        echo "错误：模拟 SSH sh -s 未读取到预期代理（实际：${sh_s_proxy:-空}），请检查 ~/.bashrc。" >&2
        exit 1
    fi
fi

# 4. 初始化 ~/.antigravity-hub-server 目录并清理残留临时文件
install_root="$HOME/.antigravity-hub-server"
mkdir -p -- "$install_root/bin" "$install_root/data"
chmod 700 "$install_root"
clean_stale_partials "$install_root"

if [[ "$skip_download" -eq 1 ]]; then
    echo "==> 已跳过 Antigravity Hub Server 二进制预下载（--skip-download）"
    exit 0
fi

# 5. 查询版本元数据并幂等预安装 Hub Server 二进制
echo "==> 查询 Antigravity Hub Server 发布版本信息"
release_line=""
if ! release_line="$(resolve_release_entry "$requested_version")"; then
    if [[ -n "$requested_version" ]]; then
        echo "未找到指定的 Antigravity Hub Server 版本：$requested_version（请检查版本号与代理连通性）。" >&2
    else
        echo "获取 Antigravity Hub Server 发布列表失败，请确认当前终端代理可用。" >&2
    fi
    exit 1
fi

IFS=$'\t' read -r target_version execution_id <<<"$release_line"
validate_version_string "$target_version"
if [[ ! "$execution_id" =~ ^[0-9]{1,64}$ ]]; then
    echo "解析到的构建编号无效：$execution_id" >&2
    exit 1
fi

bin_dir="$install_root/bin/${target_version}-${agy_arch}"
server_bin="$bin_dir/language_server"
mkdir -p -- "$bin_dir"
check_exec_mount "$bin_dir"

if [[ -f "$server_bin" ]] && verify_elf_binary "$server_bin" "$agy_arch"; then
    chmod 755 "$server_bin"
    echo "==> Antigravity Hub Server ${target_version} (${agy_arch}) 已存在且校验通过，跳过下载"
else
    rm -rf -- "$server_bin"
    artifact_url="https://storage.googleapis.com/antigravity-public/antigravity-hub/${target_version}-${execution_id}/unsigned/language_server-linux-${agy_arch}"
    partial_download="$bin_dir/.partial.$$"

    echo "==> 预下载 Antigravity Hub Server ${target_version} (linux-${agy_arch})"
    curl_dl_args=(
        -fL
        --progress-bar
        --retry 3
        --retry-all-errors
        --connect-timeout 20
        --speed-time 30
        --speed-limit 10240
        --proto '=https'
        --proto-redir '=https'
        "$artifact_url"
        -o "$partial_download"
    )
    curl "${curl_dl_args[@]}"

    if ! verify_elf_binary "$partial_download" "$agy_arch"; then
        echo "下载的文件不是有效的 linux-${agy_arch} ELF 可执行文件。" >&2
        exit 1
    fi

    chmod 755 "$partial_download"
    mv -f -- "$partial_download" "$server_bin"
    partial_download=""
    echo "==> 已安装 Antigravity Hub Server：$server_bin"
fi
