#!/usr/bin/env bash
# 脚本名称: swap.sh
# 功能: 一键添加或删除swap分区
# 作者: Silentely
# 创建日期: 2025-06-08
# 最后更新: 2025-06-08
# 许可证: MIT
# Blog: https://dao.ke/

# 引入通用函数库
if [ -f "../lib/common.sh" ]; then
    source ../lib/common.sh
elif [ -f "./lib/common.sh" ]; then
    source ./lib/common.sh
elif [ -f "/usr/local/lib/common.sh" ]; then
    source /usr/local/lib/common.sh
else
    # 如果找不到通用函数库，则使用内置定义
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
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
    
    show_help() {
        echo "用法: $0 [选项]"
        echo "选项:"
        echo "  -h, --help     显示帮助信息"
        echo ""
        echo "功能: 一键添加或删除swap分区，支持自定义swap大小"
    }
fi

# root权限检查
root_need(){
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本必须以root权限运行！"
        exit 1
    fi
}

# 检测OpenVZ
ovz_no(){
    if [[ -d "/proc/vz" ]]; then
        log_error "您的VPS基于OpenVZ，不支持此操作！"
        exit 1
    fi
}

add_swap(){
    log_info "请输入需要添加的swap大小，建议为物理内存的1-2倍！"
    read -rp "请输入swap大小(单位MB): " swapsize

    # 验证输入是否为数字
    if ! [[ "$swapsize" =~ ^[0-9]+$ ]] || [ "$swapsize" -le 0 ]; then
        log_error "输入的swap大小无效，请输入一个正整数"
        exit 1
    fi

    # 检查是否存在swapfile
    if ! grep -q "swapfile" /etc/fstab; then
        log_info "未发现swapfile，正在创建swapfile..."
        fallocate -l "${swapsize}M" /swapfile
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        echo '/swapfile none swap defaults 0 0' >> /etc/fstab
        log_success "swap创建成功，并查看信息："
        cat /proc/swaps
        grep Swap /proc/meminfo
    else
        log_warn "swapfile已存在，swap设置失败，请先运行脚本删除swap后重新设置！"
    fi
}

del_swap(){
    # 检查是否存在swapfile
    if grep -q "swapfile" /etc/fstab; then
        log_info "发现swapfile，正在移除..."
        swapoff /swapfile 2>/dev/null || true
        sed -i '/swapfile/d' /etc/fstab
        rm -f /swapfile
        log_success "swapfile移除完成"
    else
        log_warn "未发现swapfile"
    fi
}

# 显示帮助信息
show_menu() {
    echo "========== Swap分区管理工具 =========="
    echo "1. 添加swap分区"
    echo "2. 删除swap分区"
    echo "h. 显示帮助信息"
    echo "q. 退出"
    echo "====================================="
}

# 主程序
main() {
    root_need
    ovz_no
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 显示菜单
    while true; do
        show_menu
        read -rp "请选择操作 [1-2|h|q]: " choice
        case $choice in
            1)
                add_swap
                ;;
            2)
                del_swap
                ;;
            h|H)
                show_help
                ;;
            q|Q)
                log_info "退出程序"
                exit 0
                ;;
            *)
                log_warn "无效选择，请重新输入"
                ;;
        esac
        echo
    done
}

# 执行主程序
main "$@"