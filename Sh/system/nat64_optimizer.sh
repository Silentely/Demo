#!/usr/bin/env bash
#
# NAT64/DNS64 自动优选脚本
# version: 2025.11.15

set -euo pipefail
IFS=$'\n\t'

SCRIPT_NAME=$(basename "$0")
SCRIPT_VERSION="2025.11.15"

PING_COUNT=4
PING_TIMEOUT=5
AUTO_APPLY=false
DEBUG=false
CURL_MAX_TIME=${CURL_MAX_TIME:-15}

TMP_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t nat64)"
SERVERS_FILE="$TMP_DIR/nat64_servers.list"
PING_BIN=()
SOURCE_SUCCESS_COUNT=0
LATENCY_PROBES=()
RESOLV_CONF=${RESOLV_CONF:-/etc/resolv.conf}

cleanup() {
    rm -rf "$TMP_DIR"
    stty sane 2>/dev/null || true
}
trap cleanup EXIT INT TERM

log_color() {
    local code="$1"; shift
    printf "\033[%sm%s\033[0m\n" "$code" "$*"
}

log_info() { printf "\033[32;01m[INFO] %s\033[0m\n" "$*" >&2; }
log_warn() { printf "\033[33;01m[WARN] %s\033[0m\n" "$*" >&2; }
log_error() { printf "\033[31;01m[ERROR] %s\033[0m\n" "$*" >&2; }
log_debug() { $DEBUG && printf "\033[35;01m[DEBUG] %s\033[0m\n" "$*" >&2; }

die() {
    log_error "$*"
    exit 1
}

usage() {
    cat <<EOF
用法: $SCRIPT_NAME [选项]

选项:
  -a, --auto-apply       自动应用最佳 DNS64，无需交互
  -c, --count <N>        每台服务器发送的 ping 次数 (默认: ${PING_COUNT})
  -t, --timeout <sec>    ping 命令整体超时秒数 (默认: ${PING_TIMEOUT})
  -d, --debug            启用调试模式，显示详细错误信息
  -h, --help             查看本帮助

环境变量:
  PING_COUNT             同 --count，优先级低于命令行
  PING_TIMEOUT           同 --timeout，优先级低于命令行
  CURL_MAX_TIME          网络请求的超时秒数 (默认: ${CURL_MAX_TIME})
EOF
    exit 0
}

ensure_utf8_locale() {
    local utf8
    utf8=$(locale -a 2>/dev/null | grep -i -m1 -E "UTF-8|utf8" || true)
    if [[ -n "$utf8" ]]; then
        export LC_ALL="$utf8" LANG="$utf8" LANGUAGE="$utf8"
    fi
}

require_cmds() {
    local missing=()
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    [[ ${#missing[@]} -eq 0 ]] || die "缺少依赖: ${missing[*]}"
}

parse_args() {
    PING_COUNT=${PING_COUNT:-4}
    PING_TIMEOUT=${PING_TIMEOUT:-5}

    while (($#)); do
        case "$1" in
            -a|--auto-apply) AUTO_APPLY=true ;;
            -d|--debug) DEBUG=true ;;
            -c|--count)
                [[ -n ${2:-} ]] || die "--count 需要参数"
                [[ $2 =~ ^[0-9]+$ ]] || die "--count 仅接受数字"
                PING_COUNT=$2
                shift
                ;;
            -t|--timeout)
                [[ -n ${2:-} ]] || die "--timeout 需要参数"
                [[ $2 =~ ^[0-9]+$ ]] || die "--timeout 仅接受数字"
                PING_TIMEOUT=$2
                shift
                ;;
            -h|--help) usage ;;
            *)
                die "未知参数: $1"
                ;;
        esac
        shift
    done
}

select_ping_bin() {
    if command -v ping6 >/dev/null 2>&1; then
        PING_BIN=(ping6)
    elif command -v ping >/dev/null 2>&1; then
        PING_BIN=(ping -6)
    else
        die "未找到 ping/ping6 命令"
    fi
}

