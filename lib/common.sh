#!/bin/bash
# 通用函数库
# 功能: 为所有脚本提供统一的颜色定义和常用函数

# 颜色定义 (统一所有脚本的颜色方案)
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
COLOR_CYAN='\033[0;36m'
COLOR_BOLD='\033[1m'
COLOR_NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${COLOR_CYAN}[INFO]${COLOR_NC} $1"
}

log_warn() {
    echo -e "${COLOR_YELLOW}[WARN]${COLOR_NC} $1"
}

log_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_NC} $1" >&2
}

log_success() {
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_NC} $1"
}

# 错误处理函数
error_exit() {
    log_error "$1"
    exit 1
}

# 检查依赖函数
check_dependency() {
    local dep=$1
    if ! command -v "$dep" &> /dev/null; then
        log_warn "依赖 $dep 未安装"
        return 1
    fi
    return 0
}

# 显示帮助信息的函数
show_help() {
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  -h, --help     显示帮助信息"
    echo "  -v, --version  显示版本信息"
}

# 进度条函数
show_progress() {
    local duration=${1:-10}
    local fill="█"
    local empty="░"
    local width=40
    
    echo -ne "\r${COLOR_BLUE}进度: ${COLOR_NC}["
    for ((i=0; i<width; i++)); do
        echo -n "$empty"
    done
    echo -n "] 0%"
    
    for ((i=1; i<=duration; i++)); do
        local percent=$(( i * 100 / duration ))
        local filled=$(( i * width / duration ))
        local empty_count=$(( width - filled ))
        
        echo -ne "\r${COLOR_BLUE}进度: ${COLOR_NC}["
        for ((j=0; j<filled; j++)); do
            echo -n "$fill"
        done
        for ((j=0; j<empty_count; j++)); do
            echo -n "$empty"
        done
        echo -n "] $percent%"
        
        sleep 0.1
    done
    echo -e "\n${COLOR_GREEN}完成!${COLOR_NC}"
}

# 确认函数
confirm() {
    local prompt="${1:-确认继续操作吗?}"
    local response
    
    while true; do
        read -rp "$(echo -e "${COLOR_YELLOW}$prompt ${COLOR_NC}[y/N]: ")" response
        case "$response" in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "请输入 y 或 n";;
        esac
    done
}