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

TMP_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t nat64)"
SERVERS_FILE="$TMP_DIR/nat64_servers.list"
PING_BIN=()

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
  -h, --help             查看本帮助

环境变量:
  PING_COUNT             同 --count，优先级低于命令行
  PING_TIMEOUT           同 --timeout，优先级低于命令行
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

fetch_nat64_xyz() {
    local url="https://raw.githubusercontent.com/level66network/nat64.xyz/refs/heads/main/content/_index.md"
    local added=0
    log_info "抓取 nat64.xyz 列表..."
    if ! while IFS='|' read -r provider location dns64 prefix; do
        [[ -z "$dns64" ]] && continue
        append_entry "$provider" "$location" "$dns64" "$prefix" "nat64.xyz"
        ((added++))
    done < <(
        curl -fsSL "$url" | awk -F'|' '
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
        }'
    ); then
        log_warn "nat64.xyz 拉取失败"
        return 1
    fi
    log_info "nat64.xyz 添加 ${added} 条候选"
    [[ $added -gt 0 ]]
}

fetch_nat64_net() {
    local url="https://nat64.net/public-providers"
    local added=0
    command -v python3 >/dev/null 2>&1 || { log_warn "缺少 python3，跳过 nat64.net"; return 1; }
    log_info "抓取 nat64.net 列表..."
    if ! while IFS='|' read -r provider location dns64 prefix; do
        [[ -z "$dns64" ]] && continue
        append_entry "$provider" "$location" "$dns64" "$prefix" "nat64.net"
        ((added++))
    done < <(
        curl -fsSL "$url" | python3 - <<'PY'
import sys, re, ipaddress
from html.parser import HTMLParser

class TableParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.tables = []
        self._in_table = False
        self._current_table = []
        self._current_row = None
        self._collect = False
        self._cell = []

    def handle_starttag(self, tag, attrs):
        if tag == "table":
            self._in_table = True
            self._current_table = []
        elif tag == "tr" and self._in_table:
            self._current_row = []
        elif tag in ("td", "th") and self._in_table:
            self._collect = True
            self._cell = []

    def handle_data(self, data):
        if self._collect:
            self._cell.append(data.strip())

    def handle_endtag(self, tag):
        if tag in ("td", "th") and self._collect:
            text = " ".join(filter(None, self._cell)).strip()
            text = re.sub(r"\s+", " ", text)
            self._current_row.append(text)
            self._collect = False
        elif tag == "tr" and self._in_table and self._current_row:
            self._current_table.append(self._current_row)
        elif tag == "table" and self._in_table:
            if self._current_table:
                self.tables.append(self._current_table)
            self._in_table = False

parser = TableParser()
parser.feed(sys.stdin.read())

def first_ipv6(text):
    for candidate in re.split(r"[\\s,;/]+", text or ""):
        candidate = candidate.strip("[]()")
        if not candidate:
            continue
        try:
            return str(ipaddress.IPv6Address(candidate))
        except ValueError:
            continue
    return ""

def first_prefix(text):
    for candidate in re.split(r"[\\s,;/]+", text or ""):
        candidate = candidate.strip("[]()")
        if not candidate:
            continue
        try:
            return str(ipaddress.IPv6Network(candidate, strict=False))
        except ValueError:
            continue
    return ""

for table in parser.tables:
    header = [c.lower() for c in table[0]]
    if "provider" in header and "dns64 address" in header:
        idx_provider = header.index("provider")
        idx_location = header.index("location") if "location" in header else None
        idx_dns = header.index("dns64 address")
        idx_prefix = header.index("nat64 prefixes") if "nat64 prefixes" in header else None
        for row in table[1:]:
            if idx_dns >= len(row):
                continue
            provider = row[idx_provider].strip() if idx_provider < len(row) else ""
            location = row[idx_location].strip() if idx_location is not None and idx_location < len(row) else ""
            dns64 = first_ipv6(row[idx_dns])
            prefix = first_prefix(row[idx_prefix]) if idx_prefix is not None and idx_prefix < len(row) else ""
            if provider and dns64:
                print(f"{provider}|{location}|{dns64}|{prefix}")
        break
PY
    ); then
        log_warn "nat64.net 拉取失败"
        return 1
    fi
    log_info "nat64.net 添加 ${added} 条候选"
    [[ $added -gt 0 ]]
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
    awk -F'|' 'NF>=5 && !seen[$3]++' "$SERVERS_FILE" > "$filtered" 2>/dev/null || true
    mv "$filtered" "$SERVERS_FILE"
}

