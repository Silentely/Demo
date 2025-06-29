#!/bin/bash
#
# ==============================================================================
# Linux SSH Security Enhancement & Configuration Script
#
# Description: A tool to quickly and safely configure SSH server settings on
#              Linux systems, focusing on security best practices.
# Author:      @Silentely/Demo
# ==============================================================================

# --- 全局常量和颜色定义 ---
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

readonly PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJWYt+IEmAg9n30UBVyQgeDECsSmfS+Jwb1nO93rao0d"
readonly PROJECT_URL="https://github.com/Silentely/Demo"
readonly PROJECT_NAME="@Silentely/Demo"

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

# 新增：选择覆盖或追加公钥
choose_overwrite_or_append() {
    local file="$1"
    if [[ -s "$file" ]]; then
        _log warn "$file 已存在且非空。"
        if prompt_yes_no "是否覆盖原有内容？(Y=覆盖，n=追加)" "n"; then
            return 0  # 覆盖
        else
            return 1  # 追加
        fi
    else
        return 1  # 空文件，直接追加
    fi
}

check_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        _log error "此脚本需要以 root 权限运行，请使用 'sudo ./script.sh'。"
        exit 1
    fi
}

show_header() {
    clear
    printf "%s\n" "=================================================================="
    printf "  Linux SSH 安全配置脚本 \n"
    printf "  项目地址: %s  %s\n" "$PROJECT_NAME" "$PROJECT_URL"
    printf "%s\n" "=================================================================="
}

show_env_info() {
    # ASCII艺术字
    echo "+-------------------------------------------------+"
    echo "|     ____                               _______  |"
    echo "|    |  _ \  ___  ___ ___  _ __ ___     |__   __| |"
    echo "|    | | | |/ _ \/ __/ _ \| '_ \` _ \    | |      |"
    echo "|    | |_| |  __/ (_| (_) | | | | | |   | |      |"
    echo "|    |____/ \___|\___\___/|_| |_| |_|   |_|      |"
    echo "|        D E M O   T O O L B O X                |"
    echo "+-------------------------------------------------+"
    _log info "当前环境信息"
    local os distro arch time_now host
    distro=$(grep -oP '(?<=^PRETTY_NAME=").*(?="$)' /etc/os-release || lsb_release -ds || uname -s)
    arch=$(uname -m)
    os="$distro $arch"
    time_now=$(date +"%Y-%m-%d %H:%M %Z")
    host=$(hostname)
    printf "主机名    : %s%s%s\n" "$color_yellow" "$host" "$color_reset"
    printf "环境      : %s%s%s\n" "$color_yellow" "$os" "$color_reset"
    printf "时间      : %s%s%s\n" "$color_green" "$time_now" "$color_reset"
    echo
}

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
    printf "端口      : %s%s%s\n" "$color_yellow" "$port" "$color_reset"
    printf "密码认证  : %s%s%s\n" "$color_yellow" "$auth" "$color_reset"
    printf "服务状态  : %s%s%s\n" "$color_yellow" "$sshd_status" "$color_reset"
    printf "连接数    : %s%s%s\n" "$color_yellow" "$connections" "$color_reset"
    printf "本机IP    : %s%s%s\n" "$color_yellow" "$lan_ip" "$color_reset"
    printf "公网IP    : %s%s%s\n" "$color_yellow" "$wan_ip" "$color_reset"
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

get_ssh_service_name() {
    systemctl list-units --type=service | grep -oE 'ssh(d)?\.service' | head -n 1
}

validate_and_restart_ssh() {
    local config_file="/etc/ssh/sshd_config"
    local backup_file="/etc/ssh/sshd_config.bak_opt_$(date +%F_%T)"
    if ! cp "$config_file" "$backup_file"; then
        _log error "备份配置文件失败，操作已中止！"; return 1;
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
        _log error "无法确定 SSH 服务名称，请手动重启服务。"; return 1;
    fi
    if prompt_yes_no "是否立即重启 SSH 服务以应用更改？(Y/n) "; then
        _log info "正在重启 SSH 服务 ($service_name)..."
        if ! systemctl restart "$service_name"; then
             _log error "SSH 服务重启失败！请检查日志: journalctl -u $service_name"; return 1;
        fi
        sleep 1
        if systemctl is-active --quiet "$service_name"; then
            _log success "SSH 服务重启成功。"
        else
            _log error "SSH 服务启动失败！请检查日志: journalctl -u $service_name"; return 1;
        fi
    else
        _log warn "配置已修改但未生效。请稍后手动重启服务: systemctl restart $service_name"
    fi
    return 0
}

