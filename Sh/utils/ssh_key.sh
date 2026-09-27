#!/usr/bin/env bash

# ==============================================================================
# Linux SSH 安全配置与密钥加固脚本
# 项目地址: https://github.com/Silentely/Demo
#
# 功能特性:
# 1. 优先采用 /etc/ssh/sshd_config.d/00-security.conf (drop-in)，彻底解决
#    50-cloud-init.conf 与云厂商 99-*.conf 覆盖 PasswordAuthentication 的问题。
# 2. 完美适配 Ubuntu 24.04+ ssh.socket 激活机制，避免修改端口后新端口无法监听。
# 3. 自动检测并放行本机防火墙（UFW / Firewalld）及 SELinux 端口策略。
# 4. 配置修改前后自动语法检查（sshd -t），支持故障自动回滚与备份轮转。
# 5. 支持非交互式 CLI 参数（-a, -k, -p, -y），管道安全重定向（exec < /dev/tty）。
# ==============================================================================

# 若从管道运行，重定向输入流以保证交互可用
if [ -t 0 ]; then
    :
elif [ -e /dev/tty ]; then
    exec < /dev/tty
fi

# 颜色与样式配置
if [[ -t 1 ]]; then
    color_blue='\033[0;34m'
    color_green='\033[0;32m'
    color_yellow='\033[0;33m'
    color_red='\033[0;31m'
    color_bold='\033[1m'
    color_reset='\033[0m'
else
    color_blue=''
    color_green=''
    color_yellow=''
    color_red=''
    color_bold=''
    color_reset=''
fi

readonly PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJWYt+IEmAg9n30UBVyQgeDECsSmfS+Jwb1nO93rao0d"
readonly PROJECT_URL="https://github.com/Silentely/Demo"
readonly PROJECT_NAME="@Silentely/Demo"

readonly SSHD_CONFIG="/etc/ssh/sshd_config"
readonly SSHD_CONFIG_D="/etc/ssh/sshd_config.d"
readonly DROPIN_CONF="/etc/ssh/sshd_config.d/00-security.conf"

# 全局状态变量
NON_INTERACTIVE=false
BACKUP_MAIN_CONFIG=""
BACKUP_DROPIN_CONFIG=""
DROPIN_WAS_NEW=false
ORIG_PORT=""

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

choose_overwrite_or_append() {
    local file="$1"
    if [[ -s "$file" ]]; then
        _log warn "$file 已存在且非空。"
        if prompt_yes_no "是否覆盖原有内容？(Y=覆盖，n=追加) " "n"; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

check_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        _log error "此脚本需要以 root 权限运行，请使用 'sudo ./script.sh'。"
        exit 1
    fi
}

get_pubkey_fingerprint() {
    local key_str="$1"
    if command -v ssh-keygen >/dev/null 2>&1; then
        local fp
        fp=$(printf "%s\n" "$key_str" | ssh-keygen -lf /dev/stdin 2>/dev/null)
        if [[ -n "$fp" ]]; then
            echo "$fp"
            return
        fi
    fi
    echo "$key_str"
}

fetch_github_keys() {
    local username="$1"
    local url="https://github.com/${username}.keys"
    local keys=""
    if command -v curl >/dev/null 2>&1; then
        keys=$(curl -fsSL --connect-timeout 8 --max-time 15 "$url" 2>/dev/null)
    elif command -v wget >/dev/null 2>&1; then
        keys=$(wget -qO- --timeout=15 "$url" 2>/dev/null)
    fi
    keys=$(echo "$keys" | grep -E "^(ssh-(rsa|ed25519|dss)|ecdsa-sha2-[a-z0-9-]+|sk-(ssh|ecdsa)-[a-z0-9@.-]+)" || true)
    echo "$keys"
}

show_header() {
    clear
    printf "%s\n" "=================================================================="
    printf "  Linux SSH 安全配置脚本 \n"
    printf "  项目地址: %s  %s\n" "$PROJECT_NAME" "$PROJECT_URL"
    printf "%s\n" "=================================================================="
}