collect_servers() {
    : > "$SERVERS_FILE"
    local success=0
    fetch_nat64_net && ((success++))
    fetch_nat64_xyz && ((success++))
    if [[ ! -s "$SERVERS_FILE" ]]; then
        add_static_fallback
    fi
    deduplicate_servers
    local total
    total=$(grep -c '.' "$SERVERS_FILE" 2>/dev/null || echo 0)
    ((total > 0)) || die "没有可用的候选服务器"
    log_info "共收集 ${total} 台候选 DNS64"
}

ping_latency() {
    local target="$1"
    local output
    if ! output=$("${PING_BIN[@]}" -c "$PING_COUNT" -w "$PING_TIMEOUT" "$target" 2>/dev/null); then
        return 1
    fi
    local latency
    latency=$(awk -F'/' '/(rtt|round-trip)/ {print $5}' <<< "$output")
    [[ -n "$latency" ]] || return 1
    printf '%s\n' "${latency%.*}"
}

select_best_server() {
    local best_line=""
    local best_latency=999999
    while IFS='|' read -r provider location dns64 prefix source; do
        [[ -z "$dns64" ]] && continue
        log_info "测试 ${provider} (${location:-未知}) -> ${dns64}"
        local latency
        if latency=$(ping_latency "$dns64"); then
            log_info "延迟 ${latency} ms (${source})"
            if ((latency < best_latency)); then
                best_latency=$latency
                best_line="$provider|$location|$dns64|$prefix|$source|$latency"
            fi
        else
            log_warn "${dns64} 不可达"
        fi
    done < "$SERVERS_FILE"
    if [[ -z "$best_line" ]]; then
        log_warn "所有候选的 ICMP 测试均失败，按列表顺序返回第一个候选"
        local fallback
        fallback=$(grep -m1 '.' "$SERVERS_FILE" || true)
        [[ -n "$fallback" ]] || return 1
        best_line="${fallback}|未知"
    fi
    printf '%s\n' "$best_line"
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
    local dns64="$1"
    ensure_root
    local backup="/etc/resolv.conf.backup.$(date +%Y%m%d_%H%M%S)"
    if [[ -f /etc/resolv.conf ]]; then
        cp /etc/resolv.conf "$backup"
        log_info "已备份 resolv.conf -> $backup"
    fi
    printf 'nameserver %s\n' "$dns64" > /etc/resolv.conf
    update_systemd_resolved "$dns64"
    log_info "已将系统 DNS 设置为 ${dns64}"
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
    collect_servers

    local best
    if ! best=$(select_best_server); then
        die "所有候选均不可达"
    fi

    IFS='|' read -r provider location dns64 prefix source latency <<< "$best"
    printf '\n'
    log_color "32;01" "[INFO] 最佳 NAT64 服务器："
    log_color "33;01" "提供商: ${provider}"
    log_color "33;01" "地理位置: ${location:-未知}"
    log_color "33;01" "DNS64: ${dns64}"
    log_color "33;01" "NAT64 前缀: ${prefix:-未公布}"
    log_color "33;01" "来源: ${source}"
    log_color "33;01" "平均延迟: ${latency} ms"

    if confirm_or_auto "是否应用该 DNS64？(y/n) "; then
        apply_dns64 "$dns64"
        log_info "配置完成"
    else
        log_warn "已取消配置"
    fi
}

main "$@"
