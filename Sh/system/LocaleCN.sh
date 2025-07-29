#!/bin/bash
# ==============================================================================
# Modern Script to Set System Locale to Simplified Chinese (zh_CN.UTF-8)
# 现代化Linux系统中文语言环境设置脚本
#
# Description / 描述:
#   This script automates the process of setting the system-wide locale
#   to Simplified Chinese. It is designed for modern systemd-based Linux
#   distributions like CentOS 7+, RHEL 7+, Rocky, AlmaLinux, Debian,
#   and Ubuntu.
#   
#   本脚本自动化设置系统全局语言环境为简体中文。适用于现代化基于systemd的
#   Linux发行版，如CentOS 7+、RHEL 7+、Rocky、AlmaLinux、Debian和Ubuntu。
#
# Project / 项目地址: https://github.com/Silentely/Demo
#
# Usage / 使用方法:
#   sudo bash set_locale_cn.sh
# ==============================================================================

# --- Configuration / 配置 ---
readonly SCRIPT_NAME="$(basename "$0")"
readonly TARGET_LOCALE="zh_CN.UTF-8"
readonly BACKUP_DIR="/tmp/locale_backup_$(date +%s)"
readonly PROJECT_URL="https://github.com/Silentely/Demo"

# 引入通用函数库
if [ -f "../lib/common.sh" ]; then
    source ../lib/common.sh
elif [ -f "./lib/common.sh" ]; then
    source ./lib/common.sh
elif [ -f "/usr/local/lib/common.sh" ]; then
    source /usr/local/lib/common.sh
else
    # 如果找不到通用函数库，则使用内置定义
    color_red='\033[0;31m'
    color_green='\033[0;32m'
    color_yellow='\033[0;33m'
    color_blue='\033[0;34m'
    color_plain='\033[0m'

    _log() {
        local type="$1"
        local msg_en="$2"
        local msg_cn="$3"
        case "$type" in
            "info") 
                echo -e "${color_blue}INFO / 信息:${color_plain} ${msg_en}"
                [[ -n "$msg_cn" ]] && echo -e "${color_blue}            ${color_plain} ${msg_cn}"
                ;;
            "success") 
                echo -e "${color_green}SUCCESS / 成功:${color_plain} ${msg_en}"
                [[ -n "$msg_cn" ]] && echo -e "${color_green}               ${color_plain} ${msg_cn}"
                ;;
            "warn") 
                echo -e "${color_yellow}WARNING / 警告:${color_plain} ${msg_en}"
                [[ -n "$msg_cn" ]] && echo -e "${color_yellow}               ${color_plain} ${msg_cn}"
                ;;
            "error") 
                echo -e "${color_red}ERROR / 错误:${color_plain} ${msg_en}"
                [[ -n "$msg_cn" ]] && echo -e "${color_red}             ${color_plain} ${msg_cn}"
                ;;
        esac
    }
    
    log_info() {
        _log "info" "$1" "$2"
    }
    
    log_success() {
        _log "success" "$1" "$2"
    }
    
    log_warn() {
        _log "warn" "$1" "$2"
    }
    
    log_error() {
        _log "error" "$1" "$2"
    }
    
    show_help() {
        echo "用法: $0 [选项]"
        echo "选项:"
        echo "  -h, --help     显示帮助信息"
        echo "  -f, --force    强制执行，不进行确认提示"
        echo ""
        echo "功能: 一键设置系统全局语言环境为简体中文"
        echo "支持各种主流Linux发行版（CentOS、Debian、Ubuntu等）"
    }
fi

# --- Helper Functions for Colored Output / 彩色输出辅助函数 ---
_log() {
    local type="$1"
    local msg_en="$2"
    local msg_cn="$3"
    local color_red='\033[0;31m'
    local color_green='\033[0;32m'
    local color_yellow='\033[0;33m'
    local color_blue='\033[0;34m'
    local color_plain='\033[0m'

    case "$type" in
        "info") 
            echo -e "${color_blue}INFO / 信息:${color_plain} ${msg_en}"
            [[ -n "$msg_cn" ]] && echo -e "${color_blue}            ${color_plain} ${msg_cn}"
            ;;
        "success") 
            echo -e "${color_green}SUCCESS / 成功:${color_plain} ${msg_en}"
            [[ -n "$msg_cn" ]] && echo -e "${color_green}               ${color_plain} ${msg_cn}"
            ;;
        "warn") 
            echo -e "${color_yellow}WARNING / 警告:${color_plain} ${msg_en}"
            [[ -n "$msg_cn" ]] && echo -e "${color_yellow}               ${color_plain} ${msg_cn}"
            ;;
        "error") 
            echo -e "${color_red}ERROR / 错误:${color_plain} ${msg_en}" >&2
            [[ -n "$msg_cn" ]] && echo -e "${color_red}             ${color_plain} ${msg_cn}" >&2
            ;;
        "debug")
            echo -e "${color_yellow}DEBUG / 调试:${color_plain} ${msg_en}"
            [[ -n "$msg_cn" ]] && echo -e "${color_yellow}             ${color_plain} ${msg_cn}"
            ;;
        *) echo -e "${msg_en}" ;;
    esac
}

