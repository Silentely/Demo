#!/usr/bin/env bash
# ==============================================================================
# 脚本名称: uninstall_ipset.sh
# 功能:     卸载 ipset、iptables-persistent 及其配置规则
# ==============================================================================

set -eo pipefail

if [[ ! -t 0 ]] && { true < /dev/tty; } 2>/dev/null; then
    exec < /dev/tty 2>/dev/null || true
fi

ASSUME_YES=false
if [[ "${1:-}" =~ ^(-y|--yes)$ ]]; then
    ASSUME_YES=true
fi

if [[ "$ASSUME_YES" != "true" ]]; then
    echo "此脚本将卸载 ipset、iptables-persistent 及其所有相关配置和规则。"
    echo "这包括删除 cf4 和 cf6 ipset 集合以及使用这些集合的 iptables/ip6tables 规则。"
    read -rp "您确定要继续吗？(y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "操作已取消。"
        exit 0
    fi
fi

echo "正在停止 netfilter-persistent 服务..."
sudo systemctl stop netfilter-persistent 2>/dev/null || true
sudo systemctl disable netfilter-persistent 2>/dev/null || true

echo "正在删除 iptables/ip6tables 规则..."
if sudo iptables -C INPUT -m set --match-set cf4 src -p tcp -m multiport --dports http,https -j ACCEPT 2>/dev/null; then
    sudo iptables -D INPUT -m set --match-set cf4 src -p tcp -m multiport --dports http,https -j ACCEPT 2>/dev/null || true
    echo "IPv4 规则已删除。"
else
    echo "未找到 IPv4 规则，跳过删除。"
fi

if command -v ip6tables &>/dev/null; then
    if sudo ip6tables -C INPUT -m set --match-set cf6 src -p tcp -m multiport --dports http,https -j ACCEPT 2>/dev/null; then
        sudo ip6tables -D INPUT -m set --match-set cf6 src -p tcp -m multiport --dports http,https -j ACCEPT 2>/dev/null || true
        echo "IPv6 规则已删除。"
    else
        echo "未找到 IPv6 规则，跳过删除。"
    fi
fi

echo "正在销毁 ipset 集合..."
if sudo ipset list cf4 &>/dev/null; then
    sudo ipset destroy cf4 2>/dev/null || true
    echo "ipset 集合 cf4 已销毁。"
fi

if sudo ipset list cf6 &>/dev/null; then
    sudo ipset destroy cf6 2>/dev/null || true
    echo "ipset 集合 cf6 已销毁。"
fi

echo "正在保存当前的 iptables 规则..."
sudo netfilter-persistent save 2>/dev/null || true

echo "正在卸载 ipset 与 iptables-persistent 软件包..."
sudo DEBIAN_FRONTEND=noninteractive apt-get purge -y ipset iptables-persistent 2>/dev/null || true

echo "正在删除 10-ipset 插件与软链接..."
sudo rm -f "/usr/share/netfilter-persistent/plugins.d/10-ipset" "/usr/sbin/np"

echo "清理残留文件..."
sudo apt-get autoremove -y 2>/dev/null || true
sudo apt-get clean 2>/dev/null || true

echo "所有相关组件已成功卸载和清理。"
