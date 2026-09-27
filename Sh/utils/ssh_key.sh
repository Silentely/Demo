#!/bin/bash
#
# ==============================================================================
# Linux SSH Security Enhancement & Configuration Script
#
# Description: A tool to quickly and safely configure SSH server settings on
#              Linux systems, focusing on security best practices.
# Author:      @Silentely/Demo
# ==============================================================================

# --- 终端输入保护（支持 curl ... | bash 管道式运行） ---
if [[ ! -t 0 ]] && { true < /dev/tty; } 2>/dev/null; then
    exec < /dev/tty 2>/dev/null || true
fi

# --- 全局常量和颜色定义 ---
if command -v tput >/dev/null 2>&1 && tput setaf 1 >/dev/null 2>&1; then
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

readonly SSHD_CONFIG="/etc/ssh/sshd_config"
readonly SSHD_CONFIG_D="/etc/ssh/sshd_config.d"
readonly DROPIN_CONF="/etc/ssh/sshd_config.d/00-security.conf"

# 全局备份追踪变量（用于失败时精准回滚）
BACKUP_MAIN_CONFIG=""
BACKUP_DROPIN_CONFIG=""
DROPIN_WAS_NEW=false

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

# 选择覆盖或追加公钥
choose_overwrite_or_append() {
    local file="$1"
    if [[ -s "$file" ]]; then
        _log warn "$file 已存在且非空。"
        if prompt_yes_no "是否覆盖原有内容？(Y=覆盖，n=追加) " "n"; then
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
    arch=$(uname -m)
    os="$distro $arch"
    time_now=$(date +"%Y-%m-%d %H:%M %Z")
    host=$(hostname)
    printf "主机名    : %s%s%s\n" "$color_yellow" "$host" "$color_reset"
    printf "环境      : %s%s%s\n" "$color_yellow" "$os" "$color_reset"
    printf "时间      : %s%s%s\n" "$color_green" "$time_now" "$color_reset"
    echo
}

# 按照 First-Match 原则与 sshd -T 真实状态读取配置
get_sshd_config_value() {
    local key="$1"
    local val=""

    # 1. 优先使用 sshd -T 获取当前运行时解析出的最终生效值
    val=$(sshd -T 2>/dev/null | grep -iE "^${key}\s+" | awk '{print $2}' | head -n 1)
    if [[ -n "$val" ]]; then
        echo "$val"
        return 0
    fi

    # 2. 静态解析 Fallback（严格遵守 First-Match 原则）
    # 2.1 检查 drop-in 目录（字典序排在最前的有效非注释配置）
    if [[ -d "$SSHD_CONFIG_D" ]]; then
        for conf in "$SSHD_CONFIG_D"/*.conf; do
            [[ -f "$conf" ]] || continue
            val=$(grep -iE "^\s*${key}\s+" "$conf" 2>/dev/null | grep -v '^\s*#' | awk '{print $2}' | head -n 1)
            if [[ -n "$val" ]]; then
                echo "$val"
                return 0
            fi
        done
    fi

    # 2.2 检查主配置文件（排除注释，取第一条匹配值）
    if [[ -f "$SSHD_CONFIG" ]]; then
        val=$(grep -iE "^\s*${key}\s+" "$SSHD_CONFIG" 2>/dev/null | grep -v '^\s*#' | awk '{print $2}' | head -n 1)
        if [[ -n "$val" ]]; then
            echo "$val"
            return 0
        fi
    fi

    echo ""
}

show_status_info() {
    _log info "SSH 运行状态"
    local port auth pubkey_auth connections sshd_status lan_ip wan_ip_v4 wan_ip_v6 wan_ip
    port=$(get_sshd_config_value "port")
    [[ -z "$port" ]] && port="22"
    auth=$(get_sshd_config_value "passwordauthentication")
    [[ -z "$auth" ]] && auth="未知"
    pubkey_auth=$(get_sshd_config_value "pubkeyauthentication")
    [[ -z "$pubkey_auth" ]] && pubkey_auth="未知"

    lan_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    [[ -z "$lan_ip" ]] && lan_ip="127.0.0.1"

    # 超时设为 2 秒，避免国内外网络阻断导致长时间卡顿
    wan_ip_v4=$(curl -s --max-time 2 ip.sb -4 2>/dev/null || curl -s --max-time 2 api4.ipify.org 2>/dev/null)
    [[ -z "$wan_ip_v4" ]] && wan_ip_v4="IPV4获取超时"
    wan_ip_v6=$(curl -s --max-time 2 ip.sb -6 2>/dev/null || curl -s --max-time 2 api6.ipify.org 2>/dev/null)
    [[ -z "$wan_ip_v6" ]] && wan_ip_v6="IPV6获取超时"
    wan_ip="${wan_ip_v4}/${wan_ip_v6}"

    connections_val=$(ss -tun 2>/dev/null | grep -c ":$port" 2>/dev/null)
    connections=${connections_val:-"未知"}
    sshd_status_val=$(systemctl is-active sshd 2>/dev/null || systemctl is-active ssh 2>/dev/null || systemctl is-active ssh.socket 2>/dev/null)
    sshd_status=${sshd_status_val:-"未知"}

    printf "端口      : %s%s%s\n" "$color_yellow" "$port" "$color_reset"
    printf "密码认证  : %s%s%s\n" "$color_yellow" "$auth" "$color_reset"
    printf "密钥认证  : %s%s%s\n" "$color_yellow" "$pubkey_auth" "$color_reset"
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

# 确保 drop-in 目录在主配置文件顶部被 Include 引入
ensure_sshd_config_d_supported() {
    mkdir -p "$SSHD_CONFIG_D" && chmod 755 "$SSHD_CONFIG_D"
    if [[ -f "$SSHD_CONFIG" ]]; then
        if ! grep -qE "^\s*Include\s+/etc/ssh/sshd_config\.d/\*\.conf" "$SSHD_CONFIG"; then
            if ! grep -qiE "^\s*Include\s+.*sshd_config\.d" "$SSHD_CONFIG"; then
                _log info "在 $SSHD_CONFIG 首部添加 Include /etc/ssh/sshd_config.d/*.conf 以支持模块化配置"
                sed -i '1i Include /etc/ssh/sshd_config.d/*.conf\n' "$SSHD_CONFIG"
            fi
        fi
    fi
}

# 在主配置文件中更新配置（旧系统兼容或同步更新）
update_main_sshd_config() {
    local key="$1"
    local value="$2"
    if [[ -f "$SSHD_CONFIG" ]]; then
        if grep -qE "^\s*#?\s*${key}\s+" "$SSHD_CONFIG"; then
            sed -i -E "s/^\s*#?\s*${key}\s+.*/${key} ${value}/" "$SSHD_CONFIG"
        else
            echo "${key} ${value}" >> "$SSHD_CONFIG"
        fi
    fi
}

