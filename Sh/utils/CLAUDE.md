[根目录](../../CLAUDE.md) > [Sh](../) > **utils**

---

# Sh/utils - 通用工具脚本

> **模块职责**: 提供 SSH 密钥加固管理、镜像源切换、数据库备份、系统重装等通用运维工具

---

## 变更记录 (Changelog)

### 2026-09-27
- **`ssh_key.sh` 核心加固与全面重构**:
  - **Drop-in 优先策略**: 采用 `/etc/ssh/sshd_config.d/00-security.conf`，利用 OpenSSH 规则“首个匹配值生效”特性，彻底解决 `50-cloud-init.conf` 和 `99-*.conf` 等厂商镜像配置覆盖 `PasswordAuthentication no` 的重大安全缺陷。
  - **Ubuntu 24.04+ `ssh.socket` 机制适配**: 新增 `handle_ubuntu_socket_activation`，检测到 socket 激活时平滑切换为守护进程 `ssh.service`，彻底解决改端口后新端口无法监听的失联重大隐患。
  - **命令行 CLI 参数支持**: 新增 `-a/--author`、`-k/--key`、`-p/--port`、`-h/--help` 参数，支持全自动非交互式部署；`-h` 无需 root 权限直接展示说明。
  - **安全与鲁棒性增强**: 增加 `exec < /dev/tty` 支持管道安全调用，增强公钥格式清洗，支持自动备份轮转（保留最近 5 份）并在语法测试失败时毫秒级自动回滚。
- **`backup_postgres.sh` 探测自适应**:
  - 动态检测 `pg_dump`，支持用户环境变量覆盖、系统 PATH 检测以及 `/usr/lib/postgresql/*/bin/pg_dump` 自动选取最高可用版本，适配 PG 12-17+。
- **`QLOneKeyDependency.sh` 现代系统适配**:
  - 修复终端输出语法错误，增加 `--break-system-packages`，适配 Python 3.12+ (PEP 668) 与 Alpine 3.19+ 现代青龙环境。
- **`install_ipset.sh` 本地离线优先与网络容错**:
  - 优先检测并复制仓库内置的 `Sh/utils/10-ipset` 插件，解决受限 VPS 上 raw.githubusercontent.com 443 超时问题，并提供 curl/wget 互备容错与 `-y` 免确认。
- **`install-system-information.sh` 官方仓库迁移**:
  - 将 Fastfetch 上游仓库名修正为官方独立组织 `fastfetch-cli/fastfetch`，追加 `apt-get install -f -y` 修复潜在未满足的共享库依赖。

### 2025-12-13
- 初始化模块文档
- 完成 backup_postgres.sh 配置说明
- 添加所有脚本的接口文档

---

## 模块职责

本模块包含通用系统运维工具:
- SSH 密钥一键配置与安全加固 (防配置覆盖/防改端口失联/多参数支持)
- Linux 软件源镜像切换
- PostgreSQL 数据库自动备份与自适应探测
- VPS 系统网络重装
- IPSet 防火墙规则管理 (本地优先、持久化保护)
- 青龙面板依赖安装 (适配 PEP 668)
- 终端登录系统信息展示工具 (Neofetch / Fastfetch)

---

## 入口与启动

### 主要脚本入口

| 脚本名 | 功能 | 复杂度 | 执行方式 |
|-------|------|--------|---------|
| `ssh_key.sh` | SSH 密钥一键加固配置 (支持 CLI 参数) | 高 (780行) | `bash ssh_key.sh [选项]` |
| `ChangeMirrors.sh` | Linux 软件源切换 | 中 | `bash ChangeMirrors.sh` |
| `backup_postgres.sh` | PostgreSQL 自动备份 (自适应路径) | 中 (130行) | `bash backup_postgres.sh` |
| `network-reinstall-os.sh` | VPS 系统网络重装 | 中 | `bash network-reinstall-os.sh` |
| `install_ipset.sh` | 安装 IPSet 持久化 (本地优先版) | 低 | `bash install_ipset.sh [-y]` |
| `uninstall_ipset.sh` | 卸载 IPSet 持久化 | 低 | `bash uninstall_ipset.sh [-y]` |
| `10-ipset` | IPSet netfilter 插件 | 低 | 放入 `/usr/share/netfilter-persistent/plugins.d/` |
| `QLOneKeyDependency.sh` | 青龙面板依赖安装 | 中 | `bash QLOneKeyDependency.sh` |
| `install-system-information.sh` | 系统信息工具安装 (Fastfetch 现代版) | 低 | `bash install-system-information.sh` |
| `Network-Reinstall-System-Modify.sh` | 网络重装系统(修改版) | 高 | `bash Network-Reinstall-System-Modify.sh` |