add_hardcoded_pubkey() {
    local ssh_dir="/root/.ssh"
    local auth_keys_file="$ssh_dir/authorized_keys"
    mkdir -p "$ssh_dir" && chmod 700 "$ssh_dir"
    touch "$auth_keys_file" && chmod 600 "$auth_keys_file"
    if grep -qF -- "$PUBKEY" "$auth_keys_file"; then
        _log info "内置公钥已存在，无需重复添加。"
    else
        if choose_overwrite_or_append "$auth_keys_file"; then
            echo "$PUBKEY" > "$auth_keys_file"
            _log success "内置公钥已覆盖写入。"
        else
            echo "$PUBKEY" >> "$auth_keys_file"
            _log success "内置公钥已追加。"
        fi
    fi
}

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
        if [[ -z "$pubkey" ]]; then _log error "未输入任何内容，操作取消。"; return 1; fi
        if ! echo "$pubkey" | grep -qE "^ssh-(rsa|ed25519|ecdsa)"; then _log error "无效的公钥格式。"; return 1; fi
        if grep -qF -- "$pubkey" "$auth_keys_file"; then
            _log info "此公钥已存在，无需重复添加。"
        else
            if choose_overwrite_or_append "$auth_keys_file"; then
                echo "$pubkey" > "$auth_keys_file"
                _log success "公钥已覆盖写入 $auth_keys_file"
            else
                echo "$pubkey" >> "$auth_keys_file"
                _log success "公钥已追加至 $auth_keys_file"
            fi
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
            if ! ssh-keygen ${key_opts} -N "" -f "$key_path"; then _log error "密钥生成失败！"; return 1; fi
            _log success "密钥已生成:"
            printf "  公钥: %s.pub\n  私钥: %s\n" "$key_path" "$key_path"
        fi
        if grep -qF -- "$(cat "${key_path}.pub")" "$auth_keys_file"; then
            _log info "生成的公钥已存在于 authorized_keys 文件中。"
        else
            if choose_overwrite_or_append "$auth_keys_file"; then
                cat "${key_path}.pub" > "$auth_keys_file"
                _log success "生成的公钥已覆盖写入 authorized_keys"
            else
                cat "${key_path}.pub" >> "$auth_keys_file"
                _log success "生成的公钥已追加到 authorized_keys"
            fi
        fi
        _log warn "【重要】请立即下载并妥善保管您的私钥文件: $key_path"
    fi
    return 0
}

optimize_ssh_speed() {
    _log info "正在自动应用 SSH 连接速度优化..."
    update_sshd_config "Ciphers" "aes256-ctr,aes192-ctr,aes128-ctr"
    update_sshd_config "TCPKeepAlive" "yes"
    update_sshd_config "LoginGraceTime" "30"
}

change_root_password() {
    if prompt_yes_no "是否现在修改 root 用户的密码？(y/N) " "n"; then
        passwd root
    fi
}

# 新增：检测并开放 ufw 端口
check_and_open_ufw_port() {
    local port="${1:-22}"
    if command -v ufw >/dev/null 2>&1; then
        if ufw status | grep -q -E "Status: active"; then
            if ! ufw status | grep -qw "$port"; then
                _log info "检测到 ufw 已启用，正在开放端口 $port ..."
                ufw allow "$port"/tcp
                _log success "已开放 ufw 端口 $port/tcp"
            else
                _log info "ufw 端口 $port/tcp 已经开放"
            fi
        else
            _log info "ufw 已安装但未启用"
        fi
    fi
}

modify_ssh_port() {
    local current_port new_port
    current_port=$(get_sshd_config_value "port")
    [[ -z "$current_port" ]] && current_port="22"

    read -r -p "$(printf "当前端口为 %s。请输入新的 SSH 端口号 (1-65535)，或留空取消: " "$current_port")" new_port

    if [[ -z "$new_port" ]]; then
        _log info "操作已取消。"
        return 1
    fi

    if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1 ] || [ "$new_port" -gt 65535 ]; then
        _log error "无效的端口号！请输入 1-65535 之间的数字。"
        return 1
    fi

    update_sshd_config "Port" "$new_port"
    _log success "SSH 端口已计划更改为 $new_port。"
    check_and_open_ufw_port "$new_port"
    return 0
}

