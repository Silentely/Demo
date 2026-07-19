#!/usr/bin/env bash
#
# AxonHub SQLite -> PostgreSQL migration helper
#
# 这个脚本是给本地/服务器手动迁移使用的单文件工具，不依赖 AxonHub 项目脚本体系。
# 它固化了一次真实迁移中踩过的坑：
#   1. AxonHub/Ent 应先在 PostgreSQL 中创建 schema；pgloader 只导入数据，不建表。
#   2. SQLite 中可能保存 Go time.String() 格式时间，例如：
#        2026-05-02 11:05:49.982117432 +0000 UTC
#        2026-05-02 10:58:26.949679031 +0000 UTC m=+169.046904132
#      PostgreSQL timestamp/timestamptz 不接受这种格式，需要先清洗成：
#        2026-05-02 11:05:49.982117+00:00
#   3. SQLite JSON 字段有时是 BLOB，pgloader 会转成 #(91 34...) byte-vector，
#      PostgreSQL json/jsonb 会拒绝，因此需要先把对应 BLOB 解码成 TEXT。
#   4. 导入后必须校准 PostgreSQL sequence，否则后续新增数据可能主键冲突。
#   5. pgloader rejected rows/log 可能包含密钥或请求内容，默认迁移结束后清理。
#
# 推荐迁移流程：
#
#   # 1. 停止 AxonHub，确保 SQLite 不再被写入。
#   docker compose stop axonhub
#
#   # 2. 把 AxonHub 配置切到 PostgreSQL，启动一次，让 Ent 自动创建 PostgreSQL schema。
#   #    注意：这一步由你手动完成。本脚本默认不启动/停止服务，避免误操作部署环境。
#   docker compose up -d axonhub
#
#   # 3. 确认 schema 已创建后再次停止 AxonHub。
#   docker compose stop axonhub
#
#   # 4. 迁移。推荐用环境变量传 DSN，避免 shell 历史里留下密码。
#   export AXONHUB_PG_DSN='postgres://axonhub:你的密码@postgres-shared:5432/axonhub?sslmode=disable'
#   ./sqlite-to-postgres-migrate.sh --sqlite "/opt/axonhub/data/axonhub.db"
#
#   # 5. 脚本校验通过后启动 AxonHub。
#   docker compose up -d axonhub
#
# 常用示例：
#
#   # 只检查依赖、源库、目标库 schema 和目标库是否为空，不执行导入。
#   ./sqlite-to-postgres-migrate.sh \
#     --sqlite "/opt/axonhub/data/axonhub.db" \
#     --pg-dsn "postgres://axonhub:***@postgres-shared:5432/axonhub?sslmode=disable" \
#     --dry-run
#
#   # 正式迁移，PG DSN 从 AXONHUB_PG_DSN 读取。
#   AXONHUB_PG_DSN='postgres://axonhub:***@postgres-shared:5432/axonhub?sslmode=disable' \
#   ./sqlite-to-postgres-migrate.sh --sqlite "/opt/axonhub/data/axonhub.db"
#
#   # 失败排查：保留临时清洗库、pgloader load 文件和日志。
#   ./sqlite-to-postgres-migrate.sh \
#     --sqlite "/opt/axonhub/data/axonhub.db" \
#     --pg-dsn "postgres://axonhub:***@postgres-shared:5432/axonhub?sslmode=disable" \
#     --keep-workdir
#
#   # 重跑迁移到已有 schema 的空库时，通常不需要任何危险参数。
#   # 如果确认要清空目标 PG 所有 public 表再导入，必须显式传 --truncate-target，
#   # 并在交互确认中输入 TRUNCATE。
#   ./sqlite-to-postgres-migrate.sh \
#     --sqlite "/opt/axonhub/data/axonhub.db" \
#     --pg-dsn "postgres://axonhub:***@postgres-shared:5432/axonhub?sslmode=disable" \
#     --truncate-target
#
# 参数说明：
#
#   --sqlite PATH
#       必填。SQLite 数据库路径，例如 /opt/axonhub/data/axonhub.db。
#
#   --pg-dsn DSN
#       PostgreSQL 连接串。也可以通过 AXONHUB_PG_DSN 环境变量传入。
#       脚本日志会隐藏密码，但临时 pgloader load 文件中不可避免会包含 DSN；
#       默认结束时清理临时目录。
#
#   --allow-non-empty-target
#       允许目标 PostgreSQL public 表中已有数据。默认不允许。
#       注意：如果目标已有数据且不清空，可能出现主键冲突或重复数据。
#
#   --truncate-target
#       导入前清空目标 PostgreSQL public schema 下所有表，并 RESTART IDENTITY CASCADE。
#       这是危险操作，默认需要交互输入 TRUNCATE 确认。
#
#   --yes
#       与 --truncate-target 配合使用，跳过交互确认。仅适合自动化环境。
#
#   --keep-workdir
#       保留临时目录，便于检查 sanitized SQLite、pgloader load 文件和日志。
#       注意：临时文件可能包含敏感数据。
#
#   --dry-run
#       只做检查，不备份、不清洗、不导入、不修改 PostgreSQL。
#
#   -h, --help
#       显示帮助。
#
# 环境要求：
#
#   sqlite3
#   psql
#   pgloader
#   python3
#
# 设计约束：
#
#   - 不修改源 SQLite 数据库；清洗只作用于临时副本。
#   - 不自动创建 AxonHub PostgreSQL schema；schema 应由 AxonHub/Ent 创建。
#   - 默认拒绝导入到非空 PostgreSQL。
#   - 不在日志输出完整 PostgreSQL 密码。

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SQLITE_PATH=""
PG_DSN="${AXONHUB_PG_DSN:-}"
ALLOW_NON_EMPTY_TARGET="false"
TRUNCATE_TARGET="false"
ASSUME_YES="false"
KEEP_WORKDIR="false"
DRY_RUN="false"
WORKDIR=""
TMP_SQLITE=""
PGLOADER_FILE=""
PGLOADER_LOG=""
JSON_COLUMNS_FILE=""

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

