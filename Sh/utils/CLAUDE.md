[根目录](../../CLAUDE.md) > [Sh](../) > **utils**

---

# Sh/utils - 通用工具脚本

> **模块职责**: 提供 SSH 密钥管理、镜像源切换、数据库备份、系统重装等通用运维工具

---

## 变更记录 (Changelog)

### 2025-12-13
- 初始化模块文档
- 完成 backup_postgres.sh 配置说明
- 添加所有脚本的接口文档

---

## 模块职责

本模块包含通用系统运维工具:
- SSH 密钥一键配置
- Linux 软件源镜像切换
- PostgreSQL 数据库自动备份
- VPS 系统网络重装
- IPSet 防火墙规则管理
- 青龙面板依赖安装

---

## 入口与启动

### 主要脚本入口

| 脚本名 | 功能 | 复杂度 | 执行方式 |
|-------|------|--------|---------|
| `ssh_key.sh` | SSH 密钥一键配置 | 低 | `bash ssh_key.sh` |
| `ChangeMirrors.sh` | Linux 软件源切换 | 中 | `bash ChangeMirrors.sh` |
| `backup_postgres.sh` | PostgreSQL 自动备份 | 中 (142行) | `bash backup_postgres.sh` |
| `network-reinstall-os.sh` | VPS 系统网络重装 | 中 | `bash network-reinstall-os.sh` |
| `install_ipset.sh` | 安装 IPSet 持久化 | 低 | `bash install_ipset.sh` |
| `uninstall_ipset.sh` | 卸载 IPSet 持久化 | 低 | `bash uninstall_ipset.sh` |
| `10-ipset` | IPSet netfilter 插件 | 低 | 放入 `/usr/share/netfilter-persistent/plugins.d/` |
| `QLOneKeyDependency.sh` | 青龙面板依赖安装 | 中 | `bash QLOneKeyDependency.sh` |
| `install-system-information.sh` | 系统信息工具安装 | 低 | `bash install-system-information.sh` |
| `Network-Reinstall-System-Modify.sh` | 网络重装系统(修改版) | 高 | `bash Network-Reinstall-System-Modify.sh` |

### 远程执行示例
```bash
# SSH 密钥配置
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/utils/ssh_key.sh)

# 软件源切换
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/utils/ChangeMirrors.sh)
```

---

## 对外接口

### backup_postgres.sh (重点脚本)

**功能概述**:
- 使用 `pg_dump` 备份指定的 PostgreSQL 数据库
- 使用安全的 `.pgpass` 文件处理密码
- 生成带时间戳的备份文件
- 记录详细的执行日志
- 自动删除指定天数前的旧备份

**配置参数** (脚本内修改):
```bash
# 数据库连接信息
DB_USER="onehub_user"      # 数据库用户名
DB_HOST="localhost"         # 数据库主机
DB_PORT="5432"              # 数据库端口
DB_NAME="onehub_db"         # 数据库名称

# 备份设置
BACKUP_DIR="/var/backups/postgresql"  # 备份存储路径
RETENTION_DAYS=7                       # 备份保留天数

# pg_dump 路径(请根据实际情况修改)
PG_DUMP_PATH="/usr/lib/postgresql/17/bin/pg_dump"
```

**前置配置 - .pgpass 文件**:

1. **创建密码文件**:
```bash
touch ~/.pgpass
```

2. **编辑文件内容** (格式: `hostname:port:database:username:password`):
```
localhost:5432:onehub_db:onehub_user:YourS3cretPa$$w0rd
```

3. **设置权限** (关键!):
```bash
chmod 600 ~/.pgpass
```

**定时任务配置**:
```bash
# 编辑 crontab
crontab -e

# 每天凌晨 2:30 执行备份
30 2 * * * /opt/one-hub/backup_postgres.sh > /dev/null 2>&1
```

**输出文件**:
```
/var/backups/postgresql/
├── onehub_db_20251213_023000.dump   # 备份文件(自定义格式)
├── onehub_db_20251212_023000.dump
└── backup_log.txt                    # 执行日志
```

