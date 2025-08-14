#!/bin/bash

# ==============================================================================
# PostgreSQL 数据库自动化备份脚本 (增强版)
#
# 功能:
#   - 使用 pg_dump 备份指定的 PostgreSQL 数据库。
#   - 使用安全的 .pgpass 文件处理密码，无需在脚本中明文存储。
#   - 生成带有时间戳的备份文件。
#   - 记录详细的执行日志，包括文件大小和清理详情。
#   - 自动删除指定天数前的旧备份。
# ==============================================================================

# ==============================================================================
# 使用教程 (HOW-TO)
#
# --- 步骤 1: 设置 .pgpass 实现免密登录 (关键步骤) ---
# 为了让脚本能自动运行，您需要创建一个密码文件，这样就不需要在脚本中写入密码。
#
# 1. 创建 .pgpass 文件:
#    在【执行此脚本的用户】的家目录下创建文件。例如，如果您用 root 运行，
#    文件路径就是 /root/.pgpass。
#    touch /root/.pgpass
#
# 2. 编辑文件内容:
#    文件格式为：hostname:port:database:username:password
#    例如:
#    localhost:5432:onehub_db:onehub_user:YourS3cretPa$$w0rd
#
# 3. 设置严格的文件权限 (最重要!):
#    如果权限不正确，PostgreSQL 将会因为安全原因忽略此文件。
#    chmod 600 /root/.pgpass
#
# --- 步骤 2: 设置 Cron 定时任务 ---
# 使用 crontab 来让脚本每天自动执行。
#
# 1. 编辑 crontab:
#    crontab -e
#
# 2. 添加任务:
#    在文件末尾加入一行，指定执行时间和脚本路径。
#    例如，每天凌晨 2:30 执行备份：
#    30 2 * * * /opt/one-hub/backup_postgres.sh > /dev/null 2>&1
#
#    (> /dev/null 2>&1 的意思是不要将任何屏幕输出发送到邮件，所有日志都由脚本自己记录)
# ==============================================================================

# --- 参数设置区 (请根据您的环境修改) ---

# 数据库连接信息
DB_USER="onehub_user"
DB_HOST="localhost"
DB_PORT="5432"
DB_NAME="onehub_db"

# 备份文件存储路径
BACKUP_DIR="/var/backups/postgresql"

# 备份文件保留天数 (例如，保留最近 7 天的备份)
RETENTION_DAYS=7

# 【重要】pg_dump 命令的完整路径
# 请执行 `find / -name pg_dump` 来找到您系统上的正确路径
# 如果您的服务器版本是 17，路径很可能是 /usr/lib/postgresql/17/bin/pg_dump
PG_DUMP_PATH="/usr/lib/postgresql/17/bin/pg_dump"

# --- 脚本主体 (通常无需修改) ---

# 设置备份文件名和日志文件路径
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.dump"
LOG_FILE="$BACKUP_DIR/backup_log.txt"

# --- 函数：写入日志 ---
log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$LOG_FILE"
}

# --- 开始执行 ---
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

# 检查 pg_dump 命令是否存在
if [ ! -x "$PG_DUMP_PATH" ]; then
    log "【致命错误】pg_dump 命令不存在或无法执行于: $PG_DUMP_PATH"
    log "================== 备份任务结束 (失败) ================"
    exit 1
fi
log "pg_dump 命令检查通过: $PG_DUMP_PATH"

# 执行 pg_dump 命令
log "准备执行备份，数据库: $DB_NAME"
log "备份文件将存储至: $BACKUP_FILE"
"$PG_DUMP_PATH" -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -Fc "$DB_NAME" > "$BACKUP_FILE"

# 检查上一条命令的结束状态码 ($?)
# 0 代表成功，非 0 代表失败
if [ $? -eq 0 ]; then
    # 计算文件大小，提供更丰富的日志信息
    FILE_SIZE=$(du -h "$BACKUP_FILE" | awk '{print $1}')
    log "备份成功！文件大小: $FILE_SIZE"
else
    log "【错误】备份失败！请检查数据库连接、.pgpass 文件或 pg_dump 命令参数。"
    # 移除此次失败产生的空文件或不完整文件
    rm -f "$BACKUP_FILE"
    log "================== 备份任务结束 (失败) ================"
    exit 1
fi

# --- 清理旧的备份文件 ---
log "开始清理 ${RETENTION_DAYS} 天前的旧备份..."
# 首先查找有多少个旧文件
OLD_BACKUPS_COUNT=$(find "$BACKUP_DIR" -type f -name "*.dump" -mtime +"$RETENTION_DAYS" | wc -l)

if [ "$OLD_BACKUPS_COUNT" -gt 0 ]; then
    log "发现 ${OLD_BACKUPS_COUNT} 个旧备份文件，准备删除。"
    # 执行删除操作
    find "$BACKUP_DIR" -type f -name "*.dump" -mtime +"$RETENTION_DAYS" -delete
    if [ $? -eq 0 ]; then
        log "旧备份清理完成。"
    else
        log "【警告】旧备份清理过程中发生错误。"
    fi
else
    log "没有找到需要清理的旧备份文件。"
fi

log "================== 备份任务结束 (成功) ================"
echo "" >> "$LOG_FILE" # 加入空行，方便阅读日志

exit 0