print_step() {
    echo ""
    echo -e "${GREEN}==>${NC} $1"
}

usage() {
    sed -n '2,130p' "$0" | sed 's/^# \{0,1\}//'
}

die() {
    print_error "$1"
    exit 1
}

cleanup() {
    local status=$?

    if [[ "$KEEP_WORKDIR" == "true" ]]; then
        if [[ -n "$WORKDIR" ]]; then
            print_warning "保留临时目录：$WORKDIR"
            print_warning "注意：临时文件可能包含 API Key、请求内容或 PostgreSQL DSN。"
        fi
        exit "$status"
    fi

    if [[ -n "$WORKDIR" && -d "$WORKDIR" ]]; then
        rm -rf "$WORKDIR"
    fi

    # pgloader 默认会把 rejected rows 写到 /tmp/pgloader，里面可能包含敏感数据。
    if [[ -d "/tmp/pgloader" ]]; then
        rm -rf "/tmp/pgloader"
    fi

    exit "$status"
}

trap cleanup EXIT

mask_dsn() {
    local dsn="$1"
    python3 - "$dsn" <<'PY'
import re
import sys

dsn = sys.argv[1]
print(re.sub(r'(?i)(postgres(?:ql)?://[^:/?#]+:)([^@/?#]+)(@)', r'\1***\3', dsn))
PY
}

require_tool() {
    local name="$1"
    if ! command -v "$name" >/dev/null 2>&1; then
        die "缺少依赖工具：$name"
    fi
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --sqlite)
                [[ $# -ge 2 ]] || die "--sqlite 需要 PATH 参数"
                SQLITE_PATH="$2"
                shift 2
                ;;
            --pg-dsn)
                [[ $# -ge 2 ]] || die "--pg-dsn 需要 DSN 参数"
                PG_DSN="$2"
                shift 2
                ;;
            --allow-non-empty-target)
                ALLOW_NON_EMPTY_TARGET="true"
                shift
                ;;
            --truncate-target)
                TRUNCATE_TARGET="true"
                ALLOW_NON_EMPTY_TARGET="true"
                shift
                ;;
            --yes)
                ASSUME_YES="true"
                shift
                ;;
            --keep-workdir)
                KEEP_WORKDIR="true"
                shift
                ;;
            --dry-run)
                DRY_RUN="true"
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                die "未知参数：$1。使用 --help 查看帮助。"
                ;;
        esac
    done

    [[ -n "$SQLITE_PATH" ]] || die "缺少 --sqlite PATH"
    [[ -n "$PG_DSN" ]] || die "缺少 --pg-dsn DSN，或设置 AXONHUB_PG_DSN 环境变量"
}