**日志格式**:
```
2025-12-13 02:30:00 - ================== 开始备份任务 ==================
2025-12-13 02:30:00 - 备份目录检查通过: /var/backups/postgresql
2025-12-13 02:30:00 - pg_dump 命令检查通过: /usr/lib/postgresql/17/bin/pg_dump
2025-12-13 02:30:00 - 准备执行备份，数据库: onehub_db
2025-12-13 02:30:05 - 备份成功！文件大小: 125M
2025-12-13 02:30:05 - 开始清理 7 天前的旧备份...
2025-12-13 02:30:05 - 没有找到需要清理的旧备份文件。
2025-12-13 02:30:05 - ================== 备份任务结束 (成功) ==================
```

**恢复备份**:
```bash
# 使用 pg_restore 恢复
pg_restore -U onehub_user -h localhost -d onehub_db /var/backups/postgresql/onehub_db_20251213_023000.dump

# 或者恢复到新数据库
createdb -U postgres new_onehub_db
pg_restore -U onehub_user -h localhost -d new_onehub_db /var/backups/postgresql/onehub_db_20251213_023000.dump
```

---

### network-reinstall-os.sh

**功能概述**:
- VPS 系统网络重装工具
- 支持多种 Linux 发行版
- 自动检测当前网络配置

**支持的系统**:
| 序号 | 系统 | 版本 | 内存要求 |
|-----|------|------|---------|
| 1 | Debian | 11 (Bullseye) | 512M+ |
| 2 | Debian | 12 (Bookworm) | 1G+ |
| 3 | Ubuntu | 20.04 LTS | 2G+ |
| 4-6 | Fedora | 37/38/39 | 2G+ |
| 7-8 | RockyLinux | 8/9 | 2G+ |
| 9-10 | AlmaLinux | 8/9 | 2G+ |

**默认凭据**:
- 用户名: `root`
- 密码: `IdcOffer.com`

**注意事项**:
- 执行后会重装系统,**所有数据将丢失**
- 确保有 VNC 或 IPMI 等紧急访问方式
- 建议先备份重要数据

---

### 10-ipset (netfilter-persistent 插件)

**功能概述**:
- 作为 `netfilter-persistent` 的插件
- 在系统启动时自动加载 IPSet 规则
- 支持保存、加载、刷新操作

**安装方法**:
```bash
# 复制到插件目录
cp 10-ipset /usr/share/netfilter-persistent/plugins.d/
chmod +x /usr/share/netfilter-persistent/plugins.d/10-ipset
```

**规则文件**: `/etc/iptables/rules.ipset`

**支持的操作**:
| 命令 | 功能 |
|-----|------|
| `start` | 加载 IPSet 规则 |
| `restart` | 重新加载规则 |
| `reload` | 重新加载规则 |
| `save` | 保存当前规则到文件 |
| `flush` | 清空所有 IPSet |

**使用方法**:
```bash
# 通过 netfilter-persistent 调用
netfilter-persistent save
netfilter-persistent reload

# 直接调用
/usr/share/netfilter-persistent/plugins.d/10-ipset start
```

---

### ssh_key.sh

**功能概述**:
- 一键添加 SSH 公钥到 `authorized_keys`
- 自动创建 `.ssh` 目录并设置正确权限

**执行效果**:
- 创建 `~/.ssh/` 目录 (权限 700)
- 创建/追加 `~/.ssh/authorized_keys` (权限 600)
- 添加预设的 SSH 公钥

---

### ChangeMirrors.sh

**功能概述**:
- 一键切换 Linux 软件源镜像
- 支持多种发行版和镜像源

**支持的发行版**:
- Debian/Ubuntu
- CentOS/RHEL
- Fedora
- Alpine

**镜像源选项**:
- 阿里云
- 腾讯云
- 华为云
- 清华大学
- 中科大
- 官方源

---

## 关键依赖与配置