# 核心安全策略写入：使用 00-security.conf 解决 first-match 覆盖隐患
apply_security_policy() {
    local mode="$1" # "key_only", "both", "pwd_only"
    local port="$2"

    ensure_sshd_config_d_supported

    local pubkey_val="yes"
    local passwd_val="no"
    local kbd_val="no"
    local root_val="prohibit-password"

    case "$mode" in
        key_only)
            pubkey_val="yes"
            passwd_val="no"
            kbd_val="no"
            root_val="prohibit-password"
            ;;
        both)
            pubkey_val="yes"
            passwd_val="yes"
            kbd_val="yes"
            root_val="yes"
            ;;
        pwd_only)
            pubkey_val="no"
            passwd_val="yes"
            kbd_val="yes"
            root_val="yes"
            ;;
    esac

    # 写入 00-security.conf（由于前缀 00-，在 drop-in 目录中按字典序排在最前）
    # 彻底杜绝 50-cloud-init.conf 或 99-*.conf 的覆盖
    cat << EOF > "$DROPIN_CONF"
# ==============================================================================
# Managed by Demo SSH Security Script - Priority 00 (First match wins)
# 优先级说明：sshd 采用 First Match 机制，本文件排在首位以防止被其他配置覆盖
# ==============================================================================
Port ${port}
PubkeyAuthentication ${pubkey_val}
PasswordAuthentication ${passwd_val}
KbdInteractiveAuthentication ${kbd_val}
ChallengeResponseAuthentication ${kbd_val}
PermitRootLogin ${root_val}

# 连接速度优化（禁用耗时的 DNS 反向解析与 GSSAPI 超时）
UseDNS no
GSSAPIAuthentication no
TCPKeepAlive yes
ClientAliveInterval 60
ClientAliveCountMax 3
LoginGraceTime 30
EOF
    chmod 600 "$DROPIN_CONF"

    # 同步更新主配置文件中的基本项（双重保险，兼顾无 drop-in 工具）
    update_main_sshd_config "Port" "$port"
    update_main_sshd_config "PubkeyAuthentication" "$pubkey_val"
    update_main_sshd_config "PasswordAuthentication" "$passwd_val"
    update_main_sshd_config "PermitRootLogin" "$root_val"
    update_main_sshd_config "UseDNS" "no"
    update_main_sshd_config "GSSAPIAuthentication" "no"

    _log success "安全策略已写入优先配置: $DROPIN_CONF"
}

get_ssh_service_name() {
    # 1. 检查当前活跃的服务名
    for s in sshd ssh; do
        if systemctl is-active --quiet "$s" 2>/dev/null; then
            echo "$s"
            return 0
        fi
    done

    # 2. 检查已安装的 service 单元
    for s in sshd ssh; do
        if systemctl list-unit-files "${s}.service" 2>/dev/null | grep -qE "^${s}\.service"; then
            echo "$s"
            return 0
        fi
    done

    # 3. 兜底回退
    echo "sshd"
}

# 针对 Ubuntu 24.04+ systemd socket 激活机制的适配
# （若开启了 ssh.socket，改端口后 restart ssh 仍然只会监听 22，需禁用 socket 切换为原生 service）
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
    # 如果本次交互会话已经备份过，无需重复覆盖初始备份
    if [[ -n "$BACKUP_MAIN_CONFIG" ]]; then
        return 0
    fi

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

    # 自动维护备份轮转：保留最近 5 个备份文件，防止垃圾堆积
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
        _log info "已恢复原有优先配置: $DROPIN_CONF"
    fi
}

