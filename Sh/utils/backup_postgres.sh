#!/bin/bash

# ==============================================================================
# PostgreSQL 数据库自动化备份脚本 (增强自适应版)
#
# 功能:
#   - 智能自动探测 pg_dump 路径 (支持 PostgreSQL 12-17+ 及各发行版)
#   - 使用 pg_dump 备份指定的 PostgreSQL 数据库
#   - 使用安全的 .pgpass 文件处理密码，无需在脚本中明文存储
#   - 生成带有时间戳的备份文件，支持自定义保留天数
#   - 详细日志记录与失败自清理
# ==============================================================================

# --- 参数设置区 (支持环境变量直接覆盖) ---

DB_USER="${DB_USER:-onehub_user}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-onehub_db}"

BACKUP_DIR="${BACKUP_DIR:-/var/backups/postgresql}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"

# 智能探测 pg_dump 命令路径
detect_pg_dump() {
    if [[ -n "$PG_DUMP_PATH" && -x "$PG_DUMP_PATH" ]]; then
        echo "$PG_DUMP_PATH"
        return
    fi
    if command -v pg_dump &>/dev/null; then
        command -v pg_dump
        return
    fi
    # 扫描 /usr/lib/postgresql/*/bin/pg_dump 取最高版本
    local candidate
    candidate=$(find /usr/lib/postgresql/ -name pg_dump -type f 2>/dev/null | sort -V | tail -n 1)
    if [[ -n "$candidate" && -x "$candidate" ]]; then
        echo "$candidate"
        return
    fi
    echo ""
}

PG_DUMP_PATH=$(detect_pg_dump)

# --- 脚本主体 ---

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.dump"
LOG_FILE="$BACKUP_DIR/backup_log.txt"

log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" | tee -a "$LOG_FILE"
}

log "================== 开始备份任务 =================="

# 检查并创建备份目录
if [ ! -d "$BACKUP_DIR" ]; then
    log "备份目录不存在，正在创建: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    if [ $? -ne 0 ]; then
        log "【致命错误】无法创建备份目录，请检查权限！"
        exit 1
    fi
fi
log "备份目录检查通过: $BACKUP_DIR"

# 检查 pg_dump
if [ -z "$PG_DUMP_PATH" ] || [ ! -x "$PG_DUMP_PATH" ]; then
    log "【致命错误】系统未找到可执行的 pg_dump 命令，请确认已安装 postgresql-client！"
    log "================== 备份任务结束 (失败) ================"
    exit 1
fi
log "使用 pg_dump 路径: $PG_DUMP_PATH"

# 执行备份
log "准备执行备份，数据库: $DB_NAME"
log "备份文件目标: $BACKUP_FILE"
"$PG_DUMP_PATH" -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -Fc "$DB_NAME" > "$BACKUP_FILE" 2>>"$LOG_FILE"

if [ $? -eq 0 ] && [ -s "$BACKUP_FILE" ]; then
    FILE_SIZE=$(du -h "$BACKUP_FILE" | awk '{print $1}')
    log "备份成功！文件大小: $FILE_SIZE"
else
    log "【错误】备份失败！请检查数据库连接、.pgpass 权限或网络。"
    rm -f "$BACKUP_FILE"
    log "================== 备份任务结束 (失败) ================"
    exit 1
fi

# 清理过期备份
log "开始清理 ${RETENTION_DAYS} 天前的旧备份..."
OLD_BACKUPS_COUNT=$(find "$BACKUP_DIR" -type f -name "${DB_NAME}_*.dump" -mtime +"$RETENTION_DAYS" 2>/dev/null | wc -l)

if [ "$OLD_BACKUPS_COUNT" -gt 0 ]; then
    log "发现 ${OLD_BACKUPS_COUNT} 个旧备份文件，正在清理..."
    find "$BACKUP_DIR" -type f -name "${DB_NAME}_*.dump" -mtime +"$RETENTION_DAYS" -delete
    log "旧备份清理完成。"
else
    log "没有找到需要清理的旧备份文件。"
fi

log "================== 备份任务结束 (成功) ================"
exit 0
