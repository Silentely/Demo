#!/bin/bash

# 提示用户确认
echo "此脚本将卸载 ipset、iptables-persistent 及其所有相关配置和规则。"
echo "这包括删除 cf4 和 cf6 ipset 集合以及使用这些集合的 iptables/ip6tables 规则。"
read -p "您确定要继续吗？(y/N): " confirm

if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "操作已取消。"
    exit 0
fi

echo "正在停止 netfilter-persistent 服务..."
sudo systemctl stop netfilter-persistent
sudo systemctl disable netfilter-persistent

echo "正在删除 iptables/ip6tables 规则..."
# 检查并删除 IPv4 规则
if sudo iptables -C INPUT -m set --match-set cf4 src -p tcp -m multiport --dports http,https -j ACCEPT 2>/dev/null; then
    sudo iptables -D INPUT -m set --match-set cf4 src -p tcp -m multiport --dports http,https -j ACCEPT
    echo "IPv4 规则已删除。"
else
    echo "未找到 IPv4 规则，跳过删除。"
fi

# 检查并删除 IPv6 规则
if sudo ip6tables -C INPUT -m set --match-set cf6 src -p tcp -m multiport --dports http,https -j ACCEPT 2>/dev/null; then
    sudo ip6tables -D INPUT -m set --match-set cf6 src -p tcp -m multiport --dports http,https -j ACCEPT
    echo "IPv6 规则已删除。"
else
    echo "未找到 IPv6 规则，跳过删除。"
fi

echo "正在销毁 ipset 集合..."
# 销毁 cf4 集合
if sudo ipset list cf4 &>/dev/null; then
    sudo ipset destroy cf4
    echo "ipset 集合 cf4 已销毁。"
else
    echo "未找到 ipset 集合 cf4，跳过销毁。"
fi

# 销毁 cf6 集合
if sudo ipset list cf6 &>/dev/null; then
    sudo ipset destroy cf6
    echo "ipset 集合 cf6 已销毁。"
else
    echo "未找到 ipset 集合 cf6，跳过销毁。"
fi

echo "正在保存当前的 iptables 规则（删除后的状态）..."
sudo netfilter-persistent save 2>/dev/null || true # 忽略错误，因为可能 netfilter-persistent 已经被卸载或没有规则

echo "正在卸载 ipset 软件包..."
sudo apt purge ipset -y

echo "正在删除 10-ipset 插件..."
PLUGIN_PATH="/usr/share/netfilter-persistent/plugins.d/10-ipset"
SOFTLINK_PATH="/usr/sbin/np"

if [ -f "$PLUGIN_PATH" ]; then
    sudo rm "$PLUGIN_PATH"
    echo "插件 10-ipset 已删除。"
else
    echo "未找到插件 10-ipset，跳过删除。"
fi

if [ -L "$SOFTLINK_PATH" ]; then
    sudo rm "$SOFTLINK_PATH"
    echo "软链接 /usr/sbin/np 已删除。"
else
    echo "未找到软链接 /usr/sbin/np，跳过删除。"
fi

echo "正在卸载 iptables-persistent 软件包..."
sudo apt purge iptables-persistent -y

echo "清理残留文件..."
sudo apt autoremove -y
sudo apt clean

echo "所有相关组件已成功卸载和清理。"
