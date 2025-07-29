#!/bin/bash

# 提示用户确认
echo "此脚本将安装 ipset、iptables-persistent，并配置 Cloudflare 防火墙规则。"
echo "请确保您了解这些操作的含义。"
read -p "您确定要继续安装吗？(y/N): " confirm

if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "安装已取消。"
    exit 0
fi

echo "正在更新软件包列表..."
sudo apt update -y || { echo "apt update 失败，请检查网络连接或源。"; exit 1; }

echo "正在安装 ipset 软件包..."
sudo apt install ipset -y || { echo "ipset 安装失败。"; exit 1; }

echo "正在安装 iptables-persistent 软件包..."
# 在安装 iptables-persistent 时，可能会有交互式提示，这里尝试通过非交互方式处理
sudo DEBIAN_FRONTEND=noninteractive apt install iptables-persistent -y || { echo "iptables-persistent 安装失败。"; exit 1; }

echo "正在启动并启用 netfilter-persistent 服务..."
sudo systemctl enable netfilter-persistent || { echo "启用 netfilter-persistent 失败。"; }
sudo systemctl start netfilter-persistent || { echo "启动 netfilter-persistent 失败。"; }
sudo systemctl status netfilter-persistent --no-pager

echo "正在配置 ipset 的持久化插件..."
PLUGIN_DIR="/usr/share/netfilter-persistent/plugins.d"
PLUGIN_FILE="10-ipset"
PLUGIN_URL="https://raw.githubusercontent.com/freeyoung/netfilter-persistent-plugin-ipset/master/10-ipset"
SOFTLINK_PATH="/usr/sbin/np"

if [ ! -d "$PLUGIN_DIR" ]; then
    echo "创建插件目录 $PLUGIN_DIR..."
    sudo mkdir -p "$PLUGIN_DIR" || { echo "创建目录失败。"; exit 1; }
fi

echo "正在下载 10-ipset 插件脚本..."
sudo wget -O "$PLUGIN_DIR/$PLUGIN_FILE" "$PLUGIN_URL" || { echo "下载 10-ipset 插件失败。"; exit 1; }

echo "正在添加可执行权限给 10-ipset 插件..."
sudo chmod +x "$PLUGIN_DIR/$PLUGIN_FILE" || { echo "添加执行权限失败。"; exit 1; }

echo "正在创建 netfilter-persistent 的软链接 /usr/sbin/np..."
if [ ! -L "$SOFTLINK_PATH" ]; then
    sudo ln -s /usr/sbin/netfilter-persistent "$SOFTLINK_PATH" || { echo "创建软链接失败。"; }
else
    echo "软链接 /usr/sbin/np 已存在，跳过创建。"
fi

echo "正在新建防火墙 ipset 组 cf4 (IPv4) 和 cf6 (IPv6)..."
# 销毁旧的集合，以防万一它们已经存在
sudo ipset destroy cf4 &>/dev/null
sudo ipset destroy cf6 &>/dev/null

sudo ipset create cf4 hash:net || { echo "创建 ipset 集合 cf4 失败。"; exit 1; }
sudo ipset create cf6 hash:net family inet6 || { echo "创建 ipset 集合 cf6 失败。"; exit 1; }

echo "正在获取 Cloudflare IPv4 地址并填入 cf4 组..."
for x in $(curl -s https://www.cloudflare.com/ips-v4); do
    sudo ipset add cf4 $x || echo "添加 IPv4 地址 $x 到 cf4 失败。"
done

echo "正在获取 Cloudflare IPv6 地址并填入 cf6 组..."
for x in $(curl -s https://www.cloudflare.com/ips-v6); do
    sudo ipset add cf6 $x || echo "添加 IPv6 地址 $x 到 cf6 失败。"
done

echo "正在将规则导入防火墙 (iptables/ip6tables)..."
# 检查规则是否已存在，避免重复添加
if ! sudo iptables -C INPUT -m set --match-set cf4 src -p tcp -m multiport --dports http,https -j ACCEPT 2>/dev/null; then
    sudo iptables -A INPUT -m set --match-set cf4 src -p tcp -m multiport --dports http,https -j ACCEPT || { echo "添加 IPv4 iptables 规则失败。"; }
    echo "IPv4 iptables 规则已添加。"
else
    echo "IPv4 iptables 规则已存在，跳过添加。"
fi

if ! sudo ip6tables -C INPUT -m set --match-set cf6 src -p tcp -m multiport --dports http,https -j ACCEPT 2>/dev/null; then
    sudo ip6tables -A INPUT -m set --match-set cf6 src -p tcp -m multiport --dports http,https -j ACCEPT || { echo "添加 IPv6 ip6tables 规则失败。"; }
    echo "IPv6 ip6tables 规则已添加。"
else
    echo "IPv6 ip6tables 规则已存在，跳过添加。"
fi


echo "正在保存当前的 iptables 规则和 ipset 集合内容..."
sudo netfilter-persistent save || { echo "保存 netfilter 规则失败。"; }
echo "所有相关组件已成功安装和配置。"
