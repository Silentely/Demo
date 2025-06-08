#!/bin/bash
#
# ==============================================================================
# Linux SSH Security Enhancement & Configuration Script
#
# Description: A tool to quickly and safely configure SSH server settings on
#              Linux systems, focusing on security best practices.
# Author:      Silentely
# Version:     2.1
# ==============================================================================

# --- 全局常量和颜色定义 ---
# 使用 tput 动态获取终端能力，如果失败则回退到硬编码的 ANSI 转义序列
# 这样做可以提高脚本在不同终端环境下的兼容性。
if command -v tput >/dev/null && tput setaf 1 >/dev/null; then
    color_blue=$(tput setaf 4)
    color_green=$(tput setaf 2)
    color_yellow=$(tput setaf 3)
    color_red=$(tput setaf 1)
    color_bold=$(tput bold)
    color_reset=$(tput sgr0)
else
    color_blue='\033[0;34m'
    color_green='\033[0;32m'
    color_yellow='\033[0;33m'
    color_red='\033[0;31m'
    color_bold='\033[1m'
    color_reset='\033[0m'
fi

# --- 作者自用及项目信息 ---
# 警告: 这是脚本作者的个人公钥。如果您不是作者本人，请不要直接使用选项 1。
# 请选择选项 2 "使用自定义公钥登录" 来配置您自己的公钥。
readonly PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJWYt+IEmAg9n30UBVyQgeDECsSmfS+Jwb1nO93rao0d"
readonly PROJECT_URL="https://github.com/Silentely/Demo"
readonly PROJECT_NAME="@Silentely/Demo"

# --- 核心工具函数 ---

# 统一的日志输出函数
_log() {
    local type="$1"
    local msg="$2"
    local color tag
    case "$type" in
        info)    color="$color_blue"   ; tag="INFO"    ;;
        success) color="$color_green"  ; tag="SUCCESS" ;;
        warn)    color="$color_yellow" ; tag="WARN"    ;;
        error)   color="$color_red"    ; tag="ERROR"   ;;
        *)       printf "%s\n" "$msg"; return ;;
    esac
    if [[ "$type" == "error" ]]; then
        printf "${color_bold}%s:${color_reset} %s\n" "$tag" "$msg" >&2
    else
        printf "${color}%s:${color_reset} %s\n" "$tag" "$msg"
    fi
}

# 交互式提示函数
prompt_yes_no() {
    local prompt_msg="$1"
    local default_choice="${2:-y}"
    local choice
    while true; do
        read -r -p "$(printf "%s${color_blue}%s${color_reset}" "${color_bold}" "${prompt_msg}")" choice
        choice=${choice:-$default_choice}
        case "$choice" in
            [Yy]* ) return 0 ;;
            [Nn]* ) return 1 ;;
            * ) _log error "无效输入，请输入 y 或 n" ;;
        esac
    done
}

# 检查 root 权限
check_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        _log error "此脚本需要以 root 权限运行，请使用 'sudo ./script.sh'。"
        exit 1
    fi
}

# --- 展示类函数 ---

show_header() {
    clear
    printf "%s\n" "=================================================================="
    printf "  Linux SSH 安全配置脚本 (v2.1 优化版)\n"
    printf "  项目地址: %s  %s\n" "$PROJECT_NAME" "$PROJECT_URL"
    printf "%s\n" "=================================================================="
}

show_env_info() {
    echo
    _log info "当前环境信息"
    local os distro arch time_now host
    distro=$(grep -oP '(?<=^PRETTY_NAME=").*(?="$)' /etc/os-release || lsb_release -ds || uname -s)
    arch=$(uname -m)
    os="$distro $arch"
    time_now=$(date +"%Y-%m-%d %H:%M %Z")
    host=$(hostname)
    printf "%-15s: %s%s%s\n" "主机名" "$color_yellow" "$host" "$color_reset"
    printf "%-15s: %s%s%s\n" "运行环境" "$color_yellow" "$os" "$color_reset"
    printf "%-15s: %s%s%s\n" "系统时间" "$color_green" "$time_now" "$color_reset"
    echo
}

