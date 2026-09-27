#!/bin/sh
set -e

if [ -z "$1" ]; then
    echo "用法: $0 <IP地址>"
    echo "示例: $0 192.168.1.100"
    exit 1
fi

IP=$1

echo "正在为 IP: $IP 生成 Docker TLS 证书..."

# 生成 CA 密钥及自签名证书
openssl genrsa -aes256 -out ca-key.pem 4096
openssl req -new -x509 -days 3650 -key ca-key.pem -sha256 -out ca.pem

# 生成服务器证书
openssl genrsa -out server-key.pem 4096
openssl req -subj "/CN=$IP" -sha256 -new -key server-key.pem -out server.csr

# 配置服务器扩展 (覆盖写入避免多次运行重复追加)
echo "subjectAltName = IP:$IP,IP:127.0.0.1" > extfile.cnf
echo "extendedKeyUsage = serverAuth" >> extfile.cnf

openssl x509 -req -days 3650 -sha256 -in server.csr -CA ca.pem -CAkey ca-key.pem \
-CAcreateserial -out server-cert.pem -extfile extfile.cnf

# 生成客户端证书
openssl genrsa -out key.pem 4096
openssl req -subj '/CN=client' -new -key key.pem -out client.csr
echo "extendedKeyUsage = clientAuth" > extfile-client.cnf
openssl x509 -req -days 3650 -sha256 -in client.csr -CA ca.pem -CAkey ca-key.pem \
  -CAcreateserial -out cert.pem -extfile extfile-client.cnf

# 收紧私钥和证书权限
chmod 0400 ca-key.pem key.pem server-key.pem
chmod 0444 ca.pem server-cert.pem cert.pem

echo "证书生成完毕！私钥权限已收紧为 0400。"
