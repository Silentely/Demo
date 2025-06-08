#!/bin/bash

# --- 彩色输出辅助函数 ---
_log() {
    local type="$1"
    local msg="$2"
    local color_red='\033[0;31m'
    local color_green='\033[0;32m'
    local color_yellow='\033[0;33m'
    local color_blue='\033[0;34m'
    local color_plain='\033[0m'
    case "$type" in
        info)    echo -e "${color_blue}INFO:${color_plain} $msg";;
        success) echo -e "${color_green}SUCCESS:${color_plain} $msg";;
        warn)    echo -e "${color_yellow}WARN:${color_plain} $msg";;
        error)   echo -e "${color_red}ERROR:${color_plain} $msg" >&2;;
        *)       echo -e "$msg";;
    esac
}

readonly PROJECT_URL="https://github.com/Silentely/Demo"
readonly PROJECT_NAME="@Silentely/Demo"
readonly PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJWYt+IEmAg9n30UBVyQgeDECsSmfS+Jwb1nO93rao0d"

show_header() {
    clear
    echo "=================================================================="
    echo "   Linux SSH 安全配置脚本"
    echo "   项目地址: $PROJECT_NAME  $PROJECT_URL"
    echo "=================================================================="
}

show_completion() {
    echo "=================================================================="
    _log success "SSH 配置已完成"
    echo "   项目仓库: $PROJECT_URL"
    echo "   🙏 感谢使用本脚本！如有帮助，欢迎 star 支持！"
    echo "=================================================================="
    echo
}

# 检查是否以root权限运行
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        _log error "请以root权限运行此脚本"
        exit 1
    fi
}

# ==== 状态信息输出 ====
show_status_info() {
    local port auth connections sshd_status sshd_version lan_ip wan_ip ciphers keepalive grace_time
    port=$(grep '^Port ' /etc/ssh/sshd_config | awk '{print $2}' | tail -n1)
    [ -z "$port" ] && port="22"
    auth=$(grep '^PasswordAuthentication ' /etc/ssh/sshd_config | awk '{print $2}' | tail -n1)
    [ -z "$auth" ] && auth="未知"
    connections=$(ss -tun | grep ":$port" | wc -l 2>/dev/null)
    [ -z "$connections" ] && connections="未知"
    sshd_status=$(systemctl is-active sshd 2>/dev/null || systemctl is-active ssh 2>/dev/null)
    [ -z "$sshd_status" ] && sshd_status="未知"
    sshd_version=$(sshd -V 2>&1 | head -n1)
    [ -z "$sshd_version" ] && sshd_version=$(sshd -v 2>&1 | head -n1)
    lan_ip=$(hostname -I | awk '{print $1}')
    wan_ip=$(curl -s -m 5 icanhazip.com || curl -s -m 5 ipinfo.io/ip || curl -s -m 5 ifconfig.me)
    [ -z "$wan_ip" ] && wan_ip="获取失败"
    ciphers=$(grep '^Ciphers ' /etc/ssh/sshd_config | awk '{print $2}' | tail -n1)
    keepalive=$(grep '^TCPKeepAlive ' /etc/ssh/sshd_config | awk '{print $2}' | tail -n1)
    grace_time=$(grep '^LoginGraceTime ' /etc/ssh/sshd_config | awk '{print $2}' | tail -n1)

    echo -e "\n===================== SSH 运行状态 ====================="
    _log info "端口号: $port"
    _log info "密码认证: $auth"
    _log info "活跃连接数: $connections"
    _log info "SSH 服务状态: $sshd_status"
    _log info "SSH 版本: $sshd_version"
    _log info "本机IP: $lan_ip"
    _log info "公网IP: $wan_ip"
    if [ -n "$ciphers" ]; then
        _log info "加密算法: $ciphers"
    fi
    if [ -n "$keepalive" ]; then
        _log info "TCPKeepAlive: $keepalive"
    fi
    if [ -n "$grace_time" ]; then
        _log info "LoginGraceTime: $grace_time"
    fi
    echo "========================================================"
}

# ==== SSH 连接优化 ====
backup_ssh_config() {
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak_opt_$(date +%s)
}

validate_ssh_config() {
    sshd -t
}

restart_ssh_service() {
    local service_name
    service_name=$(systemctl list-units --type=service | grep -E 'ssh(d)?\.service' | awk '{print $1}' | head -n 1)
    [ -n "$service_name" ] && systemctl restart "$service_name"
}