sqlite_scalar() {
    sqlite3 "$SQLITE_PATH" "$1"
}

psql_scalar() {
    psql -X -v ON_ERROR_STOP=1 -At "$PG_DSN" -c "$1"
}

psql_exec_stdin() {
    psql -X -v ON_ERROR_STOP=1 "$@" "$PG_DSN"
}

check_dependencies() {
    print_step "检查依赖工具"
    require_tool sqlite3
    require_tool psql
    require_tool pgloader
    require_tool python3
    print_success "依赖工具齐全：sqlite3 / psql / pgloader / python3"
}

check_sqlite_source() {
    print_step "检查 SQLite 源库"

    [[ -f "$SQLITE_PATH" ]] || die "SQLite 文件不存在：$SQLITE_PATH"
    [[ -r "$SQLITE_PATH" ]] || die "SQLite 文件不可读：$SQLITE_PATH"

    local integrity
    integrity="$(sqlite_scalar "PRAGMA integrity_check;")"
    if [[ "$integrity" != "ok" ]]; then
        die "SQLite integrity_check 失败：$integrity"
    fi

    local table_count
    table_count="$(sqlite_scalar "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")"
    [[ "$table_count" =~ ^[0-9]+$ ]] || die "无法读取 SQLite 表数量"
    (( table_count > 0 )) || die "SQLite 中没有可迁移业务表"

    print_success "SQLite integrity_check=ok，业务表数量：$table_count"
}

check_postgres_target() {
    print_step "检查 PostgreSQL 目标库"

    local masked
    masked="$(mask_dsn "$PG_DSN")"
    print_info "目标 PostgreSQL：$masked"

    local pg_version
    pg_version="$(psql_scalar "SELECT version();")"
    print_info "PostgreSQL 连接正常：${pg_version%%,*}"

    local table_count
    table_count="$(psql_scalar "SELECT COUNT(*) FROM pg_tables WHERE schemaname = 'public';")"
    [[ "$table_count" =~ ^[0-9]+$ ]] || die "无法读取 PostgreSQL public 表数量"

    if (( table_count == 0 )); then
        die "PostgreSQL public schema 没有表。请先用 PG 配置启动一次 AxonHub，让 Ent 创建 schema。"
    fi

    if (( table_count < 20 )); then
        print_warning "PostgreSQL public 表数量只有 $table_count，低于 AxonHub 常见 schema 数量；请确认 schema 已完整创建。"
    else
        print_success "PostgreSQL schema 已存在，public 表数量：$table_count"
    fi
}

postgres_tables() {
    psql -X -v ON_ERROR_STOP=1 -At "$PG_DSN" -c "SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;"
}

sqlite_tables_from_file() {
    local db_file="$1"
    sqlite3 "$db_file" "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name;"
}

postgres_table_count() {
    local table="$1"
    psql -X -v ON_ERROR_STOP=1 -At "$PG_DSN" -c "SELECT COUNT(*) FROM \"${table}\";"
}

sqlite_table_count() {
    local db_file="$1"
    local table="$2"
    sqlite3 "$db_file" "SELECT COUNT(*) FROM \"${table}\";"
}

target_total_rows() {
    local total=0
    local table
    while IFS= read -r table; do
        [[ -n "$table" ]] || continue
        local count
        count="$(postgres_table_count "$table")"
        [[ "$count" =~ ^[0-9]+$ ]] || die "无法读取 PostgreSQL 表 ${table} 行数"
        total=$((total + count))
    done < <(postgres_tables)
    echo "$total"
}

check_target_empty_policy() {
    print_step "检查目标库数据安全策略"

    local total
    total="$(target_total_rows)"

    if [[ "$TRUNCATE_TARGET" == "true" ]]; then
        print_warning "已启用 --truncate-target，导入前会清空 PostgreSQL public schema 下所有表。"
        return
    fi

    if (( total > 0 )) && [[ "$ALLOW_NON_EMPTY_TARGET" != "true" ]]; then
        die "目标 PostgreSQL 已有 $total 行数据。为避免重复/覆盖，默认中止。确认风险后可使用 --allow-non-empty-target 或 --truncate-target。"
    fi

    if (( total > 0 )); then
        print_warning "目标 PostgreSQL 已有 $total 行数据，因指定 --allow-non-empty-target，脚本将继续。"
    else
        print_success "目标 PostgreSQL 当前无数据，可安全导入。"
    fi
}

