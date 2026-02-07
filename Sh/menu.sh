#!/usr/bin/env bash
set -euo pipefail

# =========================================================
# Container-friendly Cloudflare WARP (Proxy Mode) launcher
# - Alpine: 使用 wireproxy + wgcf（官方客户端不支持）
# - Debian/Ubuntu/RHEL: 使用官方 cloudflare-warp
# - 只提供本地 SOCKS5 代理
# =========================================================

VERSION="container-proxy-1.3.6 (升级 wireproxy 到 v1.0.9 + 移除 -v + 日志优化)"

export DEBIAN_FRONTEND=noninteractive

# ---- Config (env overridable) ----
WARP_SOCKS_PORT="${WARP_SOCKS_PORT:-40000}"
WARP_START_DELAY="${WARP_START_DELAY:-10}"
WARP_CONNECT_RETRY="${WARP_CONNECT_RETRY:-10}"
WARP_CONNECT_WAIT="${WARP_CONNECT_WAIT:-60}"
WARP_LOG_FILE="${WARP_LOG_FILE:-/var/log/warp-proxy.log}"
WARP_PID_FILE="${WARP_PID_FILE:-/run/warp-proxy.pid}"

# WireProxy 专用路径
WIREPROXY_CONFIG="/etc/wireproxy.conf"
WGCF_PROFILE="/etc/wgcf-profile.conf"

# ---- Pretty output ----
info()  { echo -e "\033[32;1m[INFO]\033[0m $*"; }
warn()  { echo -e "\033[33;1m[WARN]\033[0m $*"; }
error() { echo -e "\033[31;1m[ERR ]\033[0m $*" >&2; exit 1; }

need_root() {
  [[ "$(id -u)" == "0" ]] || error "请以 root 运行（容器里一般默认就是 root）。"
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

detect_os_and_arch() {
  OS_ID="unknown"
  OS_CODENAME=""
  if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    OS_ID="${ID:-unknown}"
    OS_CODENAME="${VERSION_CODENAME:-}"
  fi

  case "$(uname -m)" in
    x86_64|amd64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *) error "不支持的架构: $(uname -m)" ;;
  esac

  info "检测到系统: ${OS_ID} (${ARCH})"
}

# ==================== Alpine WireProxy 部分 ====================

install_deps_alpine() {
  info "安装 Alpine 依赖（含 Go 用于 wireproxy）..."
  apk add --no-cache ca-certificates curl wget bash iproute2 procps net-tools openssl \
    wireguard-tools go git >/dev/null || error "apk add 依赖失败"
}

download_wgcf() {
  have_cmd wgcf && { info "wgcf 已存在，跳过下载"; return; }
  info "下载 wgcf (固定版本 v2.2.22，有二进制可用)..."

  local filename="wgcf_2.2.22_linux_${ARCH}"
  local url="https://github.com/ViRb3/wgcf/releases/download/v2.2.22/${filename}"

  if ! curl -L -f --connect-timeout 15 -o /usr/local/bin/wgcf "$url"; then
    error "下载 wgcf 失败！URL: $url
请手动下载文件 ${filename} 从 https://github.com/ViRb3/wgcf/releases/tag/v2.2.22"
  fi

  chmod +x /usr/local/bin/wgcf

  if ! wgcf help >/dev/null 2>&1; then
    rm -f /usr/local/bin/wgcf
    error "wgcf 下载的文件无法运行，已删除。请检查架构或手动下载。"
  fi
  info "wgcf 下载并验证成功（v2.2.22）"
}

