#!/bin/bash
# ==============================================================================
# 脚本名称: docker-ca.sh
# 功能:     配置 Docker TLS/SSL 加密通信与安全证书自动续期
# ==============================================================================

set -e

root_need(){
    if [[ $EUID -ne 0 ]]; then
        echo "Error: 这个脚本必须以 root 身份运行!"
        exit 1
    fi
}

root_need

# 管道输入兼容
if [[ ! -t 0 ]] && { true < /dev/tty; } 2>/dev/null; then
    exec < /dev/tty 2>/dev/null || true
fi

# 检查 docker 是否已经安装
if ! command -v docker &> /dev/null; then
    echo "Docker 未安装，开始安装 Docker..."
    curl -fsSL https://get.docker.com | bash
    systemctl enable docker
    docker --version
else
    echo "Docker 已经安装:"
    docker --version
fi

# 获取主机的外网 IP 地址 (多源重试)
get_public_ip() {
    local ip=""
    for service in "https://api.ipify.org" "https://ifconfig.me" "http://ipv4.icanhazip.com"; do
        ip=$(curl -s --connect-timeout 3 --max-time 6 "$service" 2>/dev/null || true)
        if [[ -n "$ip" && "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$ip"
            return
        fi
    done
    echo ""
}

IP=$(get_public_ip)
if [ -z "$IP" ]; then
    echo "警告: 自动获取外网 IP 失败。"
    read -rp "请手动输入当前服务器外网 IP: " IP
    if [ -z "$IP" ]; then
        echo "Error: IP 地址为空，无法生成证书。"
        exit 1
    fi
fi

echo "服务器 IP: $IP"

# 设置证书目录
CERT_DIR="/root/docker-ca"
mkdir -p "$CERT_DIR"

# 生成 CA 证书
openssl genrsa -aes256 -passout pass:changepasswd -out "$CERT_DIR/ca-key.pem" 4096
openssl req -new -x509 -days 3650 -key "$CERT_DIR/ca-key.pem" -passin pass:changepasswd -sha256 -out "$CERT_DIR/ca.pem" \
-subj "/C=CN/ST=State/O=Docker Daemon/CN=$IP"

# 生成服务器证书
openssl genrsa -out "$CERT_DIR/server-key.pem" 4096
openssl req -subj "/CN=$IP" -sha256 -new -key "$CERT_DIR/server-key.pem" -out "$CERT_DIR/server.csr"

# 初始化 subjectAltName
subjectAltName="IP:$IP,IP:127.0.0.1"

# 询问是否添加受信任的域名
read -rp "你想添加一个受信任的域名吗? (y/N): " add_domain
if [[ "$add_domain" =~ ^[yY]$ ]]; then
    read -rp "输入域名: " domain_name
    if [ -n "$domain_name" ]; then
        subjectAltName="DNS:$domain_name,$subjectAltName"
        echo "已将 $domain_name 添加到受信任列表中"
    fi
fi

# 写入 subjectAltName 到 extfile.cnf
echo "subjectAltName = $subjectAltName" > "$CERT_DIR/extfile.cnf"
echo "extendedKeyUsage = serverAuth" >> "$CERT_DIR/extfile.cnf"

# 签名服务器证书
openssl x509 -req -days 3650 -sha256 -in "$CERT_DIR/server.csr" -CA "$CERT_DIR/ca.pem" -CAkey "$CERT_DIR/ca-key.pem" -CAcreateserial -out "$CERT_DIR/server-cert.pem" -extfile "$CERT_DIR/extfile.cnf" -passin pass:changepasswd

# 生成客户端证书
openssl genrsa -out "$CERT_DIR/client-key.pem" 4096
openssl req -subj '/CN=client' -new -key "$CERT_DIR/client-key.pem" -out "$CERT_DIR/client.csr"
echo "extendedKeyUsage = clientAuth" > "$CERT_DIR/client-extfile.cnf"
openssl x509 -req -days 3650 -sha256 -in "$CERT_DIR/client.csr" -CA "$CERT_DIR/ca.pem" -CAkey "$CERT_DIR/ca-key.pem" -CAcreateserial -out "$CERT_DIR/client-cert.pem" -extfile "$CERT_DIR/client-extfile.cnf" -passin pass:changepasswd

# 收紧私钥权限，防止泄露
chmod 0400 "$CERT_DIR"/ca-key.pem "$CERT_DIR"/server-key.pem "$CERT_DIR"/client-key.pem
chmod 0444 "$CERT_DIR"/ca.pem "$CERT_DIR"/server-cert.pem "$CERT_DIR"/client-cert.pem

# 配置 Docker 服务 systemd drop-in
DOCKER_DROPIN_DIR="/etc/systemd/system/docker.service.d"
mkdir -p "$DOCKER_DROPIN_DIR"

cat <<EOF > "$DOCKER_DROPIN_DIR/override.conf"
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock -H tcp://0.0.0.0:2376 --tlsverify --tlscacert=$CERT_DIR/ca.pem --tlscert=$CERT_DIR/server-cert.pem --tlskey=$CERT_DIR/server-key.pem
EOF

# 重新加载 Docker 服务
systemctl daemon-reload
systemctl restart docker

# 检查 Docker 服务是否正常启动
if systemctl is-active --quiet docker; then
   echo "============================================================"
   echo "Docker TLS 配置已经成功完成！"
   echo "监听端口: 2376"
   echo "证书目录: $CERT_DIR"
   echo "客户端连接所需文件: ca.pem, client-cert.pem, client-key.pem"
   echo "============================================================"
else
   echo "Error: docker 服务启动失败。正在恢复默认配置..."
   rm -f "$DOCKER_DROPIN_DIR/override.conf"
   systemctl daemon-reload
   systemctl restart docker
   echo "docker 服务已恢复原始配置。"
   exit 1
fi

# 配置证书自动更新脚本
cat > "$CERT_DIR/renewcert.sh" <<'EOF'
#!/bin/bash
CURRENT_TIME=$(date +"%F %T")
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if openssl x509 -checkend 1728000 -noout -in "$DIR/ca.pem"; then
  echo "[$CURRENT_TIME] CA certificate is still valid" >> "$DIR/crontab_log.txt"
else
  echo "[$CURRENT_TIME] CA certificate has expired or expiring soon. Renewing..." >> "$DIR/crontab_log.txt"
  openssl req -new -x509 -days 3650 -key "$DIR/ca-key.pem" -passin pass:changepasswd -sha256 -out "$DIR/ca.pem" -subj "/C=CN/ST=State/O=Docker Daemon"
  openssl x509 -req -days 3650 -sha256 -in "$DIR/server.csr" -CA "$DIR/ca.pem" -CAkey "$DIR/ca-key.pem" -CAcreateserial -out "$DIR/server-cert.pem" -extfile "$DIR/extfile.cnf" -passin pass:changepasswd
  openssl x509 -req -days 3650 -sha256 -in "$DIR/client.csr" -CA "$DIR/ca.pem" -CAkey "$DIR/ca-key.pem" -CAcreateserial -out "$DIR/client-cert.pem" -extfile "$DIR/client-extfile.cnf" -passin pass:changepasswd
  systemctl restart docker
  echo "[$CURRENT_TIME] All certificates have been renewed" >> "$DIR/crontab_log.txt"
fi
EOF

chmod +x "$CERT_DIR/renewcert.sh"

# 配置定时任务
CRON_JOB="0 0 */15 * * bash $CERT_DIR/renewcert.sh"
if crontab -l 2>/dev/null | grep -Fq "$CERT_DIR/renewcert.sh"; then
    echo "续期定时任务已存在，无需重复添加"
else
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    echo "续期定时任务已添加 (每15天检查一次)"
fi
