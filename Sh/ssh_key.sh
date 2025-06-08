#!/bin/bash

# 彩色输出变量
color_blue='\033[0;34m'
color_green='\033[0;32m'
color_yellow='\033[0;33m'
color_red='\033[0;31m'
color_reset='\033[0m'

_log() {
    local type="$1"
    local msg="$2"
    case "$type" in
        info)    echo -e "${color_blue}INFO:${color_reset} $msg";;
        success) echo -e "${color_green}SUCCESS:${color_reset} $msg";;
        warn)    echo -e "${color_yellow}WARN:${color_reset} $msg";;
        error)   echo -e "${color_red}ERROR:${color_reset} $msg" >&2;;
        *)       echo -e "$msg";;
    esac
}

show_env_info() {
    echo "+-------------------------------------------------+"
    echo "|   ____                             _______       |"
    echo "|  |  _ \  ___  ___ ___  _ __ ___   |__   __|      |"
    echo "|  | | | |/ _ \/ __/ _ \| '_ \` _ \     | |         |"
    echo "|  | |_| |  __/ (_| (_) | | | | | |    | |         |"
    echo "|  |____/ \___|\___\___/|_| |_| |_|    |_|         |"
    echo "|         D E M O   T O O L B O X                 |"
    echo "+-------------------------------------------------+"
    local os distro arch time_now host
    distro=$(awk -F= '/PRETTY_NAME/ {print $2}' /etc/os-release | tr -d '"')
    [ -z "$distro" ] && distro=$(lsb_release -ds 2>/dev/null | tr -d '"')
    [ -z "$distro" ] && distro=$(uname -s)
    arch=$(uname -m)
    os="$distro $arch"
    time_now=$(date +"%Y-%m-%d %H:%M %Z")
    host=$(hostname)
    echo -e "${color_blue}主机名${color_reset}      ${color_yellow}${host}${color_reset}"
    echo -e "${color_blue}运行环境${color_reset}    ${color_yellow}${os}${color_reset}"
    echo -e "${color_blue}系统时间${color_reset}    ${color_green}${time_now}${color_reset}"
}

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

    echo -e "\n${color_blue}===================== SSH 运行状态 =====================${color_reset}"
    echo -e "${color_blue}端口号         ${color_reset}${color_yellow}${port}${color_reset}"
    echo -e "${color_blue}密码认证       ${color_reset}${color_yellow}${auth}${color_reset}"
    echo -e "${color_blue}活跃连接数     ${color_reset}${color_yellow}${connections}${color_reset}"
    echo -e "${color_blue}SSH 服务状态   ${color_reset}${color_yellow}${sshd_status}${color_reset}"
    echo -e "${color_blue}SSH 版本       ${color_reset}${color_yellow}${sshd_version}${color_reset}"
    echo -e "${color_blue}本机IP         ${color_reset}${color_yellow}${lan_ip}${color_reset}"
    echo -e "${color_blue}公网IP         ${color_reset}${color_yellow}${wan_ip}${color_reset}"
    [ -n "$ciphers" ] && echo -e "${color_blue}加密算法       ${color_reset}${color_yellow}${ciphers}${color_reset}"
    [ -n "$keepalive" ] && echo -e "${color_blue}TCPKeepAlive   ${color_reset}${color_yellow}${keepalive}${color_reset}"
    [ -n "$grace_time" ] && echo -e "${color_blue}LoginGraceTime ${color_reset}${color_yellow}${grace_time}${color_reset}"
    echo -e "${color_blue}========================================================${color_reset}\n"
}