confirm_truncate_if_needed() {
    [[ "$TRUNCATE_TARGET" == "true" ]] || return 0

    print_step "确认清空 PostgreSQL 目标表"
    print_warning "危险操作：将 TRUNCATE PostgreSQL public schema 下所有表，并 RESTART IDENTITY CASCADE。"
    print_warning "影响范围：目标库 $(mask_dsn "$PG_DSN")"
    print_warning "风险：目标 PostgreSQL 中已有数据会被删除。"

    if [[ "$ASSUME_YES" == "true" ]]; then
        print_warning "已指定 --yes，跳过交互确认。"
        return 0
    fi

    local reply
    read -r -p "请输入 TRUNCATE 确认继续： " reply
    if [[ "$reply" != "TRUNCATE" ]]; then
        die "未确认 TRUNCATE，已中止。"
    fi
}

truncate_target_if_needed() {
    [[ "$TRUNCATE_TARGET" == "true" ]] || return 0

    print_step "清空 PostgreSQL 目标表"
    psql_exec_stdin <<'SQL'
DO $$
DECLARE
    stmt text;
BEGIN
    SELECT 'TRUNCATE TABLE ' || string_agg(format('%I.%I', schemaname, tablename), ', ') || ' RESTART IDENTITY CASCADE'
    INTO stmt
    FROM pg_tables
    WHERE schemaname = 'public';

    IF stmt IS NOT NULL THEN
        EXECUTE stmt;
    END IF;
END
$$;
SQL
    print_success "目标表已清空。"
}

prepare_workdir() {
    WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/axonhub-sqlite-pg.XXXXXX")"
    TMP_SQLITE="$WORKDIR/axonhub.sanitized.db"
    PGLOADER_FILE="$WORKDIR/load.pgloader"
    PGLOADER_LOG="$WORKDIR/pgloader.log"
    JSON_COLUMNS_FILE="$WORKDIR/pg-json-columns.txt"
}

backup_sqlite_source() {
    print_step "备份 SQLite 源库"

    local timestamp
    timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
    local backup_path="${SQLITE_PATH}.backup-${timestamp}"

    sqlite3 "$SQLITE_PATH" "PRAGMA wal_checkpoint(FULL);"
    sqlite3 "$SQLITE_PATH" ".backup '${backup_path}'"

    print_success "已创建源库备份：$backup_path"
}

copy_sqlite_to_workdir() {
    print_step "复制 SQLite 到临时工作库"
    sqlite3 "$SQLITE_PATH" ".backup '${TMP_SQLITE}'"
    print_success "临时 SQLite：$TMP_SQLITE"
}

export_json_columns() {
    psql -X -v ON_ERROR_STOP=1 -AtF '|' "$PG_DSN" \
        -c "SELECT table_name, column_name FROM information_schema.columns WHERE table_schema = 'public' AND data_type IN ('json', 'jsonb') ORDER BY table_name, column_name;" \
        > "$JSON_COLUMNS_FILE"
}