download_wireproxy() {
  have_cmd wireproxy && { info "wireproxy 已存在，跳过安装"; return; }
  info "使用 go install 安装 wireproxy（pufferffish fork，指定稳定版 v1.0.9）..."

  export GOPATH=/tmp/go
  go install github.com/pufferffish/wireproxy/cmd/wireproxy@v1.0.9 || error "go install wireproxy v1.0.9 失败"

  local bin_path="$GOPATH/bin/wireproxy"
  [[ -f "$bin_path" ]] || bin_path="/root/go/bin/wireproxy"

  if [[ -f "$bin_path" ]]; then
    cp "$bin_path" /usr/local/bin/wireproxy
    chmod +x /usr/local/bin/wireproxy
  else
    error "未找到 wireproxy 二进制"
  fi

  # 验证版本
  local wp_version=$(wireproxy --version 2>/dev/null || echo "未知")
  info "wireproxy 安装成功，版本: $wp_version"
  wireproxy --help >/dev/null 2>&1 || error "wireproxy 验证失败"
}

generate_wgcf_profile() {
  if [[ -f "$WGCF_PROFILE" ]]; then return; fi
  info "注册并生成 WARP WireGuard 配置文件..."
  wgcf register --accept-tos
  wgcf generate
  mv wgcf-profile.conf "$WGCF_PROFILE" 2>/dev/null || cp wgcf-profile.conf "$WGCF_PROFILE"
}

create_wireproxy_config() {
  info "生成 wireproxy 配置文件（端口绑定写在 [Socks5] 段的 BindAddress 中）..."
  local privkey endpoint
  privkey=$(grep '^PrivateKey' "$WGCF_PROFILE" | cut -d' ' -f3 || error "无法从配置文件提取 PrivateKey")
  endpoint=$(grep '^Endpoint' "$WGCF_PROFILE" | cut -d' ' -f3 || error "无法从配置文件提取 Endpoint")

  cat > "$WIREPROXY_CONFIG" <<EOF
[Interface]
PrivateKey = $privkey
Address = 172.16.0.2/32
DNS = 1.1.1.1, 1.0.0.1

[Peer]
PublicKey = bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = $endpoint

[Socks5]
BindAddress = 127.0.0.1:${WARP_SOCKS_PORT}
EOF

  # 验证生成的文件格式
  if ! grep -q "BindAddress = 127.0.0.1:${WARP_SOCKS_PORT}" "$WIREPROXY_CONFIG"; then
    error "配置文件生成失败！BindAddress 格式不对。内容预览：$(head -n 30 "$WIREPROXY_CONFIG")"
  fi
  info "配置文件生成并验证成功"
}

prepare_tun_device() {
  mkdir -p /dev/net || error "无法创建 /dev/net 目录"

  if [[ ! -c /dev/net/tun ]]; then
    info "尝试手动创建 /dev/net/tun 设备节点 (c 10 200)..."
    if mknod /dev/net/tun c 10 200 2>/dev/null; then
      chmod 666 /dev/net/tun
      info "手动创建 /dev/net/tun 成功，权限已设为 666"
    else
      warn "mknod /dev/net/tun 失败（很可能缺少权限）"
      warn "请确保容器启动时添加：--cap-add=NET_ADMIN --device /dev/net/tun"
      warn "或使用 --privileged（测试用，不推荐生产）"
    fi
  else
    info "/dev/net/tun 已存在，当前权限: $(ls -l /dev/net/tun | awk '{print $1}')"
    chmod 666 /dev/net/tun 2>/dev/null || warn "chmod 666 /dev/net/tun 失败（可能权限已足够或受限）"
  fi

  # 关键测试：尝试打开 TUN 设备
  info "测试能否打开 /dev/net/tun ..."
  if exec 3<>/dev/net/tun 2>/dev/null; then
    info "打开 /dev/net/tun 成功（容器有足够权限）"
    exec 3<&-
  else
    error "打开 /dev/net/tun 失败！错误通常为 'Operation not permitted'
请检查 Docker 启动参数，必须包含：
  --cap-add=NET_ADMIN --device /dev/net/tun
否则 wireproxy 无法创建虚拟网卡。"
  fi
}