show_env_info() {
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
    distro=$(grep -oP '(?<=^PRETTY_NAME=").*(?="$)' /etc/os-release 2>/dev/null || lsb_release -ds 2>/dev/null || uname -s)
    os=$(uname -s)
    arch=$(uname -m)
    time_now=$(date +"%Y-%m-%d %H:%M:%S %Z")
    host=$(hostname)
    printf "  主机名称: %s\n" "$host"
    printf "  系统发行: %s (%s)\n" "$distro" "$os"
    printf "  系统架构: %s\n" "$arch"
    printf "  当前时间: %s\n" "$time_now"
    echo "------------------------------------------------------------------"
}

show_status_info() {
    _log info "SSH 服务当前配置状态"
    local cur_port cur_permit_root cur_pwd_auth
    cur_port=$(get_sshd_config_value "port")
    [[ -z "$cur_port" ]] && cur_port="22 (默认)"

    cur_permit_root=$(get_sshd_config_value "permitrootlogin")
    [[ -z "$cur_permit_root" ]] && cur_permit_root="prohibit-password / 默认"

    cur_pwd_auth=$(get_sshd_config_value "passwordauthentication")
    [[ -z "$cur_pwd_auth" ]] && cur_pwd_auth="yes (默认)"

    printf "  SSH 服务端口:       %s\n" "$cur_port"
    printf "  允许 Root 登录:     %s\n" "$cur_permit_root"
    printf "  密码认证登录:       %s\n" "$cur_pwd_auth"

    if [[ -d "$SSHD_CONFIG_D" ]]; then
        local dropin_count
        dropin_count=$(find "$SSHD_CONFIG_D" -maxdepth 1 -name "*.conf" 2>/dev/null | wc -l)
        printf "  Drop-in 配置目录:   %s (发现 %s 个配置片段)\n" "$SSHD_CONFIG_D" "$dropin_count"
        if [[ -f "$DROPIN_CONF" ]]; then
            printf "  优先安全配置:       %s (已就绪)\n" "$DROPIN_CONF"
        fi
    fi
    echo "------------------------------------------------------------------"
}

show_completion() {
    echo "=================================================================="
    _log success "配置应用完成！"
    echo "=================================================================="
}

get_ssh_service_name() {
    if command -v systemctl >/dev/null 2>&1; then
        if systemctl list-unit-files 2>/dev/null | grep -q "^ssh\.service"; then
            echo "ssh"
            return
        elif systemctl list-unit-files 2>/dev/null | grep -q "^sshd\.service"; then
            echo "sshd"
            return
        fi
    fi
    if [[ -f /etc/init.d/ssh ]]; then
        echo "ssh"
    else
        echo "sshd"
    fi
}

get_sshd_config_value() {
    local key="$1"
    local value=""

    if command -v sshd >/dev/null 2>&1; then
        value=$(sshd -T 2>/dev/null | grep -i "^${key} " | head -n 1 | awk '{print $2}')
        if [[ -n "$value" ]]; then
            echo "$value"
            return
        fi
    fi

    if [[ -f "$DROPIN_CONF" ]]; then
        value=$(grep -iE "^\s*${key}\s+" "$DROPIN_CONF" 2>/dev/null | tail -n 1 | awk '{print $2}')
        if [[ -n "$value" ]]; then
            echo "$value"
            return
        fi
    fi

    if [[ -f "$SSHD_CONFIG" ]]; then
        value=$(grep -iE "^\s*${key}\s+" "$SSHD_CONFIG" 2>/dev/null | tail -n 1 | awk '{print $2}')
        if [[ -n "$value" ]]; then
            echo "$value"
            return
        fi
    fi

    echo ""
}

ensure_dropin_included() {
    if [[ ! -d "$SSHD_CONFIG_D" ]]; then
        mkdir -p "$SSHD_CONFIG_D"
        chmod 755 "$SSHD_CONFIG_D"
    fi

    if [[ -f "$SSHD_CONFIG" ]]; then
        if ! grep -qiE "^\s*Include\s+.*sshd_config.d" "$SSHD_CONFIG"; then
            _log info "在主配置文件第一行注入 'Include /etc/ssh/sshd_config.d/*.conf'..."
            sed -i '1i Include /etc/ssh/sshd_config.d/*.conf\n' "$SSHD_CONFIG"
        fi
    fi
}

