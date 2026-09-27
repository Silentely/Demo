#!/bin/bash
# ==============================================================================
# 脚本名称: http_install.sh
# 功能:     Squid HTTP 代理自动配置工具
# ==============================================================================

set -e

PROXY_USER="${PROXY_USER:-test1}"
PROXY_PASS="${PROXY_PASS:-gt54321}"
HTTP_PORT="${HTTP_PORT:-25562}"

install_http() {
  echo "正在安装 Squid HTTP 代理及认证工具..."
  if command -v apt-get &>/dev/null; then
    sudo apt-get update -y
    sudo apt-get install -y squid apache2-utils
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y squid httpd-tools
  elif command -v yum &>/dev/null; then
    sudo yum install -y squid httpd-tools
  fi

  local auth_bin=""
  for bin_path in \
    /usr/lib/squid/basic_ncsa_auth \
    /usr/lib64/squid/basic_ncsa_auth \
    /usr/lib/squid3/basic_ncsa_auth \
    /usr/libexec/squid/basic_ncsa_auth; do
    if [[ -x "$bin_path" ]]; then
      auth_bin="$bin_path"
      break
    fi
  done
  [[ -z "$auth_bin" ]] && auth_bin="/usr/lib/squid/basic_ncsa_auth"

  echo "正在生成认证密码文件..."
  sudo mkdir -p /etc/squid
  sudo htpasswd -b -c /etc/squid/passwd "$PROXY_USER" "$PROXY_PASS"
  sudo chmod 644 /etc/squid/passwd

  echo "正在写入 Squid 配置文件..."
  cat <<EOF | sudo tee /etc/squid/squid.conf >/dev/null
acl manager proto cache_object
acl localhost src 127.0.0.1/32 ::1
acl to_localhost dst 127.0.0.0/8 0.0.0.0/32 ::1

acl localnet src 10.0.0.0/8
acl localnet src 172.16.0.0/12
acl localnet src 192.168.0.0/16
acl localnet src fc00::/7
acl localnet src fe80::/10

acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 21
acl Safe_ports port 443
acl Safe_ports port 70
acl Safe_ports port 210
acl Safe_ports port 1025-65535
acl Safe_ports port 280
acl Safe_ports port 488
acl Safe_ports port 591
acl Safe_ports port 777
acl CONNECT method CONNECT

http_access allow manager localhost
http_access deny manager
http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports

# 认证配置
auth_param basic program $auth_bin /etc/squid/passwd
acl auth_user proxy_auth REQUIRED
http_access allow auth_user
http_access deny all

http_port $HTTP_PORT
via off
forwarded_for delete

coredump_dir /var/spool/squid
refresh_pattern ^ftp:        1440    20%    10080
refresh_pattern ^gopher:     1440    0%     1440
refresh_pattern -i (/cgi-bin/|\\?) 0 0%     0
refresh_pattern .            0       20%    4320
EOF

  echo "正在启动 Squid 服务..."
  sudo systemctl restart squid || sudo systemctl restart squid.service
  sudo systemctl enable squid || sudo systemctl enable squid.service
  echo "Squid HTTP 代理安装成功！监听端口: $HTTP_PORT"
  echo "用户名: $PROXY_USER"
  echo "密码:   $PROXY_PASS"
}

install_http