start_wireproxy_bg() {
  prepare_tun_device

  info "启动 wireproxy (SOCKS5 on 127.0.0.1:${WARP_SOCKS_PORT})..."
  pkill -x wireproxy 2>/dev/null || true
  # 清空旧日志，便于本次调试（可选，根据需求注释掉）
  : > "$WARP_LOG_FILE" 2>/dev/null || true

  # 检查配置文件格式
  if ! grep -q "BindAddress = 127.0.0.1:" "$WIREPROXY_CONFIG"; then
    error "配置文件格式错误：$WIREPROXY_CONFIG 中的 [Socks5] 段缺少端口！
请确保 BindAddress 格式为 '127.0.0.1:端口'（例如 127.0.0.1:40000），而不是单独的 BindAddress 和 BindPort。"
  fi

  # 启动（移除 -v，避免打印版本并退出；后台模式默认日志少，但进程运行正常）
  nohup wireproxy -c "$WIREPROXY_CONFIG" -d >>"$WARP_LOG_FILE" 2>&1 &
  local pid=$!
  echo "$pid" > "$WARP_PID_FILE"
  info "wireproxy 已后台启动，PID: $pid，日志: $WARP_LOG_FILE（后台模式下日志可能为空，这是正常行为）"

  # 多给点时间让它启动和连接
  sleep 8
  tail -n 50 "$WARP_LOG_FILE" || true  # 多打印几行，便于看到连接或错误
}

setup_alpine_warp() {
  install_deps_alpine
  download_wgcf
  download_wireproxy
  generate_wgcf_profile
  create_wireproxy_config
  sleep "$WARP_START_DELAY"
  start_wireproxy_bg

  wait_for_socks5 || error "WireProxy SOCKS5 未启动。请查看 $WARP_LOG_FILE（常见原因：缺少 NET_ADMIN capability 或 TUN 设备权限，或 WireGuard 连接失败）"
  info "Alpine WireProxy SOCKS5 已就绪：socks5h://127.0.0.1:${WARP_SOCKS_PORT}"
  info "测试命令：curl --socks5 127.0.0.1:${WARP_SOCKS_PORT} https://ip.gs"
  info "后台模式日志可能为空，使用 ss/ps 检查运行状态，或 curl 测试实际代理效果"
}

refresh_alpine() {
  info "Alpine 模式刷新 IP..."
  pkill -x wireproxy 2>/dev/null || true
  rm -f "$WGCF_PROFILE" "$WIREPROXY_CONFIG" 2>/dev/null || true
  generate_wgcf_profile
  create_wireproxy_config
  start_wireproxy_bg
  wait_for_socks5 && info "刷新完成" || warn "刷新失败，请查看 $WARP_LOG_FILE"
}

wait_for_socks5() {
  local t=0
  local max="$WARP_CONNECT_WAIT"
  info "等待 SOCKS5 端口 ${WARP_SOCKS_PORT} 监听（最多 ${max}s）..."
  while [ "$t" -lt "$max" ]; do
    if have_cmd ss; then
      if ss -nltp 2>/dev/null | grep -q "127.0.0.1:${WARP_SOCKS_PORT}"; then
        info "SOCKS5 已监听！"
        return 0
      fi
    elif have_cmd netstat; then
      if netstat -tuln 2>/dev/null | grep -q "127.0.0.1:${WARP_SOCKS_PORT}"; then
        info "SOCKS5 已监听！"
        return 0
      fi
    fi
    t=$((t + 1))
    sleep 1
  done
  warn "等待超时（${max}s）。请查看日志："
  tail -n 50 "$WARP_LOG_FILE" || cat "$WARP_LOG_FILE" 2>/dev/null
  return 1
}

# ==================== 原官方部分（Debian/Ubuntu/RHEL） ====================

apt_install_deps() {
  info "安装依赖（apt）..."
  apt update -y >/dev/null
  apt install -y --no-install-recommends \
    ca-certificates curl wget gnupg lsb-release \
    iproute2 procps net-tools openssl >/dev/null
}