init_latency_probes() {
    LATENCY_PROBES=()
    command -v ping >/dev/null 2>&1 && LATENCY_PROBES+=("icmp_ping")
    command -v python3 >/dev/null 2>&1 && LATENCY_PROBES+=("tcp53")
    { command -v dig >/dev/null 2>&1 || command -v drill >/dev/null 2>&1; } && LATENCY_PROBES+=("dns_query")
    [[ ${#LATENCY_PROBES[@]} -gt 0 ]] || LATENCY_PROBES=("icmp_ping")
    log_debug "可用延迟探测方法: ${LATENCY_PROBES[*]}"
}

is_ipv6_address() {
    [[ "$1" == *:* ]]
}

format_status_table() {
    local rows="$1"
    printf '┌────────────────────────┬─────┬──────────┐\n'
    printf '│     当前NAT64状态      │     │          │\n'
    printf '├────────────────────────┼─────┼──────────┤\n'
    printf '│ DNS服务器              │状态 │  延迟    │\n'
    printf '├────────────────────────┼─────┼──────────┤\n'
    if [[ -z "$rows" ]]; then
        printf '│ %-22s │  -  │   N/A    │\n' "未配置"
    else
        while IFS='|' read -r dns status latency; do
            [[ -z "$dns" ]] && continue
            printf '│ %-22s │  ' "$dns"
            printf '%b' "$status"
            printf '  │ %-8s │\n' "$latency"
        done <<< "$rows"
    fi
    printf '└────────────────────────┴─────┴──────────┘\n'
}

check_ipv6_connectivity() {
    local target="${1:-2001:4860:4860::64}"
    if ping_latency "$target" >/dev/null 2>&1; then
        printf '\033[32m✓\033[0m 正常'
        return 0
    fi
    printf '\033[31m✗\033[0m 受限'
    return 1
}

detect_nat64_prefix() {
    local resolver="$1" answer tool=()
    [[ -z "$resolver" ]] && return 1
    if command -v dig >/dev/null 2>&1; then
        tool=(dig +tries=1 +time=2 +short @"$resolver" ipv4only.arpa AAAA)
    elif command -v drill >/dev/null 2>&1; then
        tool=(drill -T 2 @"$resolver" ipv4only.arpa AAAA)
    else
        return 1
    fi
    answer=$("${tool[@]}" 2>/dev/null | head -n1 | tr -d '\r')
    [[ "$answer" == *:* ]] || return 1
    command -v python3 >/dev/null 2>&1 || return 1
    python3 - "$answer" <<'PY' 2>/dev/null || return 1
import sys, ipaddress
try:
    addr = ipaddress.IPv6Address(sys.argv[1])
    mask = (1 << 128) - (1 << 32)
    net = ipaddress.IPv6Network((int(addr) & mask, 96))
    print(str(net))
except:
    sys.exit(1)
PY
}

check_current_nat64() {
    local -a nameservers=()
    local table_rows="" first_ipv6=""

    # 读取nameserver
    mapfile -t nameservers < <(awk '/^nameserver/ {print $2}' "$RESOLV_CONF" 2>/dev/null | awk 'NF' | uniq)

    if ((${#nameservers[@]} == 0)); then
        table_rows=$'未配置|\033[33m-\033[0m|N/A\n'
    else
        local ns latency status
        for ns in "${nameservers[@]}"; do
            [[ -z "$ns" ]] && continue
            if is_ipv6_address "$ns"; then
                [[ -z "$first_ipv6" ]] && first_ipv6="$ns"
                if latency=$(ping_latency "$ns" 2>/dev/null); then
                    status=$'\033[32m✓\033[0m'
                    latency="${latency}ms"
                else
                    status=$'\033[31m✗\033[0m'
                    latency="N/A"
                fi
            else
                status=$'\033[33m-\033[0m'
                latency="N/A"
            fi
            table_rows+="${ns}|${status}|${latency}"$'\n'
        done
    fi

    # 显示表格
    printf '\n'
    format_status_table "$table_rows"

    # IPv6连接状态
    local ipv6_status ipv6_ok=true
    if ipv6_status=$(check_ipv6_connectivity); then
        :
    else
        ipv6_ok=false
    fi
    printf "IPv6连接状态: %s\n" "$ipv6_status"

    # NAT64前缀检测
    local prefix_note="未检测" prefix_display="未知"
    if [[ -n "$first_ipv6" ]] && prefix_display=$(detect_nat64_prefix "$first_ipv6"); then
        prefix_note="已检测"
    elif [[ -z "$first_ipv6" ]]; then
        prefix_note="未发现 IPv6 DNS"
    fi
    printf "NAT64前缀: %s (%s)\n\n" "$prefix_display" "$prefix_note"

    # 排障建议
    if [[ -z "$first_ipv6" ]]; then
        log_warn "resolv.conf 中未发现 IPv6 DNS，可能无法直接进行 NAT64 检测"
    fi
    if ! $ipv6_ok; then
        log_warn "IPv6 连接异常，可检查网络或使用 -d 查看更详细日志"
    fi
    if [[ "$prefix_note" == "未检测" ]]; then
        log_warn "无法自动解析 ipv4only.arpa，若需要可手动指定 DNS64。"
    fi
}

append_entry() {
    local provider="$1"
    local location="$2"
    local dns64="$3"
    local prefix="$4"
    local source="$5"

    [[ -z "$provider" || -z "$dns64" ]] && return
    printf '%s|%s|%s|%s|%s\n' \
        "$provider" "$location" "$dns64" "$prefix" "$source" >> "$SERVERS_FILE"
}

fetch_with_timeout() {
    local url="$1"
    local output error_msg
    if $DEBUG; then
        output=$(curl -fsSL --max-time "$CURL_MAX_TIME" "$url" 2>&1)
        local ret=$?
        if [[ $ret -ne 0 ]]; then
            log_debug "curl 失败 (退出码: $ret): $url"
            log_debug "错误信息: $output"
            return $ret
        fi
        echo "$output"
    else
        curl -fsSL --max-time "$CURL_MAX_TIME" "$url"
    fi
}

fetch_nat64_xyz() {
    local url="https://raw.githubusercontent.com/level66network/nat64.xyz/refs/heads/main/content/_index.md"
    log_info "抓取 nat64.xyz 列表..."
    log_debug "请求 URL: $url"
    local tmp_output
    tmp_output=$(fetch_with_timeout "$url" 2>&1) || {
        log_warn "nat64.xyz 拉取失败"
        log_debug "返回内容: $tmp_output"
        return 1
    }
    log_debug "成功获取 nat64.xyz 数据，长度: ${#tmp_output} 字节"
    local added=0
    while IFS='|' read -r provider location dns64 prefix; do
        [[ -z "$dns64" ]] && continue
        append_entry "$provider" "$location" "$dns64" "$prefix" "nat64.xyz"
        ((added++))
    done < <(echo "$tmp_output" | awk -F'|' '
        /\|.*\|.*\|/ {
            if ($0 !~ /Provider.*Country.*DNS64/) {
                provider = $2
                location = $3
                dns64 = $4
                prefix = $5
                while (match(dns64, /[0-9a-fA-F:]+::[0-9a-fA-F:]*[0-9a-fA-F]+/)) {
                    ip = substr(dns64, RSTART, RLENGTH)
                    dns64 = substr(dns64, RSTART + RLENGTH)
                    if (match(prefix, /[0-9a-fA-F:]+::[0-9a-fA-F:]*\/[0-9]+/)) {
                        nat64prefix = substr(prefix, RSTART, RLENGTH)
                        gsub(/^[[:space:]]+|[[:space:]]+$/, "", ip)
                        gsub(/^[[:space:]]+|[[:space:]]+$/, "", nat64prefix)
                    } else {
                        nat64prefix = ""
                    }
                    gsub(/^[[:space:]]+|[[:space:]]+$/, "", provider)
                    gsub(/^[[:space:]]+|[[:space:]]+$/, "", location)
                    if (ip != "") {
                        print provider "|" location "|" ip "|" nat64prefix
                    }
                }
            }
        }')
    if ((added == 0)); then
        log_warn "nat64.xyz 未解析到任何候选"
        return 1
    fi
    log_info "nat64.xyz 添加 ${added} 条候选"
    return 0
}

fetch_nat64_net() {
    local url="https://nat64.net/public-providers"
    log_info "抓取 nat64.net 列表..."
    log_debug "请求 URL: $url"
    local tmp_output
    tmp_output=$(fetch_with_timeout "$url" 2>&1) || {
        log_warn "nat64.net 拉取失败"
        log_debug "返回内容: $tmp_output"
        return 1
    }
    log_debug "成功获取 nat64.net 数据，长度: ${#tmp_output} 字节"
    local added=0
    while IFS='|' read -r provider location dns64 prefix; do
        [[ -z "$dns64" ]] && continue
        log_debug "解析到: $provider | $location | $dns64 | $prefix"
        append_entry "$provider" "$location" "$dns64" "$prefix" "nat64.net"
        ((added++))
    done < <(echo "$tmp_output" | awk '
    BEGIN { in_second_table = 0; col = 0 }
    /<table border="1">/ { table_count++; if (table_count == 2) in_second_table = 1 }
    /<\/table>/ { if (in_second_table) in_second_table = 0 }
    in_second_table && /<tr>/ { col = 0; provider = ""; location = ""; dns64 = ""; prefix = "" }
    in_second_table && /<td>/ {
        col++
        content = $0
        gsub(/.*<td>/, "", content)
        gsub(/<\/td>.*/, "", content)
        gsub(/<[^>]*>/, "", content)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", content)

        if (col == 1) provider = content
        else if (col == 2) location = content
        else if (col == 3 && content ~ /[0-9a-fA-F:]+::[0-9a-fA-F:]*/) dns64 = content
        else if (col == 4) prefix = content
    }
    in_second_table && /<\/tr>/ {
        if (provider != "" && dns64 != "" && provider != "Provider") {
            print provider "|" location "|" dns64 "|" prefix
        }
    }')
    log_debug "nat64.net 共解析 ${added} 条"
    if ((added == 0)); then
        log_warn "nat64.net 未解析到任何候选"
        return 1
    fi
    log_info "nat64.net 添加 ${added} 条候选"
    return 0
}

run_source() {
    local fetch_fn="$1"
    local label="$2"

    if [[ -z "$fetch_fn" || -z "$label" ]]; then
        log_warn "run_source 参数不足"
        return 1
    fi

    if ! declare -F "$fetch_fn" >/dev/null; then
        log_warn "run_source: 未知数据源函数 $fetch_fn"
        return 1
    fi

    if "$fetch_fn"; then
        ((++SOURCE_SUCCESS_COUNT))
        log_debug "$label 数据源加载成功"
        return 0
    fi

    log_warn "$label 数据源不可用"
    return 1
}

fetch_static_public_list() {
    local added=0
    log_info "添加公开 DNS64 列表..."
    while IFS='|' read -r provider location dns64 prefix; do
        [[ -z "$dns64" ]] && continue
        append_entry "$provider" "$location" "$dns64" "$prefix" "static"
        ((added++))
    done <<'EOF'
nat64.net|Amsterdam|2a00:1098:2b::1|2a00:1098:2b::/96
nat64.net|Ashburn|2a01:4ff:f0:9876::1|2a01:4f9:c010:3f02:64::/96
nat64.net|Helsinki|2a01:4f9:c010:3f02::1|2a01:4f9:c010:3f02:64::/96
nat64.net|London|2a00:1098:2c::1|2a00:1098:2c::/96
nat64.net|Nuremberg|2a01:4f8:c2c:123f::1|2a01:4f8:c2c:123f:64::/96
IPng|Amsterdam|2a02:898::146:1|
Trex|Tampere|2001:67c:2b0::4|2001:67c:2b0:db32:0:1::/96
Trex|Tampere|2001:67c:2b0::6|2001:67c:2b0:db32:0:1::/96
level66|Germany|2001:67c:2960::64|2001:67c:2960:6464::/96
level66|Germany|2001:67c:2960::6464|2001:67c:2960:6464::/96
level66|Germany|2001:67c:2960:5353:5353:5353:5353:5353|2a09:11c0:f1:be00::/96
level66|Germany|2001:67c:2960:6464:6464:6464:6464:6464|2a09:11c0:f1:be00::/96
Christian Dresel|Germany|2a0b:f4c0:4d:53::1|2a0b:f4c0:4d:1::/96
Christian Dresel|Germany|2a01:4f8:221:2d08::213|2a01:4f8:221:2d08:64:0::/96
go6Labs|Slovenia|2001:67c:27e4:15::6411|2001:67c:27e4:642::/96
go6Labs|Slovenia|2001:67c:27e4::64|2001:67c:27e4:64::/96
go6Labs|Slovenia|2001:67c:27e4:15::64|2001:67c:27e4:1064::/96
go6Labs|Slovenia|2001:67c:27e4::60|2001:67c:27e4:11::/96
Tuxis|Netherlands|2a03:7900:2:0:31:3:104:161|2a03:7900:6446::/96
Cloudflare|Global|2606:4700:4700::6400|
Cloudflare|Global|2606:4700:4700::64|
Google|Global|2001:4860:4860::64|
Google|Global|2001:4860:4860::6464|
EOF
    if ((added == 0)); then
        log_warn "静态列表未添加任何候选"
        return 1
    fi
    log_info "静态列表添加 ${added} 条候选"
    return 0
}

add_static_fallback() {
    log_warn "远程源不可用，使用内置候选"
    append_entry "nat64.net" "Amsterdam" "2a00:1098:2b::1" "2a00:1098:2b::/96" "fallback"
    append_entry "nat64.net" "Ashburn" "2a01:4ff:f0:9876::1" "2a01:4f9:c010:3f02:64::/96" "fallback"
    append_entry "nat64.net" "Helsinki" "2a01:4f9:c010:3f02::1" "2a01:4f9:c010:3f02:64::/96" "fallback"
    append_entry "level66.services" "Germany" "2001:67c:2960::64" "2001:67c:2960:6464::/96" "fallback"
    append_entry "level66.services" "Germany" "2001:67c:2960::6464" "2001:67c:2960:6464::/96" "fallback"
    append_entry "Trex" "Tampere" "2001:67c:2b0::4" "2001:67c:2b0:db32:0:1::/96" "fallback"
    append_entry "Trex" "Tampere" "2001:67c:2b0::6" "2001:67c:2b0:db32:0:1::/96" "fallback"
    append_entry "ZTVI.org" "Chicago" "2602:fc59:11:1::64" "2602:fc59:11:64::/96" "fallback"
    append_entry "ZTVI.org" "Fremont" "2602:fc59:b0:9e::64" "2602:fc59:b0:64::/96" "fallback"
}

deduplicate_servers() {
    local filtered="$TMP_DIR/nat64_servers.filtered"
    log_debug "去重前记录数: $(wc -l < "$SERVERS_FILE")"
    awk -F'|' 'NF>=5 && !seen[$3]++ {
        print
    }' "$SERVERS_FILE" > "$filtered"
    if $DEBUG; then
        awk -F'|' '{print "[DEBUG] 保留: " $3}' "$filtered" >&2
    fi
    mv "$filtered" "$SERVERS_FILE"
    log_debug "去重后记录数: $(wc -l < "$SERVERS_FILE")"
}

select_sources() {
    {
        printf '\n'
        log_color "36;01" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_color "36;01" "  DNS64 数据源选择"
        log_color "36;01" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        printf "\033[32m  1)\033[0m 全部数据源 \033[33m(推荐)\033[0m\n"
        printf "\033[32m  2)\033[0m 仅 nat64.net\n"
        printf "\033[32m  3)\033[0m 仅 nat64.xyz\n"
        printf "\033[32m  4)\033[0m 仅静态公开列表\n"
        printf "\033[32m  5)\033[0m nat64.net + nat64.xyz\n"
        printf "\033[32m  6)\033[0m nat64.net + 静态列表\n"
        log_color "36;01" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    } >&2
    local choice
    read -rp "$(printf '\033[36;01m请选择 [1-6] (默认: 1): \033[0m')" choice </dev/tty 2>/dev/null || choice=""
    choice=${choice:-1}
    echo "$choice"
}

collect_servers() {
    : > "$SERVERS_FILE"
    local choice
    choice=$(select_sources)
    SOURCE_SUCCESS_COUNT=0

    case "$choice" in
        1)
            run_source fetch_nat64_net "nat64.net"
            run_source fetch_nat64_xyz "nat64.xyz"
            run_source fetch_static_public_list "静态列表"
            ;;
        2) run_source fetch_nat64_net "nat64.net" ;;
        3) run_source fetch_nat64_xyz "nat64.xyz" ;;
        4) run_source fetch_static_public_list "静态列表" ;;
        5)
            run_source fetch_nat64_net "nat64.net"
            run_source fetch_nat64_xyz "nat64.xyz"
            ;;
        6)
            run_source fetch_nat64_net "nat64.net"
            run_source fetch_static_public_list "静态列表"
            ;;
        *) die "无效选择" ;;
    esac

    if [[ ! -s "$SERVERS_FILE" ]]; then
        add_static_fallback
    fi
    deduplicate_servers
    local total
    total=$(grep -c '.' "$SERVERS_FILE" 2>/dev/null || echo 0)
    ((total > 0)) || die "没有可用的候选服务器"
    log_info "共收集 ${total} 台候选 DNS64"
    log_info "成功加载 ${SOURCE_SUCCESS_COUNT} 个数据源"
}

