#!/bin/bash

# 提示用户确认
echo "此脚本将配置 UFW 防火墙，并允许来自 Cloudflare IP 的 HTTP (80) 和 HTTPS (443) 流量，"
echo "以及开放 SSH (22) 端口。UFW 的默认入站策略将被设置为拒绝 (deny)。"
echo "脚本将不再添加额外的 iptables DROP 规则。"
read -p "您确定要继续配置 UFW 吗？(y/N): " confirm

if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "操作已取消。"
    exit 0
fi

echo "正在检查 UFW 是否已安装..."
if ! command -v ufw &> /dev/null; then
    echo "UFW 未安装。正在安装 UFW..."
    sudo apt update -y || { echo "apt update 失败。"; exit 1; }
    sudo apt install ufw -y || { echo "UFW 安装失败。"; exit 1; }
    echo "UFW 安装完成。"
fi

echo "正在设置 UFW 默认拒绝所有入站连接..."
sudo ufw default deny incoming || { echo "设置 UFW 默认拒绝入站连接失败。"; exit 1; }
echo "UFW 默认入站策略已设置为拒绝。"

# 增加开放 22 端口的规则
echo "正在开放 SSH (22) 端口..."
sudo ufw allow 22/tcp || { echo "开放 22 端口失败。"; }
echo "SSH (22) 端口已开放。"

echo "正在获取 Cloudflare IPv4 地址并添加 UFW 允许规则..."
# 清理之前可能存在的 Cloudflare IPv4 规则，以避免重复添加
# 注意：ufw delete 命令需要明确指定规则，这里不进行全面的清理，
# 而是依赖 ufW 的重复规则处理，或者用户手动清理。
# 为了确保干净，可以先重置UFW，但这会删除所有现有规则。
# sudo ufw reset # 如果需要彻底清理现有规则，请取消注释此行，但请谨慎操作！

CLOUDFLARE_IPS_V4=$(curl -s https://www.cloudflare.com/ips-v4)
if [ -z "$CLOUDFLARE_IPS_V4" ]; then
    echo "警告：无法获取 Cloudflare IPv4 地址，跳过 IPv4 规则添加。"
else
    for ip in $CLOUDFLARE_IPS_V4; do
        echo "  - 允许 IPv4: $ip/80,443"
        sudo ufw allow from "$ip" to any port 80,443 || echo "警告：添加 IPv4 规则失败：$ip"
    done
    echo "Cloudflare IPv4 规则添加完成。"
fi


echo "正在获取 Cloudflare IPv6 地址并添加 UFW 允许规则..."
# 清理之前可能存在的 Cloudflare IPv6 规则
# sudo ufw reset # 如果需要彻底清理现有规则，请取消注释此行，但请谨慎操作！

CLOUDFLARE_IPS_V6=$(curl -s https://www.cloudflare.com/ips-v6)
if [ -z "$CLOUDFLARE_IPS_V6" ]; then
    echo "警告：无法获取 Cloudflare IPv6 地址，跳过 IPv6 规则添加。"
else
    for ip in $CLOUDFLARE_IPS_V6; do
        echo "  - 允许 IPv6: $ip/80,443"
        sudo ufw allow from "$ip" to any port 80,443 || echo "警告：添加 IPv6 规则失败：$ip"
    done
    echo "Cloudflare IPv6 规则添加完成。"
fi

echo "正在启用 UFW 防火墙..."
sudo ufw enable <<EOF
y
EOF
echo "UFW 防火墙已启用。"

# 移除了 iptables DROP 规则的部分


echo "当前 UFW 状态和规则:"
sudo ufw status verbose

echo "UFW 配置和 Cloudflare 规则已成功应用，未添加额外的 iptables DROP 规则。"