sanitize_sqlite_copy() {
    print_step "清洗临时 SQLite：Go 时间格式与 JSON BLOB"

    export_json_columns

    python3 - "$TMP_SQLITE" "$JSON_COLUMNS_FILE" <<'PY'
import json
import re
import sqlite3
import sys

db_path = sys.argv[1]
json_columns_file = sys.argv[2]

go_time_re = re.compile(
    r'^(\d{4}-\d{2}-\d{2})[ T]'
    r'(\d{2}:\d{2}:\d{2})'
    r'(?:\.(\d+))? '
    r'([+-])(\d{2})(\d{2}) UTC'
    r'(?: m=[+-]?[0-9.]+)?$'
)


def quote_ident(name: str) -> str:
    return '"' + name.replace('"', '""') + '"'


def normalize_go_time(value):
    if not isinstance(value, str):
        return None

    match = go_time_re.match(value)
    if not match:
        return None

    date_part, time_part, fractional, sign, offset_hour, offset_minute = match.groups()
    if fractional:
        normalized_fractional = (fractional[:6]).ljust(6, '0')
        return f'{date_part} {time_part}.{normalized_fractional}{sign}{offset_hour}:{offset_minute}'

    return f'{date_part} {time_part}{sign}{offset_hour}:{offset_minute}'


def load_json_columns(path):
    pairs = set()
    with open(path, 'r', encoding='utf-8') as handle:
        for raw_line in handle:
            line = raw_line.rstrip('\n')
            if not line or '|' not in line:
                continue
            table, column = line.split('|', 1)
            pairs.add((table, column))
    return pairs


def table_columns(conn, table):
    rows = conn.execute(f'PRAGMA table_info({quote_ident(table)})').fetchall()
    return [row[1] for row in rows]


def sqlite_tables(conn):
    rows = conn.execute(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name"
    ).fetchall()
    return [row[0] for row in rows]


def sanitize_time_columns(conn):
    changed = 0
    for table in sqlite_tables(conn):
        columns = table_columns(conn, table)
        timestamp_columns = [
            column for column in columns
            if column in {'created_at', 'updated_at', 'deleted_at'} or column.endswith('_at')
        ]

        for column in timestamp_columns:
            select_sql = (
                f'SELECT rowid, {quote_ident(column)} '
                f'FROM {quote_ident(table)} '
                f"WHERE typeof({quote_ident(column)}) = 'text' "
                f"AND {quote_ident(column)} LIKE '% UTC%'"
            )
            update_sql = (
                f'UPDATE {quote_ident(table)} '
                f'SET {quote_ident(column)} = ? '
                f'WHERE rowid = ?'
            )

            updates = []
            for rowid, value in conn.execute(select_sql):
                normalized = normalize_go_time(value)
                if normalized and normalized != value:
                    updates.append((normalized, rowid))

            if updates:
                conn.executemany(update_sql, updates)
                changed += len(updates)

    return changed


def sanitize_json_blobs(conn, json_columns):
    changed = 0
    existing_tables = set(sqlite_tables(conn))

    for table, column in sorted(json_columns):
        if table not in existing_tables:
            continue
        if column not in table_columns(conn, table):
            continue

        select_sql = (
            f'SELECT rowid, {quote_ident(column)} '
            f'FROM {quote_ident(table)} '
            f"WHERE typeof({quote_ident(column)}) = 'blob'"
        )
        update_sql = (
            f'UPDATE {quote_ident(table)} '
            f'SET {quote_ident(column)} = ? '
            f'WHERE rowid = ?'
        )

        updates = []
        for rowid, value in conn.execute(select_sql):
            if value is None:
                continue
            if isinstance(value, memoryview):
                value = value.tobytes()
            if not isinstance(value, (bytes, bytearray)):
                continue

            try:
                decoded = bytes(value).decode('utf-8')
                json.loads(decoded)
            except Exception:
                continue

            updates.append((decoded, rowid))

        if updates:
            conn.executemany(update_sql, updates)
            changed += len(updates)

    return changed


conn = sqlite3.connect(db_path)
try:
    conn.execute('PRAGMA journal_mode=DELETE')
    conn.execute('BEGIN')
    time_changes = sanitize_time_columns(conn)
    json_changes = sanitize_json_blobs(conn, load_json_columns(json_columns_file))
    conn.commit()
finally:
    conn.close()

print(f'time_values_normalized={time_changes}')
print(f'json_blobs_converted={json_changes}')
PY

    sqlite3 "$TMP_SQLITE" "VACUUM;"
    sqlite3 "$TMP_SQLITE" "PRAGMA integrity_check;" | grep -qx "ok" || die "清洗后的临时 SQLite integrity_check 失败"
    print_success "临时 SQLite 清洗完成。"
}

create_pgloader_file() {
    print_step "生成 pgloader 配置"

    # 注意：load 文件包含完整 DSN，因此放在临时目录，默认迁移结束清理。
    {
        echo "LOAD DATABASE"
        echo "     FROM sqlite://${TMP_SQLITE}"
        echo "     INTO ${PG_DSN}"
        echo ""
        echo " WITH data only,"
        echo "      create no tables,"
        echo "      create no indexes,"
        echo "      reset sequences,"
        echo "      downcase identifiers"
        echo ""
        echo " SET work_mem to '16MB',"
        echo "     maintenance_work_mem to '512 MB';"
    } > "$PGLOADER_FILE"

    chmod 600 "$PGLOADER_FILE"
    print_success "pgloader 配置已生成：$PGLOADER_FILE"
}

run_pgloader() {
    print_step "执行 pgloader 数据导入"

    if pgloader "$PGLOADER_FILE" 2>&1 | tee "$PGLOADER_LOG"; then
        print_success "pgloader 执行完成。"
    else
        print_error "pgloader 执行失败，日志：$PGLOADER_LOG"
        return 1
    fi
}

