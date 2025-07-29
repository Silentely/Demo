#!/bin/bash

# ==============================================================================
# 脚本名称: terminal_optimizer.sh
# 功能:     优化与美化 Linux 终端体验，支持主流发行版。
# 作者:     rouxyang (原始作者) / Gemini (优化) / Silentely (改进)
# 创建日期: 2025-04-13
# 最后更新: 2025-06-08
# 许可证:   MIT
# 项目地址: https://github.com/Silentely/Demo
# ==============================================================================

# --- 全局变量 ---
SCRIPT_VERSION="0.0.2"
readonly LOG_FILE="/tmp/terminal_optimizer.log"
UNINSTALL=false
FORCE=false

# 引入通用函数库
if [ -f "../lib/common.sh" ]; then
    source ../lib/common.sh
elif [ -f "./lib/common.sh" ]; then
    source ./lib/common.sh
elif [ -f "/usr/local/lib/common.sh" ]; then
    source /usr/local/lib/common.sh
else
    # 如果找不到通用函数库，则使用内置定义
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[0;33m'
    readonly BLUE='\033[0;34m'
    readonly CYAN='\033[0;36m'
    readonly NC='\033[0m' # No Color

    # 日志记录函数
    log() {
        local type_color
        case "$1" in
            INFO) type_color="$BLUE" ;;
            SUCCESS) type_color="$GREEN" ;;
            WARN) type_color="$YELLOW" ;;
            ERROR) type_color="$RED" ;;
            *) echo "Invalid log type" >&2; return 1 ;;
        esac
        # 将日志同时输出到控制台和文件
        echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${type_color}[$1]${NC} $2" | tee -a "$LOG_FILE"
    }
    
    log_info() {
        log "INFO" "$1"
    }
    
    log_success() {
        log "SUCCESS" "$1"
    }
    
    log_warn() {
        log "WARN" "$1"
    }
    
    log_error() {
        log "ERROR" "$1"
    }
fi

# 显示帮助信息函数
show_help() {
    echo "终端优化美化脚本 (Terminal Optimizer)"
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help       显示此帮助信息"
    echo "  -v, --version    显示脚本版本"
    echo "  -u, --uninstall  恢复到原始配置"
    echo "  -f, --force      强制执行，不进行确认提示"
    echo ""
    echo "功能:"
    echo "  - 优化与美化 Linux 终端体验"
    echo "  - 自动检测主流发行版和包管理器"
    echo "  - 快速配置炫酷 PS1、Git 集成与常用别名"
    echo "  - 历史命令增强，提升效率"
    echo "  - 一键还原、无残留"
    echo "  - 支持 root 和普通用户"
}

# 显示版本信息函数
show_version() {
    echo "终端优化美化脚本 (Terminal Optimizer) v$SCRIPT_VERSION"
}

# 优雅退出
cleanup() {
    log "WARN" "脚本被中断，正在退出..."
    exit 130
}
trap cleanup SIGINT SIGTERM

# 权限检查
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "请以 root 用户或使用 sudo 运行此脚本！"
        exit 1
    fi
}

# 检测命令是否存在
command_exists() {
    command -v "$1" &>/dev/null
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--version)
            show_version
            exit 0
            ;;
        -u|--uninstall)
            UNINSTALL=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

# ==============================================================================
# 核心功能
# ==============================================================================

# 全局变量，用于存储系统信息
OS_ID=""
PKG_MANAGER=""
TARGET_USER=""
TARGET_HOME=""
BASHRC_FILE=""
CUSTOM_CONFIG_FILE=""

# 检测操作系统和包管理器
detect_os() {
    log "INFO" "正在检测操作系统..."
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        OS_ID=${ID,,} # 转为小写
    elif command_exists lsb_release; then
        OS_ID=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
    else
        log "ERROR" "无法检测到操作系统发行版。"
        exit 1
    fi

    case "$OS_ID" in
        ubuntu|debian|linuxmint) PKG_MANAGER="apt" ;;
        centos|rhel|fedora|rocky|almalinux)
            if command_exists dnf; then PKG_MANAGER="dnf"; else PKG_MANAGER="yum"; fi ;;
        arch|manjaro) PKG_MANAGER="pacman" ;;
        opensuse*|sles) PKG_MANAGER="zypper" ;;
        alpine) PKG_MANAGER="apk" ;;
        *) log "ERROR" "不支持的操作系统: $OS_ID"; exit 1 ;;
    esac
    log "SUCCESS" "检测到系统: $OS_ID, 包管理器: $PKG_MANAGER"
}

