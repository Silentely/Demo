#!/bin/bash
# ==============================================================================
# 脚本名称: install_ufw_cloudflare.sh
# 功能:     配置 UFW 防火墙仅允许 Cloudflare IP 访问 80/443 端口，并放行 SSH 端口
# 作者:     Silentely
# 许可证:   MIT
# ==============================================================================

set -e

AUTO_YES=false
for arg in "$@"; do
    case "$arg" in
        -y|--yes)
            AUTO_YES=true
            ;;
        -h|--help)
            echo "用法: $0 [-y|--yes]"
            echo "功能: 配置 UFW 防火墙，放行当前 SSH 端口，仅允许 Cloudflare IP 访问 80/443 端口"
            exit 0
            ;;
    esac
done

# 管道执行兼容 TTY
if [[ ! -t 0 ]] && { true < /dev/tty; } 2>/dev/null; then
    exec < /dev/tty 2>/dev/null || true
fi

# 获取当前系统实际正在监听或配置的 SSH 端口
detect_ssh_ports() {
    local ports=()

    # 1. 检查 ss / netstat 监听端口
    if command -v ss &>/dev/null; then
        while read -r p; do
            [[ -n "$p" && "$p" =~ ^[0-9]+$ ]] && ports+=("$p")
        done < <(ss -tlpn 2>/dev/null | grep -E 'sshd|ssh' | awk '{print $4}' | awk -F: '{print $NF}' | sort -u)
    fi

    # 2. 检查 sshd_config.d 及 sshd_config
    while read -r p; do
        [[ -n "$p" && "$p" =~ ^[0-9]+$ ]] && ports+=("$p")
    done < <(grep -iE "^\s*Port\s+" /etc/ssh/sshd_config.d/*.conf /etc/ssh/sshd_config 2>/dev/null | grep -v '#' | awk '{print $2}' | sort -u)

    # 3. 兜底默认 22
    ports+=("22")

    # 去重
    echo "${ports[@]}" | tr ' ' '\n' | sort -un | tr '\n' ' '
}

SSH_PORTS=($(detect_ssh_ports))

echo "============================================================"
echo " UFW + Cloudflare IP 白名单配置向导"
echo "============================================================"
echo "此脚本将配置 UFW 防火墙:"
echo "  1. 仅允许来自 Cloudflare IP 的 HTTP (80) 和 HTTPS (443) 流量"
echo "  2. 自动检测并开放 SSH 端口: ${SSH_PORTS[*]} (防止失联)"
echo "  3. UFW 的默认入站策略将被设置为拒绝 (deny)"
echo "============================================================"

if [ "$AUTO_YES" = false ]; then
    read -rp "您确定要继续配置 UFW 吗? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "操作已取消。"
        exit 0
    fi
fi

# 第一步：先验证网络与拉取 Cloudflare 官方 IP 列表，避免断网时将自己锁在外面
echo "正在预先获取 Cloudflare 官方 IP 列表..."
fetch_cmd() {
    local url="$1"
    if command -v curl &>/dev/null; then
        curl -fsSL --connect-timeout 8 --max-time 15 "$url" 2>/dev/null || true
    elif command -v wget &>/dev/null; then
        wget -qO- --timeout=15 "$url" 2>/dev/null || true
    fi
}

CLOUDFLARE_IPS_V4=$(fetch_cmd "https://www.cloudflare.com/ips-v4")
VALID_V4_COUNT=$(echo "$CLOUDFLARE_IPS_V4" | grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}' | wc -l)

if [ "$VALID_V4_COUNT" -eq 0 ]; then
    echo "错误: 无法获取 Cloudflare IPv4 地址列表（网络超时或返回为空）！" >&2
    echo "为防止 80/443 业务被全部误封阻断，脚本已安全终止，未修改防火墙任何规则与状态。" >&2
    exit 1
fi
echo "成功获取 Cloudflare IPv4 地址列表 ($VALID_V4_COUNT 个网段)。"

CLOUDFLARE_IPS_V6=$(fetch_cmd "https://www.cloudflare.com/ips-v6")
VALID_V6_COUNT=$(echo "$CLOUDFLARE_IPS_V6" | grep -E '^[0-9a-fA-F:]+/[0-9]{1,3}' | wc -l)
if [ "$VALID_V6_COUNT" -gt 0 ]; then
    echo "成功获取 Cloudflare IPv6 地址列表 ($VALID_V6_COUNT 个网段)。"
fi

echo "正在检查 UFW 是否已安装..."
if ! command -v ufw &> /dev/null; then
    echo "UFW 未安装。正在安装 UFW..."
    if command -v apt-get &>/dev/null; then
        sudo apt-get update -y
        sudo apt-get install -y ufw
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y ufw
    elif command -v yum &>/dev/null; then
        sudo yum install -y epel-release && sudo yum install -y ufw
    else
        echo "未找到受支持的包管理器，请手动安装 ufw。"
        exit 1
    fi
    echo "UFW 安装完成。"
fi

# 设置默认拒绝规则前，必须先允许 SSH
echo "正在放行检测到的 SSH 端口..."
for p in "${SSH_PORTS[@]}"; do
    echo "  - 放行 SSH 端口: $p/tcp"
    sudo ufw allow "${p}/tcp" comment "SSH Port" || echo "警告: 开放 ${p} 端口失败。"
done

echo "正在设置 UFW 默认拒绝所有入站连接..."
sudo ufw default deny incoming || { echo "设置 UFW 默认拒绝入站连接失败。"; exit 1; }
sudo ufw default allow outgoing || true
echo "UFW 默认策略设置完成。"

echo "正在为 Cloudflare IPv4 地址添加 UFW 允许规则..."
for ip in $CLOUDFLARE_IPS_V4; do
    if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2} ]]; then
        sudo ufw allow from "$ip" to any port 80 proto tcp comment "Cloudflare IPv4" >/dev/null 2>&1 || true
        sudo ufw allow from "$ip" to any port 443 proto tcp comment "Cloudflare IPv4" >/dev/null 2>&1 || true
    fi
done
echo "Cloudflare IPv4 规则添加完成。"

if [ "$VALID_V6_COUNT" -gt 0 ]; then
    echo "正在为 Cloudflare IPv6 地址添加 UFW 允许规则..."
    for ip in $CLOUDFLARE_IPS_V6; do
        if [[ "$ip" =~ ^[0-9a-fA-F:]+/[0-9]{1,3} ]]; then
            sudo ufw allow from "$ip" to any port 80 proto tcp comment "Cloudflare IPv6" >/dev/null 2>&1 || true
            sudo ufw allow from "$ip" to any port 443 proto tcp comment "Cloudflare IPv6" >/dev/null 2>&1 || true
        fi
    done
    echo "Cloudflare IPv6 规则添加完成。"
fi

echo "正在启用 UFW 防火墙..."
sudo ufw --force enable
echo "UFW 防火墙已成功启用。"

echo ""
echo "当前 UFW 状态:"
sudo ufw status verbose
echo "UFW 配置和 Cloudflare 规则已成功应用，SSH 端口 [${SSH_PORTS[*]}] 保持放行。"