apply_security_policy() {
    local mode="$1"
    local port="${2:-22}"

    ensure_dropin_included

    local pwd_auth="yes"
    local permit_root="yes"
    local pubkey_auth="yes"

    case "$mode" in
        "key_only")
            pwd_auth="no"
            permit_root="prohibit-password"
            pubkey_auth="yes"
            ;;
        "pwd_only")
            pwd_auth="yes"
            permit_root="yes"
            pubkey_auth="no"
            ;;
        "both")
            pwd_auth="yes"
            permit_root="yes"
            pubkey_auth="yes"
            ;;
    esac

    _log info "写入高优先级配置片段: $DROPIN_CONF"
    cat > "$DROPIN_CONF" <<EOF
# ==============================================================================
# Managed by Demo SSH Security Script (Highest Priority 00-security.conf)
# OpenSSH applies the first matched setting. Drop-ins here take precedence over
# cloud-init (50-cloud-init.conf) and cloud provider configs (99-*.conf).
# ==============================================================================
Port ${port}
PasswordAuthentication ${pwd_auth}
PubkeyAuthentication ${pubkey_auth}
PermitRootLogin ${permit_root}
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
EOF
    chmod 644 "$DROPIN_CONF"

    update_main_sshd_config "Port" "$port"
    update_main_sshd_config "PasswordAuthentication" "$pwd_auth"
    update_main_sshd_config "PubkeyAuthentication" "$pubkey_auth"
    update_main_sshd_config "PermitRootLogin" "$permit_root"
    update_main_sshd_config "KbdInteractiveAuthentication" "no"
    update_main_sshd_config "ChallengeResponseAuthentication" "no"
}

update_main_sshd_config() {
    local key="$1"
    local value="$2"
    [[ ! -f "$SSHD_CONFIG" ]] && return 0

    if grep -q -i -E "^\s*#?\s*${key}\s+" "$SSHD_CONFIG"; then
        sed -i -E "s/^\s*#?\s*(${key}\s+).*/\1${value}/I" "$SSHD_CONFIG"
    else
        echo "${key} ${value}" >> "$SSHD_CONFIG"
    fi
}

handle_ubuntu_socket_activation() {
    if command -v systemctl >/dev/null 2>&1; then
        if systemctl is-active --quiet ssh.socket 2>/dev/null || systemctl is-enabled --quiet ssh.socket 2>/dev/null; then
            _log info "检测到系统采用 systemd socket 激活机制 (ssh.socket)..."
            _log info "正在切换为常驻服务模式 (ssh.service) 以支持自定义端口并确保稳定监听..."
            systemctl disable --now ssh.socket 2>/dev/null
            systemctl daemon-reload 2>/dev/null
            systemctl enable --now ssh.service 2>/dev/null
        fi
    fi
}

backup_configs() {
    if [[ -n "$BACKUP_MAIN_CONFIG" ]]; then
        return 0
    fi

    ORIG_PORT=$(get_sshd_config_value "port")
    [[ -z "$ORIG_PORT" ]] && ORIG_PORT="22"

    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)

    if [[ -f "$SSHD_CONFIG" ]]; then
        BACKUP_MAIN_CONFIG="/etc/ssh/sshd_config.bak_${timestamp}"
        cp "$SSHD_CONFIG" "$BACKUP_MAIN_CONFIG"
        _log info "主配置文件已备份至: $BACKUP_MAIN_CONFIG"
    fi

    if [[ -f "$DROPIN_CONF" ]]; then
        BACKUP_DROPIN_CONFIG="${DROPIN_CONF}.bak_${timestamp}"
        cp "$DROPIN_CONF" "$BACKUP_DROPIN_CONFIG"
        DROPIN_WAS_NEW=false
    else
        DROPIN_WAS_NEW=true
    fi

    ls -t /etc/ssh/sshd_config.bak_* 2>/dev/null | tail -n +6 | xargs -r rm -f 2>/dev/null
    ls -t /etc/ssh/sshd_config.d/00-security.conf.bak_* 2>/dev/null | tail -n +6 | xargs -r rm -f 2>/dev/null
}

