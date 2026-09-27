#!/bin/bash
# ==============================================================================
# 脚本名称: clean_snap.sh
# 功能:     安全清理 snap 历史禁用旧版本包 (不影响当前正在运行的服务)
# 作者:     Silentely
# 许可证:   MIT
# 项目地址: https://github.com/Silentely/Demo
# ==============================================================================

# 引入通用函数库
if [ -f "../lib/common.sh" ]; then
    source ../lib/common.sh
elif [ -f "./lib/common.sh" ]; then
    source ./lib/common.sh
elif [ -f "/usr/local/lib/common.sh" ]; then
    source /usr/local/lib/common.sh
else
    RED='\033[0;31m'
    GREEN='\033[0;32m'
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
        echo "功能: 安全清理系统中已停用的旧版本 snap 包，释放磁盘空间"
    }
fi

set -eu

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

main() {
    if ! command -v snap &> /dev/null; then
        log_warn "系统中未安装 snap，无需清理"
        exit 0
    fi
    
    log_info "正在扫描已禁用的旧版本 snap 包..."
    local disabled_snaps
    disabled_snaps=$(snap list --all 2>/dev/null | awk '/disabled/{print $1, $3}')
    
    if [ -z "$disabled_snaps" ]; then
        log_success "未发现已禁用的旧版本 snap 包，系统很干净！"
        exit 0
    fi
    
    echo "$disabled_snaps" | while read -r snapname revision; do
        if [ -n "$snapname" ] && [ -n "$revision" ]; then
            log_info "正在清理旧版本: $snapname (revision: $revision)..."
            sudo snap remove "$snapname" --revision="$revision" || log_warn "清理 $snapname ($revision) 失败，可能正在被引用"
        fi
    done
    
    log_success "旧版本 snap 包清理完成"
}

main