# 验证 sshd 语法并兼容 OpenSSH 版本的特定指令
test_and_fix_sshd_syntax() {
    local test_err
    test_err=$(sshd -t 2>&1)
    if [[ $? -eq 0 ]]; then
        return 0
    fi

    # 如果是因为较老版本 OpenSSH 不识别 KbdInteractiveAuthentication
    if echo "$test_err" | grep -qi "KbdInteractiveAuthentication"; then
        _log warn "检测到当前 OpenSSH 版本不支持 KbdInteractiveAuthentication，正在自动兼容处理..."
        sed -i '/KbdInteractiveAuthentication/d' "$DROPIN_CONF" 2>/dev/null
    fi

    # 如果是因为较新版本 OpenSSH 不识别 ChallengeResponseAuthentication
    if echo "$test_err" | grep -qi "ChallengeResponseAuthentication"; then
        _log warn "检测到当前 OpenSSH 版本不支持 ChallengeResponseAuthentication，正在自动兼容处理..."
        sed -i '/ChallengeResponseAuthentication/d' "$DROPIN_CONF" 2>/dev/null
    fi

    # 再次测试
    sshd -t
}

validate_and_restart_ssh() {
    if ! test_and_fix_sshd_syntax; then
        _log error "新的 SSH 配置语法检查失败！"
        rollback_configs
        return 1
    fi

    _log success "SSH 配置语法检查通过。"
    local service_name
    service_name=$(get_ssh_service_name)

    # 检查并处理 Ubuntu 24.04 的 socket 机制
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

    if prompt_yes_no "是否立即重启 SSH 服务以应用更改？(Y/n) "; then
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
            # 显示当前实际监听的 SSH 端口，让运维人员确认
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
        _log info "请直接粘贴公钥内容（一行），或多行粘贴后按 Ctrl+D 结束："
        local pubkey
        # 读取输入，支持单行回车直接识别或多行 cat
        IFS= read -r first_line
        if [[ -n "$first_line" ]]; then
            # 如果第一行已经是完整的有效 SSH 公钥
            if echo "$first_line" | grep -qE "^(ssh-(rsa|ed25519|dss)|ecdsa-sha2-[a-z0-9-]+|sk-(ssh|ecdsa)-[a-z0-9@.-]+)"; then
                pubkey="$first_line"
            else
                # 否则继续接收多行输入
                pubkey="${first_line}"$'\n'$(cat)
            fi
        else
            pubkey=$(cat)
        fi

        # 清除两端空格及 Windows 换行符 \r
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
        local key_type key_path key_opts choice
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

# 检测并开放防火墙端口（支持 UFW、Firewalld，并检查 SELinux）
check_and_open_firewall_port() {
    local port="${1:-22}"

    # 1. 检测与配置 UFW
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

    # 2. 检测与配置 Firewalld (CentOS/RHEL/AlmaLinux/RockyLinux/Fedora 标配)
    if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld 2>/dev/null; then
        _log info "检测到 firewalld 正在运行，正在开放端口 $port/tcp..."
        if firewall-cmd --zone=public --add-port="${port}/tcp" --permanent >/dev/null 2>&1; then
            firewall-cmd --reload >/dev/null 2>&1
            _log success "已在 firewalld 开放端口 $port/tcp"
        else
            _log warn "在 firewalld 中开放端口 $port 失败，请手动检查"
        fi
    fi

    # 3. 检测 SELinux (防止更改端口后导致 sshd 绑定端口失败失联)
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

    # 针对 00-security.conf 进行端口设定
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
    printf "  -a, --author             使用作者预设公钥登录并禁用密码认证\n"
    printf "  -k, --key <PUBLIC_KEY>   导入指定公钥并禁用密码认证\n"
    printf "  -p, --port <PORT>        修改 SSH 服务端口号 (1-65535)\n"
    printf "  -h, --help               显示帮助信息\n\n"
    printf "无参数运行则进入交互式向导模式。\n"
}

main() {
    # 优先响应帮助信息，无需 root 权限
    for arg in "$@"; do
        if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
            show_help
            exit 0
        fi
    done

    check_root

    # 处理命令行参数（支持自动化与非交互执行）
    if [[ $# -gt 0 ]]; then
        local cli_mode=""
        local cli_key=""
        local cli_port=""

        while [[ $# -gt 0 ]]; do
            case "$1" in
                -a|--author)
                    cli_mode="author"
                    shift ;;
                -k|--key)
                    cli_mode="custom"
                    cli_key="$2"
                    shift 2 ;;
                -p|--port)
                    cli_port="$2"
                    shift 2 ;;
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
            add_hardcoded_pubkey
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
            # 仅修改端口
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

    # 交互式模式
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
                if ! prompt_yes_no "确认继续吗？(Y/n) "; then continue; fi
                backup_configs
                add_hardcoded_pubkey
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