rollback_configs() {
    _log warn "正在自动回滚所有 SSH 配置文件..."
    if [[ -n "$BACKUP_MAIN_CONFIG" && -f "$BACKUP_MAIN_CONFIG" ]]; then
        cp "$BACKUP_MAIN_CONFIG" "$SSHD_CONFIG"
        _log info "已恢复主配置文件: $SSHD_CONFIG"
    fi

    if $DROPIN_WAS_NEW; then
        rm -f "$DROPIN_CONF"
        _log info "已清理新增的配置: $DROPIN_CONF"
    elif [[ -n "$BACKUP_DROPIN_CONFIG" && -f "$BACKUP_DROPIN_CONFIG" ]]; then
        cp "$BACKUP_DROPIN_CONFIG" "$DROPIN_CONF"
        _log info "已恢复安全配置片段: $DROPIN_CONF"
    fi

    if [[ -n "$ORIG_PORT" ]]; then
        check_and_open_firewall_port "$ORIG_PORT"
    fi
}

test_and_fix_sshd_syntax() {
    if ! command -v sshd >/dev/null 2>&1; then
        return 0
    fi

    local test_output
    test_output=$(sshd -t 2>&1)
    local test_status=$?

    if [ $test_status -eq 0 ]; then
        return 0
    fi

    _log warn "检测到 SSH 语法存在冲突或错误:"
    echo "$test_output"

    local bad_line bad_file
    bad_line=$(echo "$test_output" | grep -oP '(?<=line )[0-9]+' | head -n 1)
    bad_file=$(echo "$test_output" | grep -oP '/etc/ssh/[^:]+' | head -n 1)

    if [[ -n "$bad_line" && -n "$bad_file" && -f "$bad_file" ]]; then
        _log warn "尝试注释引起错误的配置行: $bad_file 第 $bad_line 行..."
        sed -i "${bad_line}s/^/#/" "$bad_file"
        if sshd -t >/dev/null 2>&1; then
            _log success "语法错误已自动修正。"
            return 0
        fi
    fi

    return 1
}

validate_and_restart_ssh() {
    _log info "正在对生成的完整 SSH 配置进行语法检测 (sshd -t)..."
    if ! test_and_fix_sshd_syntax; then
        _log error "新的 SSH 配置语法检查失败！"
        rollback_configs
        return 1
    fi

    _log success "SSH 配置语法检查通过。"
    local service_name
    service_name=$(get_ssh_service_name)

    handle_ubuntu_socket_activation

    if ! command -v systemctl >/dev/null 2>&1; then
        _log warn "当前环境未发现 systemctl，正在尝试使用 service 重启..."
        if service "$service_name" restart; then
            _log success "SSH 服务重启成功。"
            return 0
        else
            _log error "SSH 服务重启失败！"
            rollback_configs
            return 1
        fi
    fi

    local should_restart=true
    if [[ "$NON_INTERACTIVE" != true ]]; then
        if ! prompt_yes_no "是否立即重启 SSH 服务以应用更改？(Y/n) "; then
            should_restart=false
        fi
    fi

    if [[ "$should_restart" == true ]]; then
        _log info "正在重启 SSH 服务 ($service_name)..."
        if ! systemctl restart "$service_name"; then
             _log error "SSH 服务重启失败！正在回滚配置..."
             rollback_configs
             systemctl restart "$service_name" 2>/dev/null
             _log error "请检查系统日志: journalctl -u $service_name"
             return 1
        fi
        sleep 1
        if systemctl is-active --quiet "$service_name"; then
            _log success "SSH 服务重启成功。"
            if command -v ss >/dev/null 2>&1; then
                local listening_ports
                listening_ports=$(ss -tlpn 2>/dev/null | grep -E 'sshd|systemd' | grep -oE ':[0-9]+' | tr -d ':' | sort -un | tr '\n' ' ')
                [[ -n "$listening_ports" ]] && _log info "当前系统 SSH 服务实际监听端口: ${listening_ports}"
            fi
        else
            _log error "SSH 服务启动失败！正在自动回滚..."
            rollback_configs
            systemctl restart "$service_name" 2>/dev/null
            return 1
        fi
    else
        _log warn "配置已保存但未生效。请稍后手动重启服务: systemctl restart $service_name"
    fi
    return 0
}