reset_postgres_sequences() {
    print_step "校准 PostgreSQL sequences"

    psql_exec_stdin <<'SQL'
DO $$
DECLARE
    rec record;
BEGIN
    FOR rec IN
        SELECT
            sequence_schema,
            sequence_name,
            table_schema,
            table_name,
            column_name
        FROM information_schema.sequences seq
        JOIN information_schema.columns col
          ON pg_get_serial_sequence(format('%I.%I', col.table_schema, col.table_name), col.column_name)
             = format('%I.%I', seq.sequence_schema, seq.sequence_name)
        WHERE sequence_schema = 'public'
    LOOP
        EXECUTE format(
            'SELECT setval(%L, COALESCE((SELECT MAX(%I) FROM %I.%I), 0) + 1, false)',
            format('%I.%I', rec.sequence_schema, rec.sequence_name),
            rec.column_name,
            rec.table_schema,
            rec.table_name
        );
    END LOOP;
END
$$;
SQL

    print_success "PostgreSQL sequences 已校准。"
}

compare_table_counts() {
    print_step "逐表对比 SQLite 与 PostgreSQL 行数"

    local failures=0
    local table

    printf "%-40s %12s %12s %s\n" "table" "sqlite" "postgres" "status"
    printf "%-40s %12s %12s %s\n" "-----" "------" "--------" "------"

    while IFS= read -r table; do
        [[ -n "$table" ]] || continue

        local sqlite_count
        local pg_count

        sqlite_count="$(sqlite_table_count "$TMP_SQLITE" "$table")"

        if pg_count="$(postgres_table_count "$table" 2>/dev/null)"; then
            :
        else
            pg_count="MISSING"
        fi

        if [[ "$sqlite_count" == "$pg_count" ]]; then
            printf "%-40s %12s %12s %s\n" "$table" "$sqlite_count" "$pg_count" "OK"
        else
            printf "%-40s %12s %12s %s\n" "$table" "$sqlite_count" "$pg_count" "MISMATCH"
            failures=$((failures + 1))
        fi
    done < <(sqlite_tables_from_file "$TMP_SQLITE")

    if (( failures > 0 )); then
        die "行数对比失败，存在 $failures 张表不一致。"
    fi

    print_success "所有 SQLite 表与 PostgreSQL 表行数一致。"
}

business_summary() {
    print_step "输出关键业务表摘要"

    local table
    for table in users systems api_keys channels requests usage_logs request_executions; do
        if psql -X -v ON_ERROR_STOP=1 -At "$PG_DSN" -c "SELECT to_regclass('public.${table}') IS NOT NULL;" | grep -qx "t"; then
            local count
            count="$(postgres_table_count "$table")"
            printf "%-24s %s\n" "$table" "$count"
        fi
    done
}

dry_run_summary() {
    print_step "Dry run 摘要"

    local sqlite_tables
    local pg_tables
    local pg_rows

    sqlite_tables="$(sqlite_scalar "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")"
    pg_tables="$(psql_scalar "SELECT COUNT(*) FROM pg_tables WHERE schemaname = 'public';")"
    pg_rows="$(target_total_rows)"

    print_info "SQLite 文件：$SQLITE_PATH"
    print_info "SQLite 业务表数量：$sqlite_tables"
    print_info "PostgreSQL public 表数量：$pg_tables"
    print_info "PostgreSQL 当前总行数：$pg_rows"
    print_success "Dry run 完成；未修改 SQLite 或 PostgreSQL。"
}

main() {
    parse_args "$@"

    check_dependencies
    check_sqlite_source
    check_postgres_target

    if [[ "$DRY_RUN" == "true" ]]; then
        dry_run_summary
        return 0
    fi

    check_target_empty_policy
    confirm_truncate_if_needed
    prepare_workdir
    backup_sqlite_source
    copy_sqlite_to_workdir
    sanitize_sqlite_copy
    truncate_target_if_needed
    create_pgloader_file
    run_pgloader
    reset_postgres_sequences
    compare_table_counts
    business_summary

    print_step "迁移完成"
    print_success "SQLite -> PostgreSQL 迁移和校验已完成。"
    print_info "建议下一步：启动 AxonHub，并检查应用健康状态和日志。"
}

main "$@"
