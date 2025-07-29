#!/bin/bash
# 脚本名称: cleanup.sh
# 功能: 系统垃圾清理加速器
# 作者: Silentely
# 最后更新: 2025-06-08
# 许可证: MIT

# 引入通用函数库
if [ -f "./lib/common.sh" ]; then
    source ./lib/common.sh
elif [ -f "/usr/local/lib/common.sh" ]; then
    source /usr/local/lib/common.sh
else
    # 如果找不到通用函数库，则使用内置定义
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    BLUE='\033[1;34m'
    NC='\033[0m' # 恢复默认
    
    log_info() {
        echo -e "${CYAN}[INFO]${NC} $1"
    }
    
    log_warn() {
        echo -e "${YELLOW}[WARN]${NC} $1"
    }
    
    log_error() {
        echo -e "${RED}[ERROR]${NC} $1" >&2
    }
    
    log_success() {
        echo -e "${GREEN}[SUCCESS]${NC} $1"
    }
fi

# 设置脚本在遇到错误时退出
set -e

# 帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  -h, --help     显示帮助信息"
    echo "  -v, --verbose  详细输出模式"
    echo "  -y, --yes      自动确认所有操作"
    echo ""
    echo "功能: 清理系统缓存、日志、临时文件等，释放磁盘空间"
}

# 解析命令行参数
VERBOSE=false
AUTO_YES=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -y|--yes)
            AUTO_YES=true
            shift
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
done

divider() {
  echo -e "${BLUE}============================================================${NC}"
}

banner() {
  echo -e "${CYAN}"
  echo "   _____ _           _             "
  echo "  / ____| |         | |            "
  echo " | |    | | ___  ___| |_ ___  _ __ "
  echo " | |    | |/ _ \/ __| __/ _ \| '__|"
  echo " | |____| |  __/ (__| || (_) | |   "
  echo "  \_____|_|\___|\___|\__\___/|_|   "
  echo -e "${NC}"
}

pause() {
  if [ "$AUTO_YES" = false ]; then
      read -rp "$(echo -e "${YELLOW}按回车键继续...${NC}")"
  fi
}

# 进度条动画
progress_bar() {
  local duration=${1:-10}
  local fill="▓"
  local empty="░"
  local width=36
  for ((i=0; i<=duration; i++)); do
    percent=$(( i * 100 / duration ))
    filled=$(( i * width / duration ))
    empty_count=$(( width - filled ))
    bar=$(printf "%0.s$fill" $(seq 1 $filled))
    bar+=$(printf "%0.s$empty" $(seq 1 $empty_count))
    echo -ne "\r${CYAN}[$bar] $percent%${NC}"
    sleep 0.10
  done
  echo
}

# 旋转指针动画
spinner() {
  local pid=$!
  local delay=0.08
  local spinstr="|/-\\"
  while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
  printf "    \b\b\b\b"
}

# 获取磁盘空间使用情况
get_disk_usage() {
    df -h / | awk 'NR==2 {print $5}' | sed 's/%//'
}

# 清理前磁盘使用情况
initial_usage=$(get_disk_usage)
log_info "清理前磁盘使用率: ${initial_usage}%"

# 主清理函数
main() {
    banner
    divider
    log_info "开始清理系统垃圾文件..."
    pause
    
    # 清理APT缓存
    divider
    log_info "清理 APT 缓存..."
    if command -v apt-get &> /dev/null; then
        if [ "$AUTO_YES" = true ]; then
            sudo apt-get clean -y
        else
            sudo apt-get clean
        fi
        log_success "APT 缓存清理完成"
    else
        log_warn "系统中未找到 apt-get 命令"
    fi
    
    # 清理日志文件
    divider
    log_info "清理日志文件..."
    if [ -d "/var/log" ]; then
        sudo find /var/log -type f -name "*.log" -exec truncate -s 0 {} \; 2>/dev/null || true
        sudo find /var/log -type f -name "*.gz" -delete 2>/dev/null || true
        log_success "日志文件清理完成"
    else
        log_warn "未找到 /var/log 目录"
    fi
    
    # 清理临时文件
    divider
    log_info "清理临时文件..."
    sudo rm -rf /tmp/* 2>/dev/null || true
    sudo rm -rf /var/tmp/* 2>/dev/null || true
    log_success "临时文件清理完成"
    
    # 清理用户缓存
    divider
    log_info "清理用户缓存文件..."
    rm -rf ~/.cache/* 2>/dev/null || true
    log_success "用户缓存清理完成"
    
    # 清理缩略图缓存
    divider
    log_info "清理缩略图缓存..."
    rm -rf ~/.thumbnails/* 2>/dev/null || true
    log_success "缩略图缓存清理完成"
    
    # 清理浏览器缓存 (如果存在)
    divider
    log_info "清理浏览器缓存..."
    rm -rf ~/.mozilla/firefox/*.default/cache* 2>/dev/null || true
    rm -rf ~/.config/google-chrome/Default/Cache* 2>/dev/null || true
    rm -rf ~/.config/chromium/Default/Cache* 2>/dev/null || true
    log_success "浏览器缓存清理完成"
    
    # 清理包残留配置
    divider
    log_info "清理包残留配置..."
    if command -v dpkg &> /dev/null; then
        sudo dpkg --purge $(dpkg -l | grep "^rc" | awk '{print $2}') 2>/dev/null || true
        log_success "包残留配置清理完成"
    else
        log_warn "系统中未找到 dpkg 命令"
    fi
    
    divider
    # 清理后磁盘使用情况
    final_usage=$(get_disk_usage)
    freed_space=$((initial_usage - final_usage))
    log_success "系统垃圾清理完成，磁盘使用率从 ${initial_usage}% 降低到 ${final_usage}%"
    echo -e "${GREEN}共释放约 ${freed_space}% 的磁盘空间${NC}"
    divider
    
    echo -e "${CYAN}清理任务完成！${NC}"
}

# 检查是否以root权限运行
if [ "$EUID" -eq 0 ]; then
    log_warn "不建议以 root 用户身份运行此脚本"
    if [ "$AUTO_YES" = false ]; then
        read -rp "$(echo -e "${YELLOW}是否继续? [y/N]: ${NC}")" confirm
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            log_info "操作已取消"
            exit 0
        fi
    fi
fi

# 执行主函数
main
