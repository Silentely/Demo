#!/bin/bash
# 脚本名称: clean_snap.sh
# 功能: 删除snap旧版本包
# 作者: Silentely
# 创建日期: 2025-06-08
# 最后更新: 2025-06-08
# 许可证: MIT
# 项目地址: https://github.com/Silentely/Demo

# 引入通用函数库
if [ -f "../lib/common.sh" ]; then
    source ../lib/common.sh
elif [ -f "./lib/common.sh" ]; then
    source ./lib/common.sh
elif [ -f "/usr/local/lib/common.sh" ]; then
    source /usr/local/lib/common.sh
else
    # 如果找不到通用函数库，则使用内置定义
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
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
    
    show_help() {
        echo "用法: $0 [选项]"
        echo "选项:"
        echo "  -h, --help     显示帮助信息"
        echo ""
        echo "功能: 删除系统中不再需要的旧版本snap包"
    }
fi

# 设置脚本在遇到错误时退出
set -eu

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

# 主函数
main() {
    # 检查是否安装了snap
    if ! command -v snap &> /dev/null; then
        log_warn "系统中未安装snap"
        exit 0
    fi
    
    log_info "开始清理旧版本snap包..."
    
    # 关闭所有snap应用
    log_info "正在关闭所有snap应用..."
    sudo snap list | awk 'NR>1 {print $1}' | xargs -r -I {} sudo snap stop {} 2>/dev/null || true
    
    # 删除旧版本snap包
    log_info "正在删除旧版本snap包..."
    snap list --all | awk '/disabled/{print $1, $3}' |
        while read snapname revision; do
            if [ -n "$snapname" ] && [ -n "$revision" ]; then
                log_info "正在删除 $snapname (版本: $revision)..."
                sudo snap remove "$snapname" --revision="$revision" || log_error "删除 $snapname 失败"
            fi
        done
    
    log_success "旧版本snap包清理完成"
}

# 执行主函数
main