### 系统依赖
| 脚本 | 依赖 |
|-----|------|
| `backup_postgres.sh` | pg_dump, cron |
| `network-reinstall-os.sh` | wget, curl |
| `10-ipset` | ipset, netfilter-persistent |
| `ChangeMirrors.sh` | curl, wget |

### 配置文件
| 文件路径 | 用途 |
|---------|------|
| `~/.pgpass` | PostgreSQL 免密配置 |
| `/etc/iptables/rules.ipset` | IPSet 规则存储 |
| `/etc/apt/sources.list` | Debian/Ubuntu 软件源 |
| `/etc/yum.repos.d/` | CentOS/RHEL 软件源 |

---

## 数据模型

### .pgpass 文件格式
```
hostname:port:database:username:password
# 示例:
localhost:5432:mydb:myuser:mypassword
*:5432:*:backup_user:backup_password
```

### IPSet 规则格式
```
create blocked_ips hash:ip family inet hashsize 4096 maxelem 65536
add blocked_ips 192.168.1.100
add blocked_ips 10.0.0.50
```

---

## 测试与质量

### 已测试环境
- Debian 11/12
- Ubuntu 20.04/22.04
- CentOS 7/8
- PostgreSQL 14/15/16/17

### 错误处理
- `backup_postgres.sh`:
  - 检查备份目录是否存在
  - 验证 pg_dump 命令可执行
  - 备份失败时删除不完整文件
- `10-ipset`:
  - 规则文件不存在时跳过加载
  - 加载失败时返回错误码

---

## 常见问题 (FAQ)

**Q: backup_postgres.sh 报错 "pg_dump 命令不存在"?**
A: 检查 `PG_DUMP_PATH` 路径是否正确:
```bash
# 查找 pg_dump 位置
find / -name pg_dump 2>/dev/null
# 或
which pg_dump
```

**Q: .pgpass 文件配置正确但仍提示输入密码?**
A: 确保:
1. 文件权限为 600: `chmod 600 ~/.pgpass`
2. 文件所有者正确: `chown $(whoami) ~/.pgpass`
3. 主机名与连接时一致(localhost vs 127.0.0.1)

**Q: 网络重装系统后无法连接?**
A:
1. 使用 VNC/IPMI 检查系统状态
2. 默认密码: `IdcOffer.com`
3. 确保网络配置正确(IP/网关/掩码)

**Q: IPSet 规则重启后丢失?**
A: 确保:
1. `10-ipset` 插件已正确安装
2. 执行 `netfilter-persistent save` 保存规则
3. `netfilter-persistent` 服务已启用

**Q: 如何查看 pg_dump 支持的 PostgreSQL 版本?**
A:
```bash
pg_dump --version
# 输出示例: pg_dump (PostgreSQL) 17.0
```

---

## 相关文件清单

```
Sh/utils/
├── backup_postgres.sh                  # PostgreSQL 自动备份 (142行) ⭐
├── ssh_key.sh                          # SSH 密钥配置
├── ChangeMirrors.sh                    # 软件源切换
├── network-reinstall-os.sh             # VPS 系统重装
├── Network-Reinstall-System-Modify.sh  # 系统重装(修改版)
├── 10-ipset                            # IPSet 持久化插件
├── install_ipset.sh                    # 安装 IPSet 持久化
├── uninstall_ipset.sh                  # 卸载 IPSet 持久化
├── QLOneKeyDependency.sh               # 青龙面板依赖
├── install-system-information.sh       # 系统信息工具
└── CLAUDE.md                           # 本文档
```

**关键文件**:
- `backup_postgres.sh`: 数据库备份核心脚本,包含完整的日志和清理逻辑
- `10-ipset`: netfilter-persistent 插件,实现 IPSet 规则持久化

---

## 相关模块

- [Sh/system](../system/CLAUDE.md): 系统优化工具
- [Sh/docker](../docker/CLAUDE.md): Docker 安装与证书管理
- [Sh/network](../network/CLAUDE.md): 网络代理与防火墙工具

---

**维护者**: Silentely
**最后更新**: 2025-12-13