# 更健壮地获取 SSHD 配置项的值
get_sshd_config_value() {
    local key="$1"
    sshd -T 2>/dev/null | grep -i "^${key}" | awk '{print $2}' || \
    grep -iE "^\s*#?\s*${key}\s+" /etc/ssh/sshd_config | awk '{print $NF}' | tail -n1
}

show_status_info() {
    _log info "SSH 运行状态"
    local port auth connections sshd_status lan_ip wan_ip
    port=$(get_sshd_config_value "port")
    [[ -z "$port" ]] && port="22"
    auth=$(get_sshd_config_value "passwordauthentication")
    [[ -z "$auth" ]] && auth="未知"
    lan_ip=$(hostname -I | awk '{print $1}')
    wan_ip=$(curl -s -m 5 icanhazip.com || curl -s -m 5 ipinfo.io/ip)
    [[ -z "$wan_ip" ]] && wan_ip="获取失败"
    connections_val=$(ss -tun | grep -c ":$port" 2>/dev/null)
    connections=${connections_val:-"未知"}
    sshd_status_val=$(systemctl is-active sshd 2>/dev/null || systemctl is-active ssh 2>/dev/null)
    sshd_status=${sshd_status_val:-"未知"}
    printf "%-18s: %s%s%s\n" "SSH 端口" "$color_yellow" "$port" "$color_reset"
    printf "%-18s: %s%s%s\n" "密码认证" "$color_yellow" "$auth" "$color_reset"
    printf "%-18s: %s%s%s\n" "SSH 服务状态" "$color_yellow" "$sshd_status" "$color_reset"
    printf "%-18s: %s%s%s\n" "当前连接数" "$color_yellow" "$connections" "$color_reset"
    printf "%-18s: %s%s%s\n" "本机 IP" "$color_yellow" "$lan_ip" "$color_reset"
    printf "%-18s: %s%s%s\n" "公网 IP" "$color_yellow" "$wan_ip" "$color_reset"
    printf "%s\n" "------------------------------------------------------------------"
}

show_completion() {
    printf "%s\n" "=================================================================="
    _log success "SSH 配置已完成"
    printf "  项目仓库: %s\n" "$PROJECT_URL"
    printf "  🙏 感谢使用本脚本！如有帮助，欢迎 star 支持！\n"
    printf "%s\n" "=================================================================="
    echo
}

# --- SSH 配置核心函数 ---

# 统一、幂等地更新 sshd_config 文件
update_sshd_config() {
    local key="$1"
    local value="$2"
    local config_file="/etc/ssh/sshd_config"
    if grep -qE "^\s*#?\s*${key}\s+" "$config_file"; then
        sed -i -E "s/^\s*#?\s*${key}\s+.*/${key} ${value}/" "$config_file"
    else
        echo "${key} ${value}" >> "$config_file"
    fi
    _log info "配置更新: ${key} -> ${value}"
}

# 获取 SSH 服务名称
get_ssh_service_name() {
    systemctl list-units --type=service | grep -oE 'ssh(d)?\.service' | head -n 1
}