yum_install_deps() {
  info "安装依赖（yum/dnf）..."
  (dnf -y install ca-certificates curl wget gnupg2 iproute procps-ng net-tools openssl >/dev/null 2>&1) || \
  (yum -y install ca-certificates curl wget gnupg2 iproute procps-ng net-tools openssl >/dev/null 2>&1) || true
}

install_warp_debian_ubuntu() {
  have_cmd warp-cli && have_cmd warp-svc && { info "已安装 cloudflare-warp，跳过安装"; return; }

  apt_install_deps

  local codename="$OS_CODENAME"
  if [[ -z "$codename" ]]; then
    codename="$(lsb_release -sc 2>/dev/null || true)"
  fi
  [[ -n "$codename" ]] || error "无法获取系统 codename"

  info "添加 Cloudflare WARP APT 源（codename: $codename）..."
  install -d /usr/share/keyrings /etc/apt/sources.list.d
  curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --dearmor -o /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
  cat >/etc/apt/sources.list.d/cloudflare-client.list <<EOF
deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ ${codename} main
EOF

  apt-get update -y >/dev/null
  apt-get install -y cloudflare-warp >/dev/null

  have_cmd warp-cli && have_cmd warp-svc || error "cloudflare-warp 安装失败"
}

install_warp_rhel_like() {
  have_cmd warp-cli && have_cmd warp-svc && { info "已安装 cloudflare-warp，跳过安装"; return; }

  yum_install_deps

  info "添加 Cloudflare WARP YUM/DNF 源..."
  curl -fsSL https://pkg.cloudflareclient.com/cloudflare-warp-ascii.repo | tee /etc/yum.repos.d/cloudflare-warp.repo >/dev/null
  if have_cmd dnf; then dnf -y install cloudflare-warp >/dev/null; else yum -y install cloudflare-warp >/dev/null; fi

  have_cmd warp-cli && have_cmd warp-svc || error "cloudflare-warp 安装失败"
}

install_warp_official() {
  if have_cmd apk; then error "Alpine 不支持官方 warp 客户端"; fi

  if have_cmd apt-get; then install_warp_debian_ubuntu; return; fi
  if have_cmd dnf || have_cmd yum; then install_warp_rhel_like; return; fi
  error "不支持的包管理器（需 apt 或 yum/dnf）"
}

ensure_runtime_dirs() {
  install -d /run/cloudflare-warp /var/lib/cloudflare-warp /var/log
  chmod 755 /run/cloudflare-warp /var/lib/cloudflare-warp /var/log
}