rollback_ssh_config() {
    local last_bak
    last_bak=$(ls -t /etc/ssh/sshd_config.bak_opt_* 2>/dev/null | head -n 1)
    [ -f "$last_bak" ] && cp "$last_bak" /etc/ssh/sshd_config
}

optimize_ssh_speed() {
    backup_ssh_config || return 1
    {
        echo 'Ciphers aes256-ctr,aes192-ctr,aes128-ctr'
        echo 'TCPKeepAlive yes'
        echo 'LoginGraceTime 30'
    } >> /etc/ssh/sshd_config || {
        _log error "优化 SSH 配置失败"
        return 1
    }
    if validate_ssh_config; then
        restart_ssh_service || return 1
        _log success "SSH 连接速度已优化"
    else
        _log error "SSH 配置无效，执行回滚"
        rollback_ssh_config || _log error "回滚失败，请手动恢复"
        return 1
    fi
}

# --- 原有 SSH 配置和菜单代码 ---
show_menu() {
    echo
    _log info "Linux SSH 安全配置向导"
    echo "1. 仅启用密钥登录（自动添加指定公钥）"
    echo "2. 仅启用密码登录（自定义密钥）"
    echo "3. 仅启用root密码登录"
    echo "4. 同时启用密码和密钥登录"
    echo "0. 退出脚本"
    echo "--------------------------------"
}

setup_pubkey_login() {
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    touch /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    if ! grep -q "${PUBKEY}" /root/.ssh/authorized_keys; then
        echo "${PUBKEY}" >> /root/.ssh/authorized_keys
        _log success "已添加指定公钥"
    else
        _log info "指定公钥已存在，无需重复添加"
    fi
    apply_config prohibit-password no yes
    _log success "密钥登录已启用（仅允许指定公钥），密码登录已禁用"
}

setup_key() {
    echo -ne "$(echo -e '\033[0;34m')>> 是否已有SSH公钥？(y/n) $(echo -e '\033[0m')"
    read -r has_key
    if [ "$has_key" = "y" ]; then
        _log info "请粘贴您的公钥内容（支持RSA/Ed25519，按Ctrl+D结束输入）："
        temp_key=$(mktemp)
        cat > "$temp_key"
        if ! ssh-keygen -lf "$temp_key" &>/dev/null; then
            _log error "无效的公钥格式"
            rm -f "$temp_key"
            exit 1
        fi
        mkdir -p /root/.ssh
        chmod 700 /root/.ssh
        touch /root/.ssh/authorized_keys
        chmod 600 /root/.ssh/authorized_keys
        cat "$temp_key" >> /root/.ssh/authorized_keys
        rm -f "$temp_key"
        _log success "公钥已成功添加"
    else
        echo -ne "$(echo -e '\033[0;34m')>> 选择密钥类型 (1) Ed25519（推荐） (2) RSA-4096：$(echo -e '\033[0m')"
        read -r key_type_choice
        case $key_type_choice in
            1)
                key_type="ed25519"
                key_opts="-t ed25519"
                ;;
            2|*)
                key_type="rsa"
                key_opts="-t rsa -b 4096"
                ;;
        esac
        key_type_display=$(echo "$key_type" | tr '[:lower:]' '[:upper:]')
        _log info "正在生成${key_type_display}密钥对..."
        mkdir -p /root/.ssh
        chmod 700 /root/.ssh
        if ! ssh-keygen $key_opts -N "" -f "/root/.ssh/linux_$key_type"; then
            _log error "密钥生成失败"
            exit 1
        fi
        chmod 600 /root/.ssh/linux_$key_type*
        cat "/root/.ssh/linux_$key_type.pub" >> /root/.ssh/authorized_keys
        chmod 600 /root/.ssh/authorized_keys
        _log warn "重要！请立即下载私钥文件：/root/.ssh/linux_$key_type"
    fi
}