add_hardcoded_pubkey() {
    local ssh_dir="/root/.ssh"
    local auth_keys_file="$ssh_dir/authorized_keys"
    mkdir -p "$ssh_dir" && chmod 700 "$ssh_dir"
    touch "$auth_keys_file" && chmod 600 "$auth_keys_file"

    local fp
    fp=$(get_pubkey_fingerprint "$PUBKEY")
    _log info "作者预设公钥指纹信息："
    printf "  %s%s%s\n" "${color_bold}" "$fp" "${color_reset}"

    if [[ "$NON_INTERACTIVE" != true ]]; then
        if ! prompt_yes_no "确认要将作者预设公钥注入到 root 的 authorized_keys 吗？(y/N) " "n"; then
            _log warn "用户取消了作者公钥注入。"
            return 1
        fi
    fi

    if grep -qF -- "$PUBKEY" "$auth_keys_file"; then
        _log info "内置公钥已存在，无需重复添加。"
    else
        if [[ "$NON_INTERACTIVE" == true ]]; then
            echo "$PUBKEY" >> "$auth_keys_file"
            _log success "内置公钥已追加。"
        else
            if choose_overwrite_or_append "$auth_keys_file"; then
                echo "$PUBKEY" > "$auth_keys_file"
                _log success "内置公钥已覆盖写入。"
            else
                echo "$PUBKEY" >> "$auth_keys_file"
                _log success "内置公钥已追加。"
            fi
        fi
    fi
    return 0
}

setup_custom_key() {
    local ssh_dir="/root/.ssh"
    local auth_keys_file="$ssh_dir/authorized_keys"
    mkdir -p "$ssh_dir" && chmod 700 "$ssh_dir"
    touch "$auth_keys_file" && chmod 600 "$auth_keys_file"

    _log info "选择公钥导入方式："
    echo "  1. 粘贴自定义公钥"
    echo "  2. 从 GitHub 用户名拉取公钥"
    echo "  3. 本机生成新的密钥对 (Ed25519 / RSA)"
    local key_choice
    read -r -p "$(printf "%s>> 请选择方式 (1-3): %s" "$color_bold" "$color_reset")" key_choice

    if [[ "$key_choice" == "2" ]]; then
        local gh_user
        read -r -p "$(printf "%s>> 请输入 GitHub 用户名: %s" "$color_bold" "$color_reset")" gh_user
        if [[ -z "$gh_user" ]]; then
            _log error "用户名不能为空！"
            return 1
        fi
        _log info "正在拉取 GitHub 用户 [$gh_user] 的公钥..."
        local gh_keys
        gh_keys=$(fetch_github_keys "$gh_user")
        if [[ -z "$gh_keys" ]]; then
            _log error "未拉取到有效公钥，请确认用户名或网络连接。"
            return 1
        fi
        echo "$gh_keys" >> "$auth_keys_file"
        _log success "GitHub 用户 [$gh_user] 的公钥已导入！"
        return 0
    elif [[ "$key_choice" == "1" ]]; then
        _log info "请直接粘贴公钥内容（一行），或多行粘贴后按 Ctrl+D 结束："
        local pubkey first_line
        IFS= read -r first_line
        if [[ -n "$first_line" ]]; then
            if echo "$first_line" | grep -qE "^(ssh-(rsa|ed25519|dss)|ecdsa-sha2-[a-z0-9-]+|sk-(ssh|ecdsa)-[a-z0-9@.-]+)"; then
                pubkey="$first_line"
            else
                pubkey="${first_line}"$'\n'$(cat)
            fi
        else
            pubkey=$(cat)
        fi

        pubkey=$(echo "$pubkey" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

        if [[ -z "$pubkey" ]]; then
            _log error "未输入任何内容，操作取消。"
            return 1
        fi

        if ! echo "$pubkey" | grep -qE "^(ssh-(rsa|ed25519|dss)|ecdsa-sha2-[a-z0-9-]+|sk-(ssh|ecdsa)-[a-z0-9@.-]+)"; then
            _log error "无效的公钥格式！必须以 ssh-*, ecdsa-* 或 sk-* 开头。"
            return 1
        fi

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
        local key_type key_opts choice key_path
        read -r -p "$(printf "%s>> 请选择密钥类型 (1) Ed25519 [推荐] (2) RSA-4096: %s" "$color_bold" "$color_reset")" choice
        case "$choice" in
            2) key_type="rsa"; key_opts="-t rsa -b 4096" ;;
            *) key_type="ed25519"; key_opts="-t ed25519" ;;
        esac
        key_path="$ssh_dir/generated_key_$key_type"
        if [[ -f "$key_path" ]]; then
            _log warn "密钥文件 $key_path 已存在。将跳过生成。"
        else
            _log info "正在生成 ${key_type^^} 密钥对..."
            if ! ssh-keygen ${key_opts} -N "" -f "$key_path"; then
                _log error "密钥生成失败！"
                return 1
            fi
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

