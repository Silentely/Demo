#!/usr/bin/env bash
# ==============================================================================
# Linux 系统清理与垃圾回收（转发脚本）
# 真实实现位于: Sh/system/cleanup.sh
# ==============================================================================

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TARGET_SCRIPT="${SCRIPT_DIR}/system/cleanup.sh"

if [[ -f "$TARGET_SCRIPT" ]]; then
    exec bash "$TARGET_SCRIPT" "$@"
else
    echo "错误: 找不到清理主脚本 $TARGET_SCRIPT" >&2
    exit 1
fi