probe_icmp_ping() {
    local target="$1" os timeout_flag=() cmd=("${PING_BIN[@]}")
    os=$(uname -s)
    [[ ${#cmd[@]} -eq 0 ]] && cmd=(ping)
    if [[ "$os" == "Darwin" ]]; then
        # macOS ping6 不支持 -W，使用 -t 设置超时（秒）
        timeout_flag=(-t "$PING_TIMEOUT")
        [[ ${cmd[0]} == "ping6" ]] || cmd=(ping6)
    else
        # Linux ping 使用 -w 设置整体超时（秒）
        timeout_flag=(-w "$PING_TIMEOUT")
    fi
    local output
    if ! output=$("${cmd[@]}" -n -c "$PING_COUNT" "${timeout_flag[@]}" "$target" 2>&1); then
        echo "$output" >&2
        return 1
    fi
    awk -F'[=/ ]+' '/(rtt|min\/avg|round-trip)/ {printf "%.0f\n", $(NF-2); exit}' <<< "$output"
}

probe_tcp53() {
    local target="$1"
    python3 - "$target" "$PING_TIMEOUT" <<'PY' 2>&1 || return 1
import socket, sys, time
try:
    dst = sys.argv[1]
    timeout = int(sys.argv[2])
    sock = socket.socket(socket.AF_INET6, socket.SOCK_STREAM)
    sock.settimeout(timeout)
    start = time.time()
    sock.connect((dst, 53))
    print(int((time.time() - start) * 1000))
    sock.close()
except Exception as e:
    print(f"TCP53 error: {e}", file=sys.stderr)
    sys.exit(1)
PY
}

probe_dns_query() {
    local target="$1" tool=() output latency
    if command -v dig >/dev/null 2>&1; then
        tool=(dig +tries=1 +time="$PING_TIMEOUT" +stats @"$target" ipv4only.arpa AAAA)
    else
        tool=(drill -T "$PING_TIMEOUT" @"$target" ipv4only.arpa AAAA)
    fi
    output=$("${tool[@]}" 2>&1) || {
        echo "$output" >&2
        return 1
    }
    latency=$(awk '/Query time:/ {print $4}' <<< "$output")
    [[ -n "$latency" ]] || {
        echo "DNS query: 无法解析延迟信息" >&2
        return 1
    }
    printf '%s\n' "$latency"
}

ping_latency() {
    local target="$1" method raw status
    for method in "${LATENCY_PROBES[@]}"; do
        log_debug "尝试使用 ${method} 探测 ${target}..."
        raw=$(probe_"${method}" "$target" 2>&1)
        status=$?
        if [[ $status -eq 0 && -n "$raw" ]]; then
            log_info "✓ 使用 ${method} 探测成功: ${raw} ms"
            printf '%s\n' "${raw%.*}"
            return 0
        fi
        log_debug "✗ ${method} 探测失败 (exit=${status}): ${raw:-<无输出>}"
    done
    log_warn "所有探测方法均失败: ${target}"
    return 1
}

select_best_servers() {
    local results_file="$TMP_DIR/results.list"
    : > "$results_file"

    while IFS='|' read -r provider location dns64 prefix source; do
        [[ -z "$dns64" ]] && continue
        log_info "测试 ${provider} (${location:-未知}) -> ${dns64}"
        local latency
        if latency=$(ping_latency "$dns64"); then
            log_info "延迟 ${latency} ms (${source})"
            printf '%s|%s|%s|%s|%s|%s\n' "$latency" "$provider" "$location" "$dns64" "$prefix" "$source" >> "$results_file"
        else
            log_warn "${dns64} 不可达"
        fi
    done < "$SERVERS_FILE"

    if [[ ! -s "$results_file" ]]; then
        log_warn "所有候选的延迟探测方法均失败，按列表顺序返回前两个候选"
        log_warn "提示: 请检查网络连接、防火墙设置或使用 -d 查看详细日志"
        local count=0
        while IFS='|' read -r provider location dns64 prefix source && ((count < 2)); do
            printf '999999|%s|%s|%s|%s|%s\n' "$provider" "$location" "$dns64" "$prefix" "$source"
            ((count++))
        done < "$SERVERS_FILE"
        return 0
    fi

    sort -t'|' -k1 -n "$results_file" | head -2 | awk -F'|' '{print $2"|"$3"|"$4"|"$5"|"$6"|"$1}'
}

ensure_root() {
    [[ $EUID -eq 0 ]] || die "需要 root 权限才能写入 /etc/resolv.conf"
}

update_systemd_resolved() {
    local dns="$1"
    local resolved="/etc/systemd/resolved.conf"
    [[ -f "$resolved" ]] || return 0
    local tmp="${resolved}.nat64tmp"
    awk -v dns="$dns" '
        BEGIN { replaced = 0 }
        /^DNS=/ {
            if (!replaced) {
                print "DNS=" dns
                replaced = 1
            }
            next
        }
        { print }
        END {
            if (!replaced) {
                print "DNS=" dns
            }
        }
    ' "$resolved" > "$tmp"
    mv "$tmp" "$resolved"
    if command -v systemctl >/dev/null 2>&1; then
        systemctl restart systemd-resolved || log_warn "systemd-resolved 重启失败"
    fi
}

apply_dns64() {
    local dns64_1="$1"
    local dns64_2="$2"
    ensure_root
    local backup="/etc/resolv.conf.backup.$(date +%Y%m%d_%H%M%S)"
    if [[ -f /etc/resolv.conf ]]; then
        cp /etc/resolv.conf "$backup"
        log_info "已备份 resolv.conf -> $backup"
    fi
    {
        printf 'nameserver %s\n' "$dns64_1"
        [[ -n "$dns64_2" ]] && printf 'nameserver %s\n' "$dns64_2"
    } > /etc/resolv.conf
    update_systemd_resolved "$dns64_1"
    log_info "已将系统 DNS 设置为 ${dns64_1}${dns64_2:+ 和 ${dns64_2}}"
}

confirm_or_auto() {
    local prompt="$1"
    $AUTO_APPLY && return 0
    local answer
    read -rp "$(printf "\033[32m\033[01m%s\033[0m" "$prompt")" answer
    [[ $answer =~ ^[Yy] ]]
}

main() {
    parse_args "$@"
    ensure_utf8_locale
    require_cmds curl awk
    select_ping_bin
    init_latency_probes
    check_current_nat64
    collect_servers

    local results
    if ! results=$(select_best_servers); then
        die "所有候选均不可达"
    fi

    local count=0
    local dns64_1="" dns64_2=""
    local provider1="" location1="" prefix1="" source1="" latency1=""
    local provider2="" location2="" prefix2="" source2="" latency2=""

    while IFS='|' read -r provider location dns64 prefix source latency; do
        ((count++))
        if ((count == 1)); then
            provider1="$provider" location1="$location" dns64_1="$dns64"
            prefix1="$prefix" source1="$source" latency1="$latency"
        elif ((count == 2)); then
            provider2="$provider" location2="$location" dns64_2="$dns64"
            prefix2="$prefix" source2="$source" latency2="$latency"
            break
        fi
    done <<< "$results"

    printf '\n'
    log_color "36;01" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_color "32;01" "  ✓ 最佳 NAT64 服务器"
    log_color "36;01" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf "\033[33m  主DNS:\033[0m \033[32m${provider1}\033[0m (${location1:-未知})\n"
    printf "         \033[36m${dns64_1}\033[0m - \033[35m${latency1} ms\033[0m\n"
    if [[ -n "$dns64_2" ]]; then
        printf "\033[33m  备DNS:\033[0m \033[32m${provider2}\033[0m (${location2:-未知})\n"
        printf "         \033[36m${dns64_2}\033[0m - \033[35m${latency2} ms\033[0m\n"
    fi
    log_color "36;01" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if confirm_or_auto "是否应用这些 DNS64？[y/N] "; then
        apply_dns64 "$dns64_1" "$dns64_2"
        log_info "配置完成"
    else
        log_warn "已取消配置"
    fi
}

main "$@"