change_root_password() {
    if prompt_yes_no "是否现在修改 root 用户的密码？(y/N) " "n"; then
        passwd root
    fi
}

check_and_open_firewall_port() {
    local port="${1:-22}"

    if command -v ufw >/dev/null 2>&1; then
        if ufw status | grep -q -E "Status: active"; then
            if ! ufw status | grep -qw "$port"; then
                _log info "检测到 ufw 已启用，正在开放端口 $port/tcp..."
                ufw allow "$port"/tcp
                _log success "已在 ufw 开放端口 $port/tcp"
            else
                _log info "ufw 端口 $port/tcp 已经在规则中"
            fi
        else
            if ! ufw status | grep -qw "$port"; then
                _log info "ufw 已安装但未启用，已预设开放端口 $port/tcp"
                ufw allow "$port"/tcp
            fi
        fi
    fi

    if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld 2>/dev/null; then
        _log info "检测到 firewalld 正在运行，正在开放端口 $port/tcp..."
        if firewall-cmd --zone=public --add-port="${port}/tcp" --permanent >/dev/null 2>&1; then
            firewall-cmd --reload >/dev/null 2>&1
            _log success "已在 firewalld 开放端口 $port/tcp"
        else
            _log warn "在 firewalld 中开放端口 $port 失败，请手动检查"
        fi
    fi

    if command -v getenforce >/dev/null 2>&1; then
        if [[ "$(getenforce)" == "Enforcing" && "$port" != "22" ]]; then
            _log warn "检测到系统启用了 SELinux 强制模式 (Enforcing)！"
            if command -v semanage >/dev/null 2>&1; then
                _log info "正在尝试为 SELinux 添加 SSH 端口 $port 策略..."
                semanage port -a -t ssh_port_t -p tcp "$port" 2>/dev/null || \
                semanage port -m -t ssh_port_t -p tcp "$port" 2>/dev/null
                _log success "SELinux 端口策略已更新"
            else
                _log warn "未安装 semanage 工具！若 SSH 重启失败，请运行: semanage port -a -t ssh_port_t -p tcp $port 或临时 setenforce 0"
            fi
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

    if [[ -f "$DROPIN_CONF" ]]; then
        if grep -qE "^\s*Port\s+" "$DROPIN_CONF"; then
            sed -i -E "s/^\s*Port\s+.*/Port ${new_port}/" "$DROPIN_CONF"
        else
            sed -i "1i Port ${new_port}" "$DROPIN_CONF"
        fi
    fi
    update_main_sshd_config "Port" "$new_port"

    _log success "SSH 端口已计划更改为 $new_port。"
    check_and_open_firewall_port "$new_port"
    return 0
}