# 确定目标用户和家目录
detect_target_user() {
    if [[ -n "$SUDO_USER" ]]; then
        TARGET_USER="$SUDO_USER"
        TARGET_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    else
        # 如果直接以 root 登录
        TARGET_USER="root"
        TARGET_HOME="/root"
    fi
    BASHRC_FILE="$TARGET_HOME/.bashrc"
    CUSTOM_CONFIG_FILE="$TARGET_HOME/.terminal_optimizer.sh"
    log "INFO" "配置将应用于用户 '$TARGET_USER' (家目录: $TARGET_HOME)"
}

# 安装软件包
install_packages() {
    local packages=("$@")
    if [[ ${#packages[@]} -eq 0 ]]; then
        log "WARN" "没有需要安装的软件包。"
        return
    fi
    
    local pkgs_to_install=()
    for pkg in "${packages[@]}"; do
        if ! command_exists "$pkg" && ! ( [[ "$pkg" == "bash-completion" ]] && [[ -f /etc/bash_completion ]] ); then
             pkgs_to_install+=("$pkg")
        fi
    done

    if [[ ${#pkgs_to_install[@]} -eq 0 ]]; then
        log "SUCCESS" "所有必需的软件包均已安装。"
        return
    fi

    log "INFO" "准备安装软件包: ${pkgs_to_install[*]}"
    case "$PKG_MANAGER" in
        apt)
            apt-get update -y
            apt-get install -y "${pkgs_to_install[@]}"
            ;;
        dnf|yum)
            # CentOS/RHEL 可能需要 epel-release
            if [[ "$OS_ID" == "centos" || "$OS_ID" == "rhel" ]]; then
                $PKG_MANAGER install -y epel-release
            fi
            $PKG_MANAGER install -y "${pkgs_to_install[@]}"
            ;;
        pacman)
            pacman -Syu --noconfirm --needed "${pkgs_to_install[@]}"
            ;;
        zypper)
            zypper --non-interactive in "${pkgs_to_install[@]}"
            ;;
        apk)
            apk update
            apk add "${pkgs_to_install[@]}"
            ;;
    esac

    # 验证安装结果
    for pkg in "${pkgs_to_install[@]}"; do
        if ! command_exists "$pkg" && ! ( [[ "$pkg" == "bash-completion" ]] && [[ -f /etc/bash_completion ]] ); then
            log "ERROR" "软件包 '$pkg' 安装失败。请检查日志 $LOG_FILE"
            return 1 # 返回失败状态码
        fi
    done
    log "SUCCESS" "所有软件包均已成功安装。"
}


# 核心：配置 Bash 环境
configure_bash() {
    log "INFO" "开始配置 Bash 环境..."

    # 1. 安装必要的工具
    install_packages git curl wget bash-completion || { log "ERROR" "安装基础包失败，终止配置。"; return 1; }

    # 2. 备份原始 .bashrc (仅在第一次配置时)
    if [[ ! -f "${BASHRC_FILE}.bak_optimizer" ]]; then
        log "INFO" "备份原始 .bashrc 到 ${BASHRC_FILE}.bak_optimizer"
        cp "$BASHRC_FILE" "${BASHRC_FILE}.bak_optimizer"
    fi

    # 3. 创建自定义配置文件
    log "INFO" "正在创建或更新自定义配置文件: $CUSTOM_CONFIG_FILE"
    # 使用 cat 和 EOF 创建文件，由 root 创建，但所有者是目标用户
    cat > "$CUSTOM_CONFIG_FILE" <<EOF
# --- 由 terminal_optimizer.sh 生成 ---

# 1. PS1 提示符美化 (单行版本)
#    - 寻找 git-prompt.sh 脚本
if [[ -f /usr/share/git-core/contrib/completion/git-prompt.sh ]]; then
    source /usr/share/git-core/contrib/completion/git-prompt.sh
elif [[ -f /usr/lib/git-core/git-prompt.sh ]]; then
    source /usr/lib/git-core/git-prompt.sh
fi

#    - 设置 PS1
if declare -f __git_ps1 &>/dev/null; then
    GIT_PS1_SHOWDIRTYSTATE=1      # '
    GIT_PS1_SHOWSTASHSTATE=1    # '$'
    GIT_PS1_SHOWUNTRACKEDFILES=1 # '%'
    # 单行提示符，移除了 '\n'
    PS1='\[\033[0;32m\]\u@\h\[\033[0m\]:\[\033[0;34m\]\w\[\033[0;33m\]\$(__git_ps1 " (%s)")\[\033[0m\]\$ '
else
    # 不带 Git 功能的 PS1
    PS1='\[\033[0;32m\]\u@\h\[\033[0m\]:\[\033[0;34m\]\w\[\033[0m\]\$ '
fi
# 如果想要两行显示，恢复下面这行:
# PS1='\[\033[0;32m\]\u@\h:\w\$(__git_ps1 " (%s)")\n\[\033[0m\]\$ '


# 2. 历史命令优化
export HISTCONTROL=ignoredups:erasedups # 忽略重复和清除旧的重复项
export HISTSIZE=10000                   # 历史记录条数
export HISTFILESIZE=20000               # 历史文件大小
export HISTTIMEFORMAT="%F %T "          # 记录时间戳
shopt -s histappend                     # 追加而不是覆盖历史文件
export PROMPT_COMMAND="history -a; \$PROMPT_COMMAND" # 立即写入历史

# 3. 常用别名
alias ll='ls -alF --color=auto'
alias la='ls -A --color=auto'
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias g='git'
alias c='clear'
alias h='history'
alias p='ps auxf'
alias ..='cd ..'
alias ...='cd ../..'

# 4. 其它设置
export EDITOR=vim # 将默认编辑器设置为 vim，可以改为 nano

# --- 配置结束 ---
EOF
    
    # 更改配置文件的所有者为目标用户
    chown "$TARGET_USER":"$(id -gn "$TARGET_USER")" "$CUSTOM_CONFIG_FILE"

    # 4. 在 .bashrc 中引用自定义配置
    if ! grep -q "source $CUSTOM_CONFIG_FILE" "$BASHRC_FILE"; then
        log "INFO" "在 $BASHRC_FILE 中添加对自定义配置的引用。"
        # 在文件末尾追加引用
        echo -e "\n# 加载终端优化配置\nif [ -f \"\$HOME/.terminal_optimizer.sh\" ]; then\n    . \"\$HOME/.terminal_optimizer.sh\"\nfi" >> "$BASHRC_FILE"
    else
        log "INFO" "自定义配置引用已存在于 $BASHRC_FILE。"
    fi
    
    log "SUCCESS" "Bash 配置完成！"
}

# 清理与还原
cleanup_and_restore() {
    log "INFO" "开始清理和还原配置..."
    
    # 1. 移除 .bashrc 中的引用
    if [[ -f "$BASHRC_FILE" ]]; then
        log "INFO" "从 $BASHRC_FILE 中移除配置引用..."
        # 使用 sed 原地删除相关代码块
        sed -i '/# 加载终端优化配置/,/fi/d' "$BASHRC_FILE"
    fi

    # 2. 删除自定义配置文件
    if [[ -f "$CUSTOM_CONFIG_FILE" ]]; then
        log "INFO" "删除自定义配置文件 $CUSTOM_CONFIG_FILE"
        rm -f "$CUSTOM_CONFIG_FILE"
    fi

    # 3. 还原备份 (可选)
    if [[ -f "${BASHRC_FILE}.bak_optimizer" ]]; then
        read -p "找到 .bashrc 的备份文件，是否要用它覆盖当前文件? (y/N): " -r reply
        if [[ "$reply" =~ ^[Yy]$ ]]; then
            log "INFO" "正在从备份还原 $BASHRC_FILE..."
            mv "${BASHRC_FILE}.bak_optimizer" "$BASHRC_FILE"
        else
            log "INFO" "跳过从备份还原。备份文件保留在 ${BASHRC_FILE}.bak_optimizer"
        fi
    fi

    log "SUCCESS" "清理完成！"
}

# ==============================================================================
# 主逻辑
# ==============================================================================
main() {
    # 脚本开始，记录日志
    echo "==================== $(date) ====================" >> "$LOG_FILE"
    log "INFO" "终端优化脚本 v$SCRIPT_VERSION 启动。"
    
    # 核心流程
    check_root
    detect_os
    detect_target_user

    # 主菜单
    echo -e "\n${CYAN}欢迎使用终端优化脚本!${NC}"
    echo -e "配置将应用于用户: ${YELLOW}${TARGET_USER}${NC}"
    echo -e "----------------------------------------"
    echo "1) 安装或更新终端美化配置"
    echo "2) 卸载配置并还原"
    echo "q) 退出"
    echo -e "----------------------------------------"
    read -rp "请输入选项 [1]: " choice
    
    case "${choice:-1}" in
        1)
            configure_bash
            ;;
        2)
            cleanup_and_restore
            ;;
        q|Q)
            log "INFO" "用户选择退出。"
            ;;
        *)
            log "WARN" "无效选项，执行默认操作：安装配置。"
            configure_bash
            ;;
    esac

    log "INFO" "操作完成。"
    echo -e "\n${GREEN}✅ 操作完成！请重新登录或运行 'source ${BASHRC_FILE}' 来使配置生效。${NC}"
    echo -e "日志文件位于: ${LOG_FILE}"
}

# --- 脚本执行入口 ---
main "$@"
