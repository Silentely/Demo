#!/usr/bin/env bash
# ==============================================================================
# 脚本名称: install_ipset.sh
# 功能:     安装 ipset、iptables-persistent，并配置 Cloudflare 白名单持久化规则
# ==============================================================================

set -eo pipefail

# 管道输入兼容
if [[ ! -t 0 ]] && { true < /dev/tty; } 2>/dev/null; then
    exec < /dev/tty 2>/dev/null || true
fi

ASSUME_YES=false
if [[ "${1:-}" =~ ^(-y|--yes)$ ]]; then
    ASSUME_YES=true
fi

if [[ "$ASSUME_YES" != "true" ]]; then
    echo "此脚本将安装 ipset、iptables-persistent，并配置 Cloudflare 防火墙规则。"
    echo "请确保您了解这些操作的含义。"
    read -rp "您确定要继续安装吗？(y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "安装已取消。"
        exit 0
    fi
fi

echo "正在更新软件包列表..."
sudo apt-get update -y || { echo "apt update 失败，请检查网络连接或源。"; exit 1; }

echo "正在安装 ipset 与 iptables-persistent 软件包..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ipset iptables-persistent curl ca-certificates || {
    echo "软件包安装失败。"; exit 1;
}

echo "正在启动并启用 netfilter-persistent 服务..."
sudo systemctl enable netfilter-persistent || true
sudo systemctl start netfilter-persistent || true

echo "正在配置 ipset 的持久化插件..."
PLUGIN_DIR="/usr/share/netfilter-persistent/plugins.d"
PLUGIN_FILE="10-ipset"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_PLUGIN="${SCRIPT_DIR}/10-ipset"
PLUGIN_URL="https://raw.githubusercontent.com/freeyoung/netfilter-persistent-plugin-ipset/master/10-ipset"
SOFTLINK_PATH="/usr/sbin/np"

if [ ! -d "$PLUGIN_DIR" ]; then
    echo "创建插件目录 $PLUGIN_DIR..."
    sudo mkdir -p "$PLUGIN_DIR" || { echo "创建目录失败。"; exit 1; }
fi

if [ -f "$LOCAL_PLUGIN" ]; then
    echo "发现本地插件 $LOCAL_PLUGIN，正在复制..."
    sudo cp "$LOCAL_PLUGIN" "$PLUGIN_DIR/$PLUGIN_FILE"
else
    echo "正在下载 10-ipset 插件脚本..."
    if command -v curl &>/dev/null; then
        sudo curl -fsSL -o "$PLUGIN_DIR/$PLUGIN_FILE" "$PLUGIN_URL" || true
    fi
    if [ ! -s "$PLUGIN_DIR/$PLUGIN_FILE" ] && command -v wget &>/dev/null; then
        sudo wget -q -O "$PLUGIN_DIR/$PLUGIN_FILE" "$PLUGIN_URL" || true
    fi
fi

if [ ! -s "$PLUGIN_DIR/$PLUGIN_FILE" ]; then
    echo "10-ipset 插件准备失败，请检查网络。"
    exit 1
fi

sudo chmod +x "$PLUGIN_DIR/$PLUGIN_FILE"

echo "正在创建 netfilter-persistent 的软链接 /usr/sbin/np..."
if [ ! -e "$SOFTLINK_PATH" ]; then
    sudo ln -s /usr/sbin/netfilter-persistent "$SOFTLINK_PATH" 2>/dev/null || true
fi

echo "正在新建防火墙 ipset 组 cf4 (IPv4) 和 cf6 (IPv6)..."
sudo ipset create cf4 hash:net -exist
sudo ipset create cf6 hash:net family inet6 -exist

echo "正在获取 Cloudflare IPv4 地址并填入 cf4 组..."
cf_ipv4=$(curl -s --connect-timeout 5 --max-time 15 https://www.cloudflare.com/ips-v4 || true)
if [ -n "$cf_ipv4" ]; then
    for x in $cf_ipv4; do
        sudo ipset add cf4 "$x" -exist 2>/dev/null || true
    done
else
    echo "警告：无法获取 Cloudflare IPv4 列表，请检查网络"
fi

echo "正在获取 Cloudflare IPv6 地址并填入 cf6 组..."
cf_ipv6=$(curl -s --connect-timeout 5 --max-time 15 https://www.cloudflare.com/ips-v6 || true)
if [ -n "$cf_ipv6" ]; then
    for x in $cf_ipv6; do
        sudo ipset add cf6 "$x" -exist 2>/dev/null || true
    done
fi

echo "正在将规则导入防火墙 (iptables/ip6tables)..."
if ! sudo iptables -C INPUT -m set --match-set cf4 src -p tcp -m multiport --dports http,https -j ACCEPT 2>/dev/null; then
    sudo iptables -A INPUT -m set --match-set cf4 src -p tcp -m multiport --dports http,https -j ACCEPT || true
fi

if command -v ip6tables &>/dev/null; then
    if ! sudo ip6tables -C INPUT -m set --match-set cf6 src -p tcp -m multiport --dports http,https -j ACCEPT 2>/dev/null; then
        sudo ip6tables -A INPUT -m set --match-set cf6 src -p tcp -m multiport --dports http,https -j ACCEPT || true
    fi
fi

echo "正在保存当前的 iptables 规则和 ipset 集合内容..."
sudo netfilter-persistent save || true
echo "所有相关组件已成功安装和配置。"