# Check if script is running from a pipe or file descriptor / 检查脚本是否通过管道或文件描述符运行
is_script_piped() {
    case "$0" in
        /dev/fd/*|/proc/self/fd/*|/dev/stdin|-)
            return 0  # Script is piped / 脚本是通过管道运行的
            ;;
        *)
            return 1  # Script is a regular file / 脚本是常规文件
            ;;
    esac
}

# Generate locale configuration content / 生成语言环境配置内容
generate_locale_config() {
    cat << 'EOF'
LANG=zh_CN.UTF-8
LANGUAGE="zh_CN.UTF-8"
LC_CTYPE="zh_CN.UTF-8"
LC_NUMERIC="zh_CN.UTF-8"
LC_TIME="zh_CN.UTF-8"
LC_COLLATE="zh_CN.UTF-8"
LC_MONETARY="zh_CN.UTF-8"
LC_MESSAGES="zh_CN.UTF-8"
LC_PAPER="zh_CN.UTF-8"
LC_NAME="zh_CN.UTF-8"
LC_ADDRESS="zh_CN.UTF-8"
LC_TELEPHONE="zh_CN.UTF-8"
LC_MEASUREMENT="zh_CN.UTF-8"
LC_IDENTIFICATION="zh_CN.UTF-8"
LC_ALL="zh_CN.UTF-8"
EOF
}

# Generate locale.gen content / 生成locale.gen内容
generate_locale_gen() {
    cat << 'EOF'
# This file lists locales that you wish to have built. You can find a list
# of valid supported locales at /usr/share/i18n/SUPPORTED, and you can add
# user defined locales to /usr/local/share/i18n/SUPPORTED. If you change
# this file, you need to rerun locale-gen.

en_US.UTF-8 UTF-8
zh_CN.UTF-8 UTF-8
EOF
}

# --- Exit Handler / 退出处理器 ---
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        _log "error" "Script failed with exit code $exit_code" "脚本执行失败，退出代码: $exit_code"
        if [[ -d "$BACKUP_DIR" ]]; then
            _log "info" "Locale backup is available at: $BACKUP_DIR" "语言环境备份保存在: $BACKUP_DIR"
        fi
    fi
}

trap cleanup EXIT

# --- Main Functions / 主要功能函数 ---

# Show project information / 显示项目信息
show_header() {
    clear
    echo "=================================================================="
    echo "   Linux System Chinese Locale Configuration Script"
    echo "   Linux系统中文语言环境配置脚本"
    echo ""
    echo "   Project / 项目地址: $PROJECT_URL"
    echo "=================================================================="
    echo ""
}

# Check system requirements / 检查系统要求
check_requirements() {
    # Check for root privileges / 检查root权限
    if [[ "$EUID" -ne 0 ]]; then
        _log "error" "This script must be run as root. Please use 'sudo'." "此脚本必须以root权限运行，请使用'sudo'"
        exit 1
    fi

    # Check for systemd and localectl / 检查systemd和localectl
    if ! command -v localectl &> /dev/null; then
        _log "error" "'localectl' command not found. This script requires systemd-based systems." "未找到'localectl'命令。此脚本需要基于systemd的系统"
        exit 1
    fi

    # Check if target locale is already set / 检查目标语言环境是否已设置
    local current_locale
    current_locale=$(localectl status | grep "System Locale" | cut -d'=' -f2 | tr -d ' ')
    if [[ "$current_locale" == "$TARGET_LOCALE" ]]; then
        _log "info" "System locale is already set to $TARGET_LOCALE" "系统语言环境已经设置为 $TARGET_LOCALE"
        exit 0
    fi
}

# Detect operating system / 检测操作系统
detect_os() {
    if [[ ! -f /etc/os-release ]]; then
        _log "error" "Cannot detect OS: /etc/os-release not found" "无法检测操作系统: 未找到 /etc/os-release 文件"
        exit 1
    fi

    # shellcheck source=/dev/null
    source /etc/os-release
    
    _log "info" "Detected OS: ${PRETTY_NAME:-${ID:-Unknown}}" "检测到操作系统: ${PRETTY_NAME:-${ID:-未知}}"
    
    # Validate supported OS / 验证支持的操作系统
    case "$ID" in
        ubuntu|debian|centos|rhel|rocky|almalinux|fedora|opensuse*)
            return 0
            ;;
        *)
            _log "warn" "OS '$ID' is not officially supported, but will attempt installation" "操作系统 '$ID' 未正式支持，但将尝试安装"
            return 0
            ;;
    esac
}

# Create backup of current locale settings / 创建当前语言环境设置的备份
create_backup() {
    _log "info" "Creating backup of current locale settings..." "正在创建当前语言环境设置的备份..."
    
    mkdir -p "$BACKUP_DIR" || {
        _log "error" "Failed to create backup directory" "创建备份目录失败"
        exit 1
    }
    
    # Backup current locale settings / 备份当前语言环境设置
    localectl status > "$BACKUP_DIR/localectl_status.bak" 2>/dev/null
    [[ -f /etc/locale.conf ]] && cp /etc/locale.conf "$BACKUP_DIR/"
    [[ -f /etc/default/locale ]] && cp /etc/default/locale "$BACKUP_DIR/"
    [[ -f /etc/locale.gen ]] && cp /etc/locale.gen "$BACKUP_DIR/"
    [[ -f /etc/environment ]] && cp /etc/environment "$BACKUP_DIR/"
    
    _log "success" "Backup created at: $BACKUP_DIR" "备份已创建于: $BACKUP_DIR"
}

# Install language packages / 安装语言包
install_language_packs() {
    _log "info" "Installing Chinese language packs..." "正在安装中文语言包..."
    
    local install_success=false
    local error_msg=""
    
    case "$ID" in
        ubuntu)
            _log "debug" "Installing Ubuntu language packs..." "正在安装Ubuntu语言包..."
            if apt-get update -y > /dev/null 2>&1; then
                if apt-get install -y language-pack-zh-hans language-pack-zh-hans-base > /dev/null 2>&1; then
                    install_success=true
                else
                    error_msg="Failed to install language-pack-zh-hans / 安装language-pack-zh-hans失败"
                fi
            else
                error_msg="Failed to update package list / 更新软件包列表失败"
            fi
            ;;
        debian)
            _log "debug" "Installing Debian language packs..." "正在安装Debian语言包..."
            if apt-get update -y > /dev/null 2>&1; then
                # For Debian, we need locales and ensure zh_CN.UTF-8 is available
                if apt-get install -y locales locales-all > /dev/null 2>&1; then
                    install_success=true
                else
                    # Fallback: try just locales
                    if apt-get install -y locales > /dev/null 2>&1; then
                        install_success=true
                    else
                        error_msg="Failed to install locales package / 安装locales包失败"
                    fi
                fi
            else
                error_msg="Failed to update package list / 更新软件包列表失败"
            fi
            ;;
        centos|rhel|rocky|almalinux|fedora)
            _log "debug" "Installing RHEL-based language packs..." "正在安装RHEL系语言包..."
            if command -v dnf &> /dev/null; then
                if dnf install -y glibc-langpack-zh langpacks-zh_CN > /dev/null 2>&1; then
                    install_success=true
                else
                    # Fallback: try just glibc-langpack-zh
                    if dnf install -y glibc-langpack-zh > /dev/null 2>&1; then
                        install_success=true
                    else
                        error_msg="Failed to install glibc-langpack-zh / 安装glibc-langpack-zh失败"
                    fi
                fi
            else
                if yum install -y glibc-langpack-zh > /dev/null 2>&1; then
                    install_success=true
                else
                    error_msg="Failed to install glibc-langpack-zh / 安装glibc-langpack-zh失败"
                fi
            fi
            ;;
        opensuse*)
            _log "debug" "Installing openSUSE language packs..." "正在安装openSUSE语言包..."
            if zypper install -y glibc-locale-zh > /dev/null 2>&1; then
                install_success=true
            else
                error_msg="Failed to install glibc-locale-zh / 安装glibc-locale-zh失败"
            fi
            ;;
        *)
            _log "warn" "Unsupported OS for automatic language pack installation" "不支持自动安装语言包的操作系统"
            install_success=true  # Continue anyway / 继续执行
            ;;
    esac
    
    if [[ "$install_success" == "true" ]]; then
        _log "success" "Language packs installed successfully" "语言包安装成功"
    else
        _log "error" "Failed to install language packs" "语言包安装失败"
        [[ -n "$error_msg" ]] && _log "debug" "$error_msg"
        
        # Provide manual instructions / 提供手动安装说明
        case "$ID" in
            debian)
                _log "info" "Manual installation for Debian:" "Debian手动安装方法:"
                _log "info" "Run: apt-get update && apt-get install locales" "运行: apt-get update && apt-get install locales"
                ;;
            ubuntu)
                _log "info" "Manual installation for Ubuntu:" "Ubuntu手动安装方法:"
                _log "info" "Run: apt-get update && apt-get install language-pack-zh-hans" "运行: apt-get update && apt-get install language-pack-zh-hans"
                ;;
        esac
        
        # Ask user if they want to continue / 询问用户是否继续
        echo ""
        echo -n "Continue without language packs? / 不安装语言包继续？ (y/N): "
        read -r -n 1 REPLY
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
        _log "warn" "Continuing without language pack installation" "在未安装语言包的情况下继续"
    fi
}

# Generate locale if needed / 如需要则生成语言环境
generate_locale() {
    _log "info" "Configuring $TARGET_LOCALE locale..." "正在配置 $TARGET_LOCALE 语言环境..."
    
    # Check if locale is available / 检查语言环境是否可用
    if locale -a 2>/dev/null | grep -q "^${TARGET_LOCALE}$"; then
        _log "info" "Locale $TARGET_LOCALE is already available" "语言环境 $TARGET_LOCALE 已经可用"
        return 0
    fi
    
    # For Debian/Ubuntu systems, configure locale.gen / 对于Debian/Ubuntu系统，配置locale.gen
    if [[ "$ID" == "debian" || "$ID" == "ubuntu" ]]; then
        _log "debug" "Configuring locale.gen for Debian/Ubuntu..." "正在为Debian/Ubuntu配置locale.gen..."
        
        # Generate new locale.gen file / 生成新的locale.gen文件
        generate_locale_gen > /etc/locale.gen
        _log "debug" "Created new /etc/locale.gen file" "已创建新的/etc/locale.gen文件"
        
        # Generate locales / 生成语言环境
        if command -v locale-gen &> /dev/null; then
            _log "debug" "Running locale-gen..." "正在运行locale-gen..."
            locale-gen > /dev/null 2>&1
        fi
    fi
    
    # For CentOS/RHEL, generate locale using localedef / 对于CentOS/RHEL，使用localedef生成语言环境
    if [[ "$ID" == "centos" || "$ID" == "rhel" || "$ID" == "rocky" || "$ID" == "almalinux" ]]; then
        _log "debug" "Generating locale using localedef..." "正在使用localedef生成语言环境..."
        localedef -v -c -i zh_CN -f UTF-8 zh_CN.UTF-8 > /dev/null 2>&1
    fi
    
    # Verify locale is now available / 验证语言环境现在是否可用
    if ! locale -a 2>/dev/null | grep -q "^${TARGET_LOCALE}$"; then
        _log "warn" "Could not verify that $TARGET_LOCALE is available" "无法验证 $TARGET_LOCALE 是否可用"
        _log "warn" "The system may generate it automatically when needed" "系统可能会在需要时自动生成"
    else
        _log "success" "Locale $TARGET_LOCALE is now available" "语言环境 $TARGET_LOCALE 现在已可用"
    fi
}

# Set system locale / 设置系统语言环境
set_locale() {
    _log "info" "Setting system locale to $TARGET_LOCALE..." "正在设置系统语言环境为 $TARGET_LOCALE..."
    
    # Use localectl for systemd-based systems / 对于基于systemd的系统使用localectl
    if localectl set-locale LANG="$TARGET_LOCALE"; then
        _log "success" "System locale set using localectl" "使用localectl设置系统语言环境成功"
    else
        _log "error" "Failed to set system locale using localectl" "使用localectl设置系统语言环境失败"
        exit 1
    fi
    
    # Create additional configuration files for compatibility / 为兼容性创建额外的配置文件
    case "$ID" in
        centos|rhel|rocky|almalinux|fedora)
            # Create /etc/locale.conf for RHEL-based systems / 为RHEL系统创建/etc/locale.conf
            _log "debug" "Creating /etc/locale.conf..." "正在创建/etc/locale.conf..."
            generate_locale_config > /etc/locale.conf
            
            # Also update /etc/environment for legacy compatibility / 为遗留兼容性更新/etc/environment
            if [[ -f /etc/environment ]]; then
                # Remove existing locale settings / 移除现有的语言环境设置
                sed -i '/^LANG=/d; /^LANGUAGE=/d; /^LC_/d' /etc/environment
            fi
            generate_locale_config >> /etc/environment
            _log "debug" "Updated /etc/environment" "已更新/etc/environment"
            ;;
        debian|ubuntu)
            # Create /etc/default/locale for Debian/Ubuntu / 为Debian/Ubuntu创建/etc/default/locale
            _log "debug" "Creating /etc/default/locale..." "正在创建/etc/default/locale..."
            generate_locale_config > /etc/default/locale
            ;;
    esac
    
    # Verify the change / 验证更改
    local new_locale
    new_locale=$(localectl status | grep "System Locale" | cut -d'=' -f2 | tr -d ' ')
    if [[ "$new_locale" == "$TARGET_LOCALE" ]]; then
        _log "success" "Locale change verified" "语言环境更改已验证"
    else
        _log "warn" "Locale change could not be verified immediately" "语言环境更改无法立即验证"
    fi
}

# Display completion message and cleanup options / 显示完成信息和清理选项
show_completion() {
    clear
    echo "=================================================================="
    echo "🎉 INSTALLATION COMPLETED SUCCESSFULLY! / 安装成功完成！ 🎉"
    echo "=================================================================="
    echo ""
    _log "success" "System locale has been successfully set to Chinese (Simplified)" "系统语言环境已成功设置为简体中文"
    echo ""
    echo "📋 IMPORTANT NOTES / 重要说明:"
    echo "   • You must REBOOT or start a new session for changes to take full effect"
    echo "     您必须重启或开始新会话以使更改完全生效"
    echo ""
    echo "   • Verify the change with: localectl status"
    echo "     使用以下命令验证更改: localectl status"
    echo ""
    echo "   • Current locale setting / 当前语言环境设置:"
    echo "     $(localectl status | grep 'System Locale' | cut -d':' -f2)"
    echo ""
    if [[ -d "$BACKUP_DIR" ]]; then
        echo "   • Backup of old settings / 旧设置备份: $BACKUP_DIR"
        echo ""
    fi
    echo "📄 Configuration files updated / 已更新的配置文件:"
    case "$ID" in
        centos|rhel|rocky|almalinux|fedora)
            echo "   • /etc/locale.conf"
            echo "   • /etc/environment"
            ;;
        debian|ubuntu)
            echo "   • /etc/default/locale"
            echo "   • /etc/locale.gen"
            ;;
    esac
    echo ""
    echo "=================================================================="
    echo "📁 Project Repository / 项目仓库: $PROJECT_URL"
    echo ""
    echo "🙏 Thank you for using this script! / 感谢您使用此脚本！"
    echo "   If you found this helpful, please consider giving it a star ⭐"
    echo "   如果此脚本对您有帮助，请考虑为项目点个星 ⭐"
    echo "=================================================================="
    echo ""
    
    # Handle script deletion based on how it was executed / 根据脚本执行方式处理删除
    if is_script_piped; then
        _log "info" "Script was executed via pipe/stdin, no file to delete" "脚本通过管道/标准输入执行，无文件可删除"
        _log "info" "If you downloaded this script, you can manually delete it" "如果您下载了此脚本，可以手动删除"
    else
        # Ask for script deletion only if it's a regular file / 仅当是常规文件时询问删除
        echo -n "Do you want to delete this script? / 是否删除此脚本？ (y/N): "
        read -r -n 1 REPLY
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if [[ -f "$0" && -w "$0" ]]; then
                _log "info" "Deleting script: $0" "正在删除脚本: $0"
                rm -- "$0" && _log "success" "Script deleted successfully" "脚本删除成功"
            else
                _log "warn" "Cannot delete script (not writable or not a file)" "无法删除脚本（不可写或非文件）"
            fi
        else
            _log "info" "Script preserved at: $0" "脚本保留在: $0"
        fi
    fi
    
    echo ""
    echo "👋 Goodbye! Have a great day! / 再见！祝您愉快！"
}

# --- Main Execution / 主执行函数 ---
main() {
    show_header
    
    _log "info" "Starting Chinese locale configuration..." "开始中文语言环境配置..."
    echo ""
    
    check_requirements
    detect_os
    create_backup
    install_language_packs
    generate_locale
    set_locale
    
    echo ""
    show_completion
}

# Execute main function / 执行主函数
main "$@"