# 验证配置并重启 SSH 服务
validate_and_restart_ssh() {
    local config_file="/etc/ssh/sshd_config"
    local backup_file="/etc/ssh/sshd_config.bak_opt_$(date +%F_%T)"
    if ! cp "$config_file" "$backup_file"; then
        _log error "备份配置文件失败，操作已中止！"
        return 1
    fi
    _log success "配置已备份至: $backup_file"
    if ! sshd -t; then
        _log error "新的 SSH 配置无效！正在自动回滚..."
        if ! cp "$backup_file" "$config_file"; then
            _log error "自动回滚失败！请手动恢复: cp ${backup_file} ${config_file}"
        else
            _log success "已成功从备份回滚配置。"
        fi
        return 1
    fi
    _log success "SSH 配置语法检查通过。"
    local service_name
    service_name=$(get_ssh_service_name)
    if [[ -z "$service_name" ]]; then
        _log error "无法确定 SSH 服务名称，请手动重启服务。"
        return 1
    fi
    if prompt_yes_no "是否立即重启 SSH 服务以应用更改？(Y/n) "; then
        _log info "正在重启 SSH 服务 ($service_name)..."
        if ! systemctl restart "$service_name"; then
             _log error "SSH 服务重启失败！请检查日志: journalctl -u $service_name"
             return 1
        fi
        sleep 1
        if systemctl is-active --quiet "$service_name"; then
            _log success "SSH 服务重启成功。"
        else
            _log error "SSH 服务启动失败！请检查日志: journalctl -u $service_name"
            return 1
        fi
    else
        _log warn "配置已修改但未生效。请稍后手动重启服务: systemctl restart $service_name"
    fi
    return 0
}

# 添加作者的硬编码公钥
add_hardcoded_pubkey() {
    local ssh_dir="/root/.ssh"
    local auth_keys_file="$ssh_dir/authorized_keys"
    mkdir -p "$ssh_dir" && chmod 700 "$ssh_dir"
    touch "$auth_keys_file" && chmod 600 "$auth_keys_file"
    if grep -qF -- "$PUBKEY" "$auth_keys_file"; then
        _log info "内置公钥已存在，无需重复添加。"
    else
        echo "$PUBKEY" >> "$auth_keys_file"
        _log success "内置公钥已成功添加。"
    fi
}

# 设置自定义密钥认证
setup_custom_key() {
    local ssh_dir="/root/.ssh"
    local auth_keys_file="$ssh_dir/authorized_keys"
    mkdir -p "$ssh_dir" && chmod 700 "$ssh_dir"
    touch "$auth_keys_file" && chmod 600 "$auth_keys_file"
    _log info "您需要配置公钥以进行密钥登录。"
    if prompt_yes_no "您是否已经有想要使用的公钥？(Y/n) "; then
        _log info "请粘贴您的公钥内容（一行），然后按 Ctrl+D 结束输入："
        local pubkey
        pubkey=$(cat)
        if [[ -z "$pubkey" ]]; then
            _log error "未输入任何内容，操作取消。"; return 1;
        fi
        if ! echo "$pubkey" | grep -qE "^ssh-(rsa|ed25519|ecdsa)"; then
             _log error "无效的公钥格式。应以 'ssh-rsa', 'ssh-ed25519' 等开头。"; return 1;
        fi
        if grep -qF -- "$pubkey" "$auth_keys_file"; then
            _log info "此公钥已存在，无需重复添加。"
        else
            echo "$pubkey" >> "$auth_keys_file"
            _log success "公钥已成功添加至 $auth_keys_file"
        fi
    else
        _log info "将为您生成新的密钥对。"
        local key_type key_path key_opts
        read -r -p "$(printf "%s>> 请选择密钥类型 (1) Ed25519 [推荐] (2) RSA-4096: %s" "$color_bold" "$color_reset")" choice
        case "$choice" in
            1) key_type="ed25519"; key_opts="-t ed25519" ;;
            *) key_type="rsa"; key_opts="-t rsa -b 4096" ;;
        esac
        key_path="$ssh_dir/generated_key_$key_type"
        if [[ -f "$key_path" ]]; then
            _log warn "密钥文件 $key_path 已存在。将跳过生成。"
        else
             _log info "正在生成 ${key_type^^} 密钥对..."
             if ! ssh-keygen ${key_opts} -N "" -f "$key_path"; then
                 _log error "密钥生成失败！"; return 1;
             fi
             _log success "密钥已生成:"
             printf "  公钥: %s.pub\n  私钥: %s\n" "$key_path" "$key_path"
        fi
        if grep -qF -- "$(cat "${key_path}.pub")" "$auth_keys_file"; then
             _log info "生成的公钥已存在于 authorized_keys 文件中。"
        else
             cat "${key_path}.pub" >> "$auth_keys_file"
             _log success "生成的公钥已自动添加到 authorized_keys"
        fi
        _log warn "【重要】请立即下载并妥善保管您的私钥文件: $key_path"
    fi
    return 0
}