apply_config() {
    backup_file="/etc/ssh/sshd_config.bak_$(date +%s)"
    cp /etc/ssh/sshd_config "$backup_file"
    _log info "配置已备份至：$backup_file"
    sed -i "s/^#*PermitRootLogin.*/PermitRootLogin $1/" /etc/ssh/sshd_config
    sed -i "s/^#*PasswordAuthentication.*/PasswordAuthentication $2/" /etc/ssh/sshd_config
    sed -i "s/^#*PubkeyAuthentication.*/PubkeyAuthentication $3/" /etc/ssh/sshd_config
    grep -q "^PermitRootLogin" /etc/ssh/sshd_config || echo "PermitRootLogin $1" >> /etc/ssh/sshd_config
    grep -q "^PasswordAuthentication" /etc/ssh/sshd_config || echo "PasswordAuthentication $2" >> /etc/ssh/sshd_config
    grep -q "^PubkeyAuthentication" /etc/ssh/sshd_config || echo "PubkeyAuthentication $3" >> /etc/ssh/sshd_config
}

restart_ssh() {
    if ! sshd -t; then
        _log error "SSH配置存在语法错误，请检查以下问题："
        sshd -t
        _log info "可以从备份恢复配置："
        ls -lh /etc/ssh/sshd_config.bak_*
        exit 1
    fi
    service_name=$(systemctl list-units --type=service | grep -E 'ssh(d)?\.service' | awk '{print $1}' | head -n 1)
    if [ -z "$service_name" ]; then
        _log error "无法确定SSH服务名称，请手动重启SSH服务"
        exit 1
    fi
    echo -ne "$(echo -e '\033[0;34m')>> 是否立即重启SSH服务？(y/n) $(echo -e '\033[0m')"
    read -r restart_choice
    if [ "$restart_choice" = "y" ]; then
        _log info "正在重启SSH服务..."
        systemctl restart "$service_name"
        sleep 2
        if systemctl is-active --quiet "$service_name"; then
            _log success "SSH服务重启成功"
        else
            _log error "SSH服务启动失败，请检查日志：journalctl -u $service_name"
            _log info "可以从备份恢复配置："
            ls -lh /etc/ssh/sshd_config.bak_*
            exit 1
        fi
    else
        _log warn "配置更改尚未生效！请手动执行：systemctl restart $service_name"
    fi
}

get_ip_address() {
    ip=$(curl -s -m 10 icanhazip.com || curl -s -m 10 ipinfo.io/ip || curl -s -m 10 ifconfig.me)
    [ -z "$ip" ] && ip=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v "127.0.0.1" | head -n 1)
    [ -z "$ip" ] && echo "无法获取IP地址" || echo "$ip"
}

main() {
    check_root
    show_header
    show_status_info

    mkdir -p /root/.ssh
    chmod 700 /root/.ssh

    while true; do
        show_menu
        echo -ne "$(echo -e '\033[0;34m')>> 请选择操作编号：$(echo -e '\033[0m')"
        read -r choice
        case $choice in
            1)
                setup_pubkey_login
                optimize_ssh_speed
                break
                ;;
            2)
                setup_key
                apply_config prohibit-password yes yes
                _log success "密码登录已启用，自定义密钥也已配置"
                optimize_ssh_speed
                break
                ;;
            3)
                apply_config yes yes no
                _log success "已启用root密码登录"
                echo -ne "$(echo -e '\033[0;34m')>> 是否现在修改root密码？(y/n) $(echo -e '\033[0m')"
                read -r change_pw
                [ "$change_pw" = "y" ] && passwd root
                optimize_ssh_speed
                break
                ;;
            4)
                setup_key
                apply_config yes yes yes
                _log success "密码和密钥登录均已启用"
                echo -ne "$(echo -e '\033[0;34m')>> 是否现在修改root密码？(y/n) $(echo -e '\033[0m')"
                read -r change_pw
                [ "$change_pw" = "y" ] && passwd root
                optimize_ssh_speed
                break
                ;;
            0)
                _log info "退出脚本"
                exit 0
                ;;
            *)
                _log warn "无效选择，请重新输入"
                sleep 2
                ;;
        esac
    done

    restart_ssh

    server_ip=$(get_ip_address)
    echo "========================================"
    echo "服务器IP：$server_ip"
    [ -f /root/.ssh/linux_ed25519 ] && echo "Ed25519密钥：/root/.ssh/linux_ed25519"
    [ -f /root/.ssh/linux_rsa ] && echo "RSA-4096密钥：/root/.ssh/linux_rsa"
    echo "连接命令：ssh -i [密钥路径] root@$server_ip"
    echo "========================================"
    _log warn "[!] 重要安全提醒"
    echo "1. 请在新窗口测试连接，确认正常后再关闭当前会话！"
    echo "2. 备份配置文件列表："
    ls -lh /etc/ssh/sshd_config.bak_*
    show_completion
}

main
