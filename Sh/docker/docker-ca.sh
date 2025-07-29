#!/bin/bash

root_need(){
    if [[ $EUID -ne 0 ]]; then
        echo "Error:这个脚本必须以root身份运行!"
        exit 1
    fi
}

# 检查docker是否已经安装
if ! command -v docker &> /dev/null
then
    echo "Docker未安装，开始安装Docker..."
    # 安装Docker
    wget -qO- get.docker.com | bash
    systemctl enable docker
    # 输出安装结果
    docker --version
else
    echo "Docker已经安装"
    # 输出Docker版本
    docker --version
fi

# 获取主机的 IP 地址
IP=$(curl -s http://ipv4.icanhazip.com)

# 设置证书目录
CERT_DIR="/root/docker-ca"
mkdir -p "$CERT_DIR"

# 生成 CA 证书
openssl genrsa -aes256 -passout pass:changepasswd -out "$CERT_DIR/ca-key.pem" 4096
openssl req -new -x509 -days 365 -key "$CERT_DIR/ca-key.pem" -passin pass:changepasswd -sha256 -out "$CERT_DIR/ca.pem" \
-subj "/C=AU/ST=Some-State/O=Internet Widgits Pty Ltd"

# 生成服务器证书
openssl genrsa -out "$CERT_DIR/server-key.pem" 4096
openssl req -subj "/CN=$IP" -sha256 -new -key "$CERT_DIR/server-key.pem" -out "$CERT_DIR/server.csr"

# 确保 subjectAltName 不为空
if [ -z "$IP" ]; then
    echo "Error: IP 地址为空，无法继续生成证书。"
    exit 1
fi

# 初始化 subjectAltName
subjectAltName="IP:$IP"

# 询问是否添加受信任的域名
read -p "你想添加一个受信任的域名吗? (y/n): " add_domain
if [ "$add_domain" == "y" ]; then
    read -p "输入域名: " domain_name
    subjectAltName="DNS:$domain_name,$subjectAltName"
    echo "将$domain_name添加到受信任域列表中"
else
    echo "跳过将域添加到受信任域列表的步骤"
fi

# 写入 subjectAltName 到 extfile.cnf
echo "subjectAltName = $subjectAltName" > "$CERT_DIR/extfile.cnf"
echo "extendedKeyUsage = serverAuth" >> "$CERT_DIR/extfile.cnf"

# 生成服务器证书
openssl x509 -req -days 365 -sha256 -in "$CERT_DIR/server.csr" -CA "$CERT_DIR/ca.pem" -CAkey "$CERT_DIR/ca-key.pem" -CAcreateserial -out "$CERT_DIR/server-cert.pem" -extfile "$CERT_DIR/extfile.cnf" -passin pass:changepasswd

# 生成客户端证书
openssl genrsa -out "$CERT_DIR/client-key.pem" 4096
openssl req -subj '/CN=client' -new -key "$CERT_DIR/client-key.pem" -out "$CERT_DIR/client.csr"
echo "extendedKeyUsage = clientAuth" > "$CERT_DIR/client-extfile.cnf"
openssl x509 -req -days 365 -sha256 -in "$CERT_DIR/client.csr" -CA "$CERT_DIR/ca.pem" -CAkey "$CERT_DIR/ca-key.pem" -CAcreateserial -out "$CERT_DIR/client-cert.pem" -extfile "$CERT_DIR/client-extfile.cnf" -passin pass:changepasswd

# 配置 Docker 使用 TLS
DOCKER_SERVICE_FILE="/lib/systemd/system/docker.service"
if [ -f "$DOCKER_SERVICE_FILE" ]; then
    cp "$DOCKER_SERVICE_FILE" "$DOCKER_SERVICE_FILE.bak"
fi

# 修改 Docker 服务配置
sed -i "s|^ExecStart=/usr/bin/dockerd.*|ExecStart=/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock -H tcp://0.0.0.0:2376 --tlsverify --tlscacert=$CERT_DIR/ca.pem --tlscert=$CERT_DIR/server-cert.pem --tlskey=$CERT_DIR/server-key.pem|" "$DOCKER_SERVICE_FILE"

# 重新加载 Docker 服务
systemctl daemon-reload
systemctl restart docker

# 检查 Docker 服务是否正常启动
if systemctl is-active --quiet docker; then
   echo -e "Docker TLS配置已经成功完成。"
else
   echo "Error: docker服务启动失败。恢复到原来的配置..."
   if [ -f "$DOCKER_SERVICE_FILE.bak" ]; then
       mv "$DOCKER_SERVICE_FILE.bak" "$DOCKER_SERVICE_FILE"
   fi
   systemctl daemon-reload
   systemctl restart docker
   echo "docker服务已被恢复到原始配置。"
   exit 1
fi

# 配置证书自动更新脚本
cat > $CERT_DIR/renewcert.sh <<'EOF'
#!/bin/bash
CURRENT_TIME=$(date +"%F %T")
# check if CA certificate is expired
if openssl x509 -checkend 1728000 -noout -in $(dirname "$0")/ca.pem; then
  echo "[$CURRENT_TIME] CA certificate is still valid" >> $(dirname "$0")/crontab_log.txt
else
  echo "[$CURRENT_TIME] CA certificate has expired. Renewing all certificates..." >> $(dirname "$0")/crontab_log.txt
  # regenerate server and client certificates using existing CA
  openssl req -new -x509 -days 365 -key "$(dirname "$0")/ca-key.pem" -passin pass:changepasswd -sha256 -out "$(dirname "$0")/ca.pem" \
-subj "/C=AU/ST=Some-State/O=Internet Widgits Pty Ltd"
  openssl x509 -req -days 365 -sha256 -in "$(dirname "$0")/server.csr" -CA "$(dirname "$0")/ca.pem" -CAkey "$(dirname "$0")/ca-key.pem" -CAcreateserial -out "$(dirname "$0")/server-cert.pem" -extfile "$(dirname "$0")/extfile.cnf" -passin pass:changepasswd
  openssl x509 -req -days 365 -sha256 -in "$(dirname "$0")/client.csr" -CA "$(dirname "$0")/ca.pem" -CAkey "$(dirname "$0")/ca-key.pem" -CAcreateserial -out "$(dirname "$0")/client-cert.pem" -extfile "$(dirname "$0")/client-extfile.cnf" -passin pass:changepasswd
   systemctl daemon-reload
   systemctl restart docker
  echo "[$CURRENT_TIME] All certificates have been renewed" >> $(dirname "$0")/crontab_log.txt
fi
EOF

# 配置脚本定时任务
CRON_JOB="0 0 */15 * * bash $CERT_DIR/renewcert.sh"
if crontab -l 2>/dev/null | grep -Fq "$CRON_JOB"; then
    echo "已存在相同续期定时任务，取消添加"
else
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    echo "续期定时任务已添加"
fi-