# 修改 root 密码
change_root_password() {
    if prompt_yes_no "是否现在修改 root 用户的密码？(y/N) " "n"; then
        passwd root
    fi
}

# --- 主逻辑 ---
main() {
    check_root
    show_header
    show_env_info
    show_status_info
    while true; do
        printf "\n%s%s%s\n" "$color_bold" "--- SSH 安全配置向导 ---" "$color_reset"
        echo "1. 【作者专用】使用内置公钥登录 (禁用密码)"
        echo "2. 【推荐】使用自定义公钥登录 (禁用密码)"
        echo "3. 【兼容】密钥和密码登录均可"
        echo "4. 【危险】仅密码登录 (禁用密钥)"
        echo "5. 优化 SSH 连接速度"
        echo "6. 修改 Root 用户密码"
        echo "0. 退出脚本"
        printf "%s\n" "------------------------------------------------------------------"
        local choice
        read -r -p "$(printf "%s>> 请选择操作编号: %s" "$color_bold" "$color_reset")" choice
        case "$choice" in
            1) # 作者专用
                _log warn "您选择了作者专用模式，将使用脚本内置的公钥。"
                if ! prompt_yes_no "确认继续吗？(Y/n) "; then continue; fi
                add_hardcoded_pubkey
                update_sshd_config "PubkeyAuthentication" "yes"
                update_sshd_config "PasswordAuthentication" "no"
                update_sshd_config "PermitRootLogin" "prohibit-password"
                break ;;
            2) # 自定义密钥登录
                _log info "将配置为仅限使用您自己的公钥登录。"
                if ! setup_custom_key; then continue; fi
                update_sshd_config "PubkeyAuthentication" "yes"
                update_sshd_config "PasswordAuthentication" "no"
                update_sshd_config "PermitRootLogin" "prohibit-password"
                break ;;
            3) # 密钥和密码
                _log info "将配置为允许密钥和密码两种登录方式。"
                if ! setup_custom_key; then continue; fi
                change_root_password
                update_sshd_config "PubkeyAuthentication" "yes"
                update_sshd_config "PasswordAuthentication" "yes"
                update_sshd_config "PermitRootLogin" "yes"
                break ;;
            4) # 仅密码
                _log warn "警告：禁用密钥登录会降低服务器安全性！"
                if prompt_yes_no "您确定要这样做吗？(y/N) " "n"; then
                    change_root_password
                    update_sshd_config "PubkeyAuthentication" "no"
                    update_sshd_config "PasswordAuthentication" "yes"
                    update_sshd_config "PermitRootLogin" "yes"
                    break
                else
                    _log info "操作已取消。"
                fi ;;
            5) # 优化速度
                _log info "正在应用 SSH 连接速度优化..."
                update_sshd_config "Ciphers" "aes256-ctr,aes192-ctr,aes128-ctr"
                update_sshd_config "TCPKeepAlive" "yes"
                update_sshd_config "LoginGraceTime" "30"
                _log success "速度优化配置已添加，将在重启 SSH 服务后生效。"
                ;;
            6) # 修改密码
                change_root_password ;;
            0)
                _log info "退出脚本，未做任何更改。"
                exit 0 ;;
            *)
                _log error "无效选择，请重新输入。" ;;
        esac
    done
    if ! validate_and_restart_ssh; then
        _log error "配置过程出现问题，请检查以上日志。"
        exit 1
    fi
    show_completion
    _log warn "[!] 重要安全提醒：请立即打开一个新的终端窗口，使用新配置测试SSH连接，确认无误后再关闭当前会话！"
}

# --- 脚本入口 ---
main "$@"