show_help() {
    printf "用法: bash %s [选项]\n\n" "$0"
    printf "选项:\n"
    printf "  -a, --author [USER]      使用作者预设公钥（或传入 GitHub 用户名拉取）并禁用密码认证\n"
    printf "  -k, --key <PUBLIC_KEY>   导入指定公钥并禁用密码认证\n"
    printf "  -p, --port <PORT>        修改 SSH 服务端口号 (1-65535)\n"
    printf "  -y, --yes                非交互模式，跳过所有交互提示自动执行\n"
    printf "  -h, --help               显示帮助信息\n\n"
    printf "无参数运行则进入交互式向导模式。\n"
}

main() {
    for arg in "$@"; do
        if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
            show_help
            exit 0
        fi
    done

    check_root

    if [[ $# -gt 0 ]]; then
        NON_INTERACTIVE=true
        local cli_mode=""
        local cli_author_user=""
        local cli_key=""
        local cli_port=""

        while [[ $# -gt 0 ]]; do
            case "$1" in
                -a|--author)
                    cli_mode="author"
                    if [[ $# -gt 1 && ! "$2" =~ ^- ]]; then
                        cli_author_user="$2"
                        shift 2
                    else
                        shift
                    fi
                    ;;
                -k|--key)
                    cli_mode="custom"
                    cli_key="$2"
                    shift 2 ;;
                -p|--port)
                    cli_port="$2"
                    shift 2 ;;
                -y|--yes)
                    NON_INTERACTIVE=true
                    shift ;;
                *)
                    _log error "未知参数: $1"
                    show_help
                    exit 1 ;;
            esac
        done

        backup_configs
        local target_port
        target_port="${cli_port:-$(get_sshd_config_value "port")}"
        [[ -z "$target_port" ]] && target_port="22"

        if [[ -n "$cli_port" ]]; then
            if ! [[ "$cli_port" =~ ^[0-9]+$ ]] || [ "$cli_port" -lt 1 ] || [ "$cli_port" -gt 65535 ]; then
                _log error "无效的端口号: $cli_port"
                exit 1
            fi
        fi

        if [[ "$cli_mode" == "author" ]]; then
            if [[ -n "$cli_author_user" ]]; then
                _log info "正在获取 GitHub 用户 [$cli_author_user] 的公钥..."
                local gh_keys
                gh_keys=$(fetch_github_keys "$cli_author_user")
                if [[ -n "$gh_keys" ]]; then
                    local ssh_dir="/root/.ssh"
                    mkdir -p "$ssh_dir" && chmod 700 "$ssh_dir"
                    echo "$gh_keys" >> "$ssh_dir/authorized_keys"
                    chmod 600 "$ssh_dir/authorized_keys"
                    _log success "已注入 GitHub 用户 [$cli_author_user] 的公钥。"
                else
                    _log warn "未获取到 GitHub 用户 [$cli_author_user] 的公钥，使用预设作者公钥。"
                    add_hardcoded_pubkey
                fi
            else
                add_hardcoded_pubkey
            fi
            apply_security_policy "key_only" "$target_port"
        elif [[ "$cli_mode" == "custom" ]]; then
            if [[ -z "$cli_key" ]]; then
                _log error "未提供公钥内容！"
                exit 1
            fi
            local ssh_dir="/root/.ssh"
            mkdir -p "$ssh_dir" && chmod 700 "$ssh_dir"
            echo "$cli_key" >> "$ssh_dir/authorized_keys"
            chmod 600 "$ssh_dir/authorized_keys"
            apply_security_policy "key_only" "$target_port"
        elif [[ -n "$cli_port" ]]; then
            if [[ -f "$DROPIN_CONF" ]]; then
                sed -i -E "s/^\s*Port\s+.*/Port ${cli_port}/" "$DROPIN_CONF" 2>/dev/null || sed -i "1i Port ${cli_port}" "$DROPIN_CONF"
            fi
            update_main_sshd_config "Port" "$cli_port"
        fi

        check_and_open_firewall_port "$target_port"

        if ! validate_and_restart_ssh; then
            _log error "SSH 重启验证失败，已自动回滚！"
            exit 1
        fi
        _log success "非交互模式执行完成！当前端口: $target_port"
        exit 0
    fi

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
        echo "0. 完成配置并应用"
        printf "%s\n" "------------------------------------------------------------------"
        local choice
        read -r -p "$(printf "%s>> 请选择操作编号: %s" "$color_bold" "$color_reset")" choice
        case "$choice" in
            1)
                _log warn "您选择了作者专用模式，将使用脚本内置的公钥。"
                backup_configs
                if ! add_hardcoded_pubkey; then continue; fi
                port=$(get_sshd_config_value "port")
                [[ -z "$port" ]] && port="22"
                apply_security_policy "key_only" "$port"
                check_and_open_firewall_port "$port"
                config_changed=true
                if ! prompt_yes_no "是否继续配置其他选项？(y/N) " "n"; then break; fi
                ;;
            2)
                _log info "将配置为仅限使用您自己的公钥登录。"
                if ! setup_custom_key; then continue; fi
                backup_configs
                port=$(get_sshd_config_value "port")
                [[ -z "$port" ]] && port="22"
                apply_security_policy "key_only" "$port"
                check_and_open_firewall_port "$port"
                config_changed=true
                if ! prompt_yes_no "是否继续配置其他选项？(y/N) " "n"; then break; fi
                ;;
            3)
                _log info "将配置为允许密钥和密码两种登录方式。"
                if ! setup_custom_key; then continue; fi
                change_root_password
                backup_configs
                port=$(get_sshd_config_value "port")
                [[ -z "$port" ]] && port="22"
                apply_security_policy "both" "$port"
                check_and_open_firewall_port "$port"
                config_changed=true
                if ! prompt_yes_no "是否继续配置其他选项？(y/N) " "n"; then break; fi
                ;;
            4)
                _log warn "警告：禁用密钥登录会降低服务器安全性！"
                if prompt_yes_no "您确定要这样做吗？(y/N) " "n"; then
                    change_root_password
                    backup_configs
                    port=$(get_sshd_config_value "port")
                    [[ -z "$port" ]] && port="22"
                    apply_security_policy "pwd_only" "$port"
                    check_and_open_firewall_port "$port"
                    config_changed=true
                    if ! prompt_yes_no "是否继续配置其他选项？(y/N) " "n"; then break; fi
                else
                    _log info "操作已取消。"
                fi ;;
            5)
                backup_configs
                if modify_ssh_port; then
                    config_changed=true
                    if ! prompt_yes_no "是否继续配置其他选项？(y/N) " "n"; then break; fi
                fi
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
            _log error "配置过程出现问题，已回滚更改，请检查日志。"
            exit 1
        fi
    fi

    local final_port final_ip
    final_port=$(get_sshd_config_value "port")
    [[ -z "$final_port" ]] && final_port="22"
    final_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    [[ -z "$final_ip" ]] && final_ip="你的服务器IP"
    printf "\n"
    _log info "最终连接信息"
    printf "连接命令: %ssh root@%s -p %s%s\n" "$color_green" "$final_ip" "$final_port" "$color_reset"

    if [[ "$final_port" != "22" ]]; then
        printf "\n"
        _log warn "=================================================================="
        _log warn "[!] 云服务商安全组提醒："
        _log warn "如果您的 VPS 位于阿里云、腾讯云、华为云、AWS、GCP 或甲骨文云等平台，"
        _log warn "除本机防火墙外，请务必前往【云控制台 -> 安全组 / 防火墙】"
        _log warn "放行 TCP 端口: $final_port，否则外网将无法连入！"
        _log warn "=================================================================="
    fi

    _log warn "[!] 重要安全提醒：请立即打开一个新的终端窗口，使用新配置测试SSH连接，确认无误后再关闭当前会话！"
    show_completion
}

main "$@"
