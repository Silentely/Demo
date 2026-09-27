#!/bin/bash
# ==============================================================================
# 脚本名称: cleanup.sh
# 功能:     系统垃圾清理加速器 (全发行版适配 & journald/包管理器深度清理)
# 作者:     Silentely
# 许可证:   MIT
# ==============================================================================

# 引入通用函数库
if [ -f "./lib/common.sh" ]; then
    source ./lib/common.sh
elif [ -f "../lib/common.sh" ]; then
    source ../lib/common.sh
elif [ -f "/usr/local/lib/common.sh" ]; then
    source /usr/local/lib/common.sh
else
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    BLUE='\033[1;34m'
    NC='\033[0m'

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

set -e

# 管道执行兼容 TTY
if [[ ! -t 0 ]] && { true < /dev/tty; } 2>/dev/null; then
    exec < /dev/tty 2>/dev/null || true
fi

# 帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  -h, --help     显示帮助信息"
    echo "  -v, --verbose  详细输出模式"
    echo "  -y, --yes      自动确认所有操作"
    echo ""
    echo "功能: 清理系统缓存、journal 日志、临时文件、孤立包等，释放磁盘空间"
}

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

get_disk_usage() {
    df -h / | awk 'NR==2 {print $5}' | sed 's/%//'
}

get_disk_free() {
    df -h / | awk 'NR==2 {print $4}'
}

# 主清理函数
main() {
    banner
    divider

    local initial_usage
    local initial_free
    initial_usage=$(get_disk_usage)
    initial_free=$(get_disk_free)

    log_info "清理前磁盘使用率: ${initial_usage}% (可用空间: ${initial_free})"
    log_info "开始清理系统垃圾文件..."
    pause

    # 1. 清理 systemd journal 日志 (现代 Linux 磁盘占用大户)
    if command -v journalctl &> /dev/null; then
        divider
        log_info "清理 systemd journal 日志 (保留最近 2 天或 50M)..."
        sudo journalctl --vacuum-time=2d --vacuum-size=50M 2>/dev/null || true
        log_success "systemd journal 日志清理完成"
    fi

    # 2. 清理包管理器缓存及孤立包
    divider
    log_info "清理软件包管理器缓存及孤立无用包..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get clean -y >/dev/null 2>&1 || true
        sudo apt-get autoclean -y >/dev/null 2>&1 || true
        sudo apt-get autoremove --purge -y >/dev/null 2>&1 || true
        if command -v dpkg &> /dev/null; then
            local rc_pkgs
            rc_pkgs=$(dpkg -l 2>/dev/null | grep "^rc" | awk '{print $2}' || true)
            if [ -n "$rc_pkgs" ]; then
                sudo dpkg --purge $rc_pkgs 2>/dev/null || true
            fi
        fi
        log_success "APT 缓存与残留配置清理完成"
    elif command -v dnf &> /dev/null; then
        sudo dnf clean all >/dev/null 2>&1 || true
        sudo dnf autoremove -y >/dev/null 2>&1 || true
        log_success "DNF 缓存及孤立包清理完成"
    elif command -v yum &> /dev/null; then
        sudo yum clean all >/dev/null 2>&1 || true
        sudo yum autoremove -y >/dev/null 2>&1 || true
        log_success "YUM 缓存清理完成"
    elif command -v pacman &> /dev/null; then
        sudo pacman -Sc --noconfirm >/dev/null 2>&1 || true
        log_success "Pacman 缓存清理完成"
    elif command -v apk &> /dev/null; then
        sudo apk cache clean >/dev/null 2>&1 || true
        log_success "APK 缓存清理完成"
    else
        log_warn "未识别到主流包管理器，跳过包缓存清理"
    fi

    # 3. 清理 /var/log 日志文件
    divider
    log_info "清理旧日志归档文件..."
    if [ -d "/var/log" ]; then
        sudo find /var/log -type f -name "*.gz" -delete 2>/dev/null || true
        sudo find /var/log -type f -name "*.1" -delete 2>/dev/null || true
        sudo find /var/log -type f -name "*.old" -delete 2>/dev/null || true
        sudo find /var/log -type f -name "*.log" -size +10M -exec truncate -s 1M {} \; 2>/dev/null || true
        log_success "日志归档清理完成"
    fi

    # 4. 清理临时文件
    divider
    log_info "清理临时目录..."
    sudo find /tmp -type f -atime +3 -delete 2>/dev/null || true
    sudo find /var/tmp -type f -atime +3 -delete 2>/dev/null || true
    log_success "临时文件清理完成"

    # 5. 清理用户缓存
    divider
    log_info "清理用户缓存及缩略图..."
    rm -rf ~/.cache/* 2>/dev/null || true
    rm -rf ~/.thumbnails/* 2>/dev/null || true
    log_success "用户缓存清理完成"

    # 6. 清理浏览器缓存 (如果存在)
    if [ -d ~/.mozilla ] || [ -d ~/.config/google-chrome ] || [ -d ~/.config/chromium ]; then
        divider
        log_info "清理浏览器缓存..."
        rm -rf ~/.mozilla/firefox/*.default/cache* 2>/dev/null || true
        rm -rf ~/.config/google-chrome/Default/Cache* 2>/dev/null || true
        rm -rf ~/.config/chromium/Default/Cache* 2>/dev/null || true
        log_success "浏览器缓存清理完成"
    fi

    # 7. 统计清理结果
    divider
    local final_usage
    local final_free
    final_usage=$(get_disk_usage)
    final_free=$(get_disk_free)

    local freed_pct=0
    if [ "$initial_usage" -gt "$final_usage" ]; then
        freed_pct=$((initial_usage - final_usage))
    fi

    log_success "系统垃圾清理完成！"
    log_info "磁盘使用率: ${initial_usage}% -> ${final_usage}% (释放约 ${freed_pct}%)"
    log_info "当前可用空间: ${final_free} (清理前: ${initial_free})"
    divider
    echo -e "${CYAN}清理任务全部完成！${NC}"
}

main
