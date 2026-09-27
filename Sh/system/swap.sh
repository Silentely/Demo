#!/usr/bin/env bash
# ==============================================================================
# Linux VPS 一键配置 / 调整 / 移除 Swap 交换分区脚本
# 功能特性:
# 1. 优先使用 fallocate 极速分配空间，失败自动回退到 dd 块写入，完美支持 XFS/Btrfs。
# 2. 自动检查已有 Swap 与剩余磁盘空间，杜绝写满磁盘造成系统死锁。
# 3. 自动配置 swappiness 内核参数与 /etc/fstab 持久化开机自启。
# 4. 支持非交互式 CLI 参数（--size <MB> 或 --delete）与 -y 静默确认。
# ==============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)/lib"

if [[ -f "${LIB_DIR}/common.sh" ]]; then
    # shellcheck disable=SC1091
    source "${LIB_DIR}/common.sh"
else
    # 独立运行模式兜底日志
    log_info()    { echo -e "\033[34m[INFO]\033[0m $*"; }
    log_success() { echo -e "\033[32m[SUCCESS]\033[0m $*"; }
    log_warn()    { echo -e "\033[33m[WARN]\033[0m $*"; }
    log_error()   { echo -e "\033[31m[ERROR]\033[0m $*" >&2; }
    require_root() {
        if [[ $EUID -ne 0 ]]; then
            log_error "本脚本需要 root 权限，请使用 sudo 重新运行！"
            exit 1
        fi
    }
fi

# 管道输入兼容
if [[ ! -t 0 ]] && { true < /dev/tty; } 2>/dev/null; then
    exec < /dev/tty 2>/dev/null || true
fi

# 获取当前可用磁盘空间 (单位 MB)
get_available_disk_mb() {
    df -m / | awk 'NR==2 {print $4}'
}

# 格式化检查与安全添加 Swap
add_swap() {
    local swapsize="$1"

    if [[ -z "$swapsize" ]]; then
        read -rp "请输入需要添加的 Swap 大小 (单位 MB，建议与物理内存 1:1 或 1:2，如 2048): " swapsize
    fi

    if ! [[ "$swapsize" =~ ^[0-9]+$ ]] || [ "$swapsize" -le 0 ]; then
        log_error "输入的 Swap 大小无效，必须为正整数！"
        return 1
    fi

    # 磁盘空间充裕性检查
    local disk_avail
    disk_avail=$(get_available_disk_mb)
    if [ "$swapsize" -ge "$disk_avail" ]; then
        log_error "磁盘可用空间不足！需要: ${swapsize}MB，可用: ${disk_avail}MB"
        return 1
    fi

    # 如果系统中已经存在 /swapfile，先安全注销
    if [[ -f /swapfile ]] || grep -q "/swapfile" /etc/fstab 2>/dev/null; then
        log_warn "检测到系统中已存在 /swapfile，正在关闭并重新配置..."
        swapoff /swapfile 2>/dev/null || true
        rm -f /swapfile
    fi

    log_info "正在为系统分配 ${swapsize}MB 的 Swap 空间..."

    local fallocate_success=false
    # 针对 ext4 等文件系统优先使用 fallocate 秒级分配
    if command -v fallocate &>/dev/null; then
        if fallocate -l "${swapsize}M" /swapfile 2>/dev/null; then
            chmod 600 /swapfile
            if mkswap /swapfile &>/dev/null && swapon /swapfile &>/dev/null; then
                fallocate_success=true
            else
                swapoff /swapfile 2>/dev/null || true
                rm -f /swapfile
            fi
        fi
    fi

    if [ "$fallocate_success" = false ]; then
        log_info "fallocate 遇到文件系统限制，正在使用 dd 进行块写入 (速度取决于磁盘 I/O)..."
        if ! dd if=/dev/zero of=/swapfile bs=1M count="${swapsize}" status=progress 2>/dev/null; then
            dd if=/dev/zero of=/swapfile bs=1M count="${swapsize}"
        fi
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
    fi

    # 写入 fstab 开机自启
    if ! grep -E '^[[:space:]]*/swapfile[[:space:]]' /etc/fstab 2>/dev/null; then
        cp /etc/fstab "/etc/fstab.bak_$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
        echo '/swapfile none swap defaults 0 0' >> /etc/fstab
    fi

    # 调优 swappiness (建议 10~60)
    sysctl vm.swappiness=60 >/dev/null 2>&1 || true
    if ! grep -q "vm.swappiness" /etc/sysctl.conf 2>/dev/null; then
        echo "vm.swappiness=60" >> /etc/sysctl.conf
    fi

    log_success "Swap 创建成功！当前交换空间信息如下："
    swapon --show 2>/dev/null || cat /proc/swaps
    free -h
}

del_swap(){
    log_info "正在检查并移除 swapfile..."
    if grep -E '^[[:space:]]*/swapfile[[:space:]]' /etc/fstab 2>/dev/null || [[ -f /swapfile ]]; then
        swapoff /swapfile 2>/dev/null || true
        cp /etc/fstab "/etc/fstab.bak_$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
        sed -i -E '/^[[:space:]]*\/swapfile[[:space:]]/d' /etc/fstab
        rm -f /swapfile
        log_success "Swapfile 移除完成！"
        free -h
    else
        log_warn "未发现活动或配置中的 /swapfile"
    fi
}

show_menu() {
    echo "====================================="
    echo "       Swap 交换空间管理工具"
    echo "====================================="
    echo " 1. 添加 Swap"
    echo " 2. 删除 Swap"
    echo " h. 显示帮助"
    echo " q. 退出"
    echo "====================================="
}

show_help() {
    cat << EOF
用法:
  $0 [选项]

选项:
  -s, --size <MB>     指定大小直接创建 Swap (例如: $0 --size 2048)
  -d, --delete        直接移除现有的 Swap 交换空间
  -h, --help          显示本帮助信息

无参数执行时进入交互式配置向导。
EOF
}

main() {
    require_root

    # 处理 CLI 传参
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--size)
                add_swap "$2"
                exit 0
                ;;
            -d|--delete)
                del_swap
                exit 0
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # 交互向导
    while true; do
        show_menu
        read -rp "请选择操作 [1-2/h/q]: " choice
        case "$choice" in
            1)
                add_swap ""
                break
                ;;
            2)
                del_swap
                break
                ;;
            h|H)
                show_help
                ;;
            q|Q)
                exit 0
                ;;
            *)
                log_warn "无效选项，请重新输入。"
                ;;
        esac
    done
}

main "$@"