main() {
    check_root
    show_header
    show_env_info
    show_status_info
    local config_changed=false

    while true; do
        printf "\n%s%s%s\n" "$color_bold" "--- SSH 安全配置向导 ---" "$color_reset"
        echo "1. 使用内置公钥登录 (禁用密码)（作者专用）"
        echo "2. 使用自定义公钥登录 (禁用密码)"
        echo "3. 密钥和密码登录均可"
        echo "4. 仅密码登录 (禁用密钥)"
        echo "5. 修改 SSH 端口"
        echo "6. 修改 Root 用户密码"
        echo "0. 完成配置并退出"
        printf "%s\n" "------------------------------------------------------------------"
        local choice
        read -r -p "$(printf "%s>> 请选择操作编号: %s" "$color_bold" "$color_reset")" choice
        case "$choice" in
            1)
                _log warn "您选择了作者专用模式，将使用脚本内置的公钥。"
                if ! prompt_yes_no "确认继续吗？(Y/n) "; then continue; fi
                add_hardcoded_pubkey; optimize_ssh_speed
                update_sshd_config "PubkeyAuthentication" "yes"
                update_sshd_config "PasswordAuthentication" "no"
                update_sshd_config "PermitRootLogin" "prohibit-password"
                port=$(get_sshd_config_value "port")
                [[ -z "$port" ]] && port="22"
                check_and_open_ufw_port "$port"
                config_changed=true; break ;;
            2)
                _log info "将配置为仅限使用您自己的公钥登录。"
                if ! setup_custom_key; then continue; fi
                optimize_ssh_speed
                update_sshd_config "PubkeyAuthentication" "yes"
                update_sshd_config "PasswordAuthentication" "no"
                update_sshd_config "PermitRootLogin" "prohibit-password"
                port=$(get_sshd_config_value "port")
                [[ -z "$port" ]] && port="22"
                check_and_open_ufw_port "$port"
                config_changed=true; break ;;
            3)
                _log info "将配置为允许密钥和密码两种登录方式。"
                if ! setup_custom_key; then continue; fi
                change_root_password; optimize_ssh_speed
                update_sshd_config "PubkeyAuthentication" "yes"
                update_sshd_config "PasswordAuthentication" "yes"
                update_sshd_config "PermitRootLogin" "yes"
                port=$(get_sshd_config_value "port")
                [[ -z "$port" ]] && port="22"
                check_and_open_ufw_port "$port"
                config_changed=true; break ;;
            4)
                _log warn "警告：禁用密钥登录会降低服务器安全性！"
                if prompt_yes_no "您确定要这样做吗？(y/N) " "n"; then
                    change_root_password; optimize_ssh_speed
                    update_sshd_config "PubkeyAuthentication" "no"
                    update_sshd_config "PasswordAuthentication" "yes"
                    update_sshd_config "PermitRootLogin" "yes"
                    port=$(get_sshd_config_value "port")
                    [[ -z "$port" ]] && port="22"
                    check_and_open_ufw_port "$port"
                    config_changed=true; break
                else
                    _log info "操作已取消。"
                fi ;;
            5)
                if modify_ssh_port; then config_changed=true; break; fi
                ;;
            6)
                change_root_password ;;
            0)
                if ! $config_changed; then
                    _log info "未进行任何配置更改，直接退出。"
                    exit 0
                fi
                break ;;
            *)
                _log error "无效选择，请重新输入。" ;;
        esac
    done

    if $config_changed; then
        if ! validate_and_restart_ssh; then
            _log error "配置过程出现问题，请检查以上日志。"
            exit 1
        fi
    fi

    local final_port final_ip
    final_port=$(get_sshd_config_value "port")
    final_ip=$(hostname -I | awk '{print $1}')
    printf "\n"
    _log info "最终连接信息"
    printf "连接命令: %ssh root@%s -p %s%s\n" "$color_green" "$final_ip" "$final_port" "$color_reset"
    _log warn "[!] 重要安全提醒：请立即打开一个新的终端窗口，使用新配置测试SSH连接，确认无误后再关闭当前会话！"
    show_completion
}

main "$@"