warp_svc_running() {
  if [[ -f "$WARP_PID_FILE" ]]; then
    local pid=$(cat "$WARP_PID_FILE" 2>/dev/null)
    [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null && return 0
  fi
  pgrep -x warp-svc >/dev/null 2>&1
}

start_warp_svc_bg() {
  ensure_runtime_dirs
  if warp_svc_running; then info "warp-svc 已在运行"; return; fi

  info "启动 warp-svc（后台）..."
  if have_cmd setsid; then
    setsid -f warp-svc >>"$WARP_LOG_FILE" 2>&1
  else
    nohup warp-svc >>"$WARP_LOG_FILE" 2>&1 &
  fi
  pgrep -xo warp-svc > "$WARP_PID_FILE" || true
}

wait_for_socket() {
  local t=0
  while (( t < 10 )); do
    [[ -S /run/cloudflare-warp/warp_service ]] && return 0
    sleep 1; ((t++))
  done
  return 1
}

warp_cli_ready() {
  warp-cli --accept-tos status >/dev/null 2>&1
}

configure_and_connect_proxy() {
  info "延迟 ${WARP_START_DELAY}s 后启动..."
  sleep "$WARP_START_DELAY"

  start_warp_svc_bg
  wait_for_socket || error "warp_service socket 未就绪"

  for _ in {1..5}; do warp_cli_ready && break; sleep 1; done

  warp-cli --accept-tos mode proxy >/dev/null 2>&1 || true
  warp-cli --accept-tos proxy port "$WARP_SOCKS_PORT" >/dev/null 2>&1 || true

  local i=1
  while (( i <= WARP_CONNECT_RETRY )); do
    info "尝试 ${i}/${WARP_CONNECT_RETRY}"
    warp-cli --accept-tos disconnect >/dev/null 2>&1 || true
    warp-cli --accept-tos registration delete >/dev/null 2>&1 || true
    rm -f /var/lib/cloudflare-warp/reg.json 2>/dev/null || true
    sleep 1
    warp-cli --accept-tos registration new >/dev/null 2>&1 || true
    warp-cli --accept-tos connect >/dev/null 2>&1 || true

    if wait_for_socks5; then
      info "SOCKS5 已就绪：socks5h://127.0.0.1:${WARP_SOCKS_PORT}"
      warp-cli --accept-tos status 2>/dev/null || true
      return 0
    fi
    sleep 2; ((i++))
  done

  error "启动失败，请查看 $WARP_LOG_FILE"
}

refresh_official() {
  info "官方模式刷新 IP..."
  warp-cli --accept-tos disconnect >/dev/null 2>&1 || true
  warp-cli --accept-tos registration delete >/dev/null 2>&1 || true
  rm -f /var/lib/cloudflare-warp/reg.json 2>/dev/null || true
  sleep 2
  warp-cli --accept-tos registration new >/dev/null 2>&1 || true
  warp-cli --accept-tos connect >/dev/null 2>&1 || true
  wait_for_socks5 && info "刷新完成，检查：curl --socks5 127.0.0.1:${WARP_SOCKS_PORT} https://ip.gs" || warn "刷新失败"
}

# ==================== 公共函数 ====================

status() {
  echo "=== ${VERSION} ==="
  if [[ "$OS_ID" == "alpine" ]]; then
    echo "模式: WireProxy"
    ps aux | grep -E 'wireproxy|${WARP_SOCKS_PORT}' | grep -v grep || echo "未运行"
  else
    echo "模式: Official"
    echo "warp-svc running: $(warp_svc_running && echo YES || echo NO)"
    warp-cli --accept-tos status 2>/dev/null || true
  fi
  echo "SOCKS5: 127.0.0.1:${WARP_SOCKS_PORT}"
  ss -nltp 2>/dev/null | grep "${WARP_SOCKS_PORT}" || true
}

stop_proxy() {
  if [[ "$OS_ID" == "alpine" ]]; then
    pkill -x wireproxy 2>/dev/null || true
  else
    pkill -x warp-svc 2>/dev/null || true
  fi
  rm -f "$WARP_PID_FILE" 2>/dev/null || true
  info "已停止"
}

usage() {
  cat <<EOF
用法:
  $0 c       安装并启动
  $0 s       状态
  $0 o       停止
  $0 r       重启
  $0 refresh 尝试换 IP

环境变量示例: WARP_SOCKS_PORT=1080
EOF
}

# ==================== 主入口 ====================

main() {
  need_root
  detect_os_and_arch
  local opt="${1:-c}"

  if [[ "$OS_ID" == "alpine" ]]; then
    case "$opt" in
      c) setup_alpine_warp ;;
      s) status ;;
      o) stop_proxy ;;
      r) stop_proxy; setup_alpine_warp ;;
      refresh) refresh_alpine ;;
      *) usage; exit 1 ;;
    esac
  else
    case "$opt" in
      c) install_warp_official; configure_and_connect_proxy ;;
      s) status ;;
      o) stop_proxy ;;
      r) stop_proxy; install_warp_official; configure_and_connect_proxy ;;
      refresh) refresh_official ;;
      *) usage; exit 1 ;;
    esac
  fi
}

main "$@"