### 远程执行示例
```bash
# SSH 密钥交互式配置
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/utils/ssh_key.sh)

# SSH 密钥非交互式配置 (指定 GitHub 开发者公钥并禁用密码)
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/utils/ssh_key.sh) -a Silentely

# SSH 自定义端口与非交互式加固
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/utils/ssh_key.sh) -p 2222 -a Silentely

# 软件源切换
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/utils/ChangeMirrors.sh)
```

---

## 重点脚本与对外接口

### ssh_key.sh (核心加固脚本)

**功能概述**:
- 快速注入 GitHub 用户公钥或自定义公钥到目标用户 `authorized_keys`。
- 禁用密码登录（PasswordAuthentication no）与允许/禁止 root 登录。
- 自定义修改 SSH 服务监听端口，并自动联动 UFW/Firewalld/SELinux 放行。
- **安全防覆盖**: 优先使用 `/etc/ssh/sshd_config.d/00-security.conf` 字典序首位 drop-in 配置，免疫云服务商自带的覆盖。
- **Ubuntu 24.04 守护升级**: 解决 `ssh.socket` 导致的改端口失效与失联问题。
- **自动备份与回滚**: 在配置生效前调用 `sshd -t` 深度检查，报错时自动使用备份文件立即回滚，且自动维持最近 5 份备份轮转。

**CLI 命令行参数**:
```bash
用法: ssh_key.sh [选项]

选项:
  -a, --author <username>  拉取指定 GitHub 用户的公钥并追加
  -k, --key "<pubkey>"     直接追加指定的公钥字符串
  -p, --port <port>        修改 SSH 监听端口 (1-65535)
  -h, --help               显示帮助信息并退出 (无需 root 权限)
```

---

### backup_postgres.sh

**功能概述**:
- 自动智能检测系统可用 `pg_dump`，无需手动写死版本路径；支持 PostgreSQL 12-17+。
- 支持直接通过环境变量指定数据库连接与备份参数，方便集成到自动化脚本与 Cron 中。
- 使用安全的 `.pgpass` 凭证机制，支持历史备份天数按需轮转清理与错误自清理。

**环境变量配置项**:
```bash
export DB_USER="onehub_user"
export DB_NAME="onehub_db"
export DB_HOST="localhost"
export DB_PORT="5432"
export BACKUP_DIR="/var/backups/postgresql"
export RETENTION_DAYS="7"
bash backup_postgres.sh
```

---

## 相关文件清单

```
Sh/utils/
├── backup_postgres.sh                  # PostgreSQL 自动备份 (自适应探测) ⭐
├── ssh_key.sh                          # SSH 密钥加固与端口管理 ⭐
├── ChangeMirrors.sh                    # 软件源切换
├── network-reinstall-os.sh             # VPS 系统网络重装
├── Network-Reinstall-System-Modify.sh  # 系统重装(修改版)
├── 10-ipset                            # IPSet 持久化插件
├── install_ipset.sh                    # 安装 IPSet 持久化 (本地优先)
├── uninstall_ipset.sh                  # 卸载 IPSet 持久化
├── QLOneKeyDependency.sh               # 青龙面板依赖 (PEP 668 适配)
├── install-system-information.sh       # 系统信息工具 (Fastfetch 官方组织)
└── CLAUDE.md                           # 本文档
```

---

**维护者**: Silentely
**最后更新**: 2026-09-27
