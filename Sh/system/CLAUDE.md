[根目录](../../CLAUDE.md) > [Sh](../) > **system**

---

# Sh/system - 系统相关工具脚本

> **模块职责**: 提供系统优化、清理、配置、美化等维护工具

---

## 📋 变更记录 (Changelog)

### 2025-12-13
- 初始化模块文档
- 完成脚本清单与接口说明

---

## 🎯 模块职责

本模块包含系统级维护工具,涵盖:
- 系统垃圾清理与磁盘空间释放
- 终端环境优化与美化
- 语言环境配置(简体中文)
- Swap 分区管理
- Snap 包清理
- NAT64/DNS64 自动优选

---

## 🚪 入口与启动

### 主要脚本入口

| 脚本名 | 功能 | 使用频率 | 执行方式 |
|-------|------|---------|---------|
| `cleanup.sh` | 系统垃圾清理加速器 | ★★★★☆ | `bash cleanup.sh` 或远程执行 |
| `terminal_optimizer.sh` | 终端优化美化工具 | ★★★★☆ | `bash terminal_optimizer.sh [-u/-f]` |
| `LocaleCN.sh` | 简体中文环境设置 | ★★★★★ | `bash LocaleCN.sh [-f]` |
| `swap.sh` | Swap 分区管理工具 | ★★★☆☆ | `bash swap.sh` |
| `clean_snap.sh` | Snap 包清理工具 | ★☆☆☆☆ | `bash clean_snap.sh` |
| `nat64_optimizer.sh` | NAT64/DNS64 自动优选 | ★★★★★ | `bash nat64_optimizer.sh [-a/-c/-t]` |

### 远程执行示例
```bash
# 系统清理
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/system/cleanup.sh)

# NAT64 优选
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/system/nat64_optimizer.sh)
```

---

## 🔌 对外接口

### cleanup.sh
**参数**:
- `-h, --help`: 显示帮助信息
- `-v, --verbose`: 详细输出模式
- `-y, --yes`: 自动确认所有操作

**输出**: 清理前后磁盘使用情况对比,释放的空间大小

**清理项**:
- APT 缓存 (`/var/cache/apt/archives`)
- 日志文件 (`/var/log`)
- 临时文件 (`/tmp`)
- 旧的内核包(如适用)

---

### terminal_optimizer.sh
**参数**:
- `-h, --help`: 显示帮助信息
- `-v, --version`: 显示脚本版本
- `-u, --uninstall`: 恢复到原始配置
- `-f, --force`: 强制执行,不进行确认提示

**功能**:
- 炫酷 PS1 提示符配置
- Git 分支显示集成
- 常用别名配置 (如 `ll`, `la`, `grep --color=auto`)
- 历史命令增强 (时间戳、去重)

**备份文件**: `~/.bashrc.backup.YYYYMMDD_HHMMSS`

---

### LocaleCN.sh
**参数**:
- `-h, --help`: 显示帮助信息
- `-f, --force`: 强制执行,不进行确认提示

**功能**:
- 一键设置系统全局语言为简体中文 (`zh_CN.UTF-8`)
- 自动安装中文语言包
- 支持 CentOS/Debian/Ubuntu/Alpine 等发行版
- 自动备份原有语言配置

**注意事项**: 修改后需重启或重新登录生效

---

### nat64_optimizer.sh (核心脚本)
**参数**:
- `-a, --auto-apply`: 自动应用最佳 DNS64,无需交互
- `-c, --count <N>`: 每台服务器发送的 ping 次数(默认:4)
- `-t, --timeout <sec>`: ping 命令整体超时秒数(默认:5)
- `-h, --help`: 查看帮助

**环境变量**:
- `PING_COUNT`: 同 `--count`,优先级低于命令行
- `PING_TIMEOUT`: 同 `--timeout`,优先级低于命令行
- `CURL_MAX_TIME`: 网络请求的超时秒数(默认:15)

**功能流程**:
1. 检查当前 NAT64 状态(DNS 服务器、IPv6 连接、NAT64 前缀)
2. 从多个数据源获取候选服务器列表:
   - nat64.xyz (GitHub)
   - nat64.net (HTML 解析)
   - 静态公开列表(内置)
3. 智能测速(支持 ICMP ping、TCP53、DNS query 三种方式)
4. 展示测速结果表格(前 6 名)
5. 交互式确认或自动应用最佳 DNS64
6. 自动配置 `/etc/resolv.conf` 和 `systemd-resolved`

**关键逻辑**:
- 多数据源容错机制(失败后使用内置 fallback 列表)
- 智能去重(按 DNS64 地址去重)
- 多探测方式自动切换(优先 ICMP,其次 TCP53,最后 DNS query)
- 配置备份与回滚支持

---

## 🔗 关键依赖与配置

### 系统依赖
- **必需**: curl, awk, grep, ping/ping6
- **可选**: dig/drill (NAT64 前缀检测), python3 (TCP53 探测)

### 配置文件
- `/etc/resolv.conf`: DNS 配置(NAT64 脚本会修改)
- `/etc/systemd/resolved.conf`: systemd-resolved 配置
- `~/.bashrc`: 终端配置(终端优化脚本会修改)

### 外部资源
NAT64 脚本依赖的数据源:
- https://raw.githubusercontent.com/level66network/nat64.xyz/refs/heads/main/content/_index.md
- https://nat64.net/public-providers

---

## 📦 数据模型

### NAT64 服务器记录格式
```bash
provider|location|dns64|prefix|source
# 示例:
nat64.net|Amsterdam|2a00:1098:2b::1|2a00:1098:2b::/96|nat64.xyz
```

### 测速结果格式
```bash
provider|location|dns64|prefix|source|latency
# 示例:
nat64.net|Amsterdam|2a00:1098:2b::1|2a00:1098:2b::/96|nat64.xyz|12
```

---

## 🧪 测试与质量

### 手动测试
所有脚本已在以下环境测试:
- Debian 11/12
- Ubuntu 20.04/22.04
- CentOS 7/8
- Alpine Linux

### 错误处理
- NAT64 脚本: `set -euo pipefail`,严格错误检查
- 其他脚本: 显式依赖检查,操作前确认提示

### 日志级别
- `log_info`: 正常信息(绿色)
- `log_warn`: 警告信息(黄色)
- `log_error`: 错误信息(红色)
- `log_debug`: 调试信息(紫色,NAT64 脚本)

---

## ❓ 常见问题 (FAQ)

**Q: NAT64 脚本报 "缺少依赖" 错误?**
A: 确保已安装 `curl` 和 `awk`,对于完整功能,建议安装 `dig`/`drill` 和 `python3`。

**Q: 终端优化脚本修改后无效?**
A: 执行 `source ~/.bashrc` 或重新登录终端。

**Q: 系统清理脚本会删除重要文件吗?**
A: 不会。脚本只清理标准缓存目录,不会删除用户数据或系统关键文件。

**Q: NAT64 脚本测速很慢?**
A: 可以减少 ping 次数或超时时间,例如: `bash nat64_optimizer.sh -c 2 -t 3`

**Q: Locale 脚本修改后系统仍然是英文?**
A: 确保重启或重新登录,部分应用可能需要手动配置语言。

---

## 📂 相关文件清单

```
Sh/system/
├── cleanup.sh                  # 系统垃圾清理
├── terminal_optimizer.sh       # 终端优化美化
├── LocaleCN.sh                 # 简体中文环境设置
├── swap.sh                     # Swap 分区管理
├── clean_snap.sh               # Snap 包清理
└── nat64_optimizer.sh          # NAT64/DNS64 自动优选 (最复杂)
```

**关键文件**:
- `nat64_optimizer.sh` (827 行): 功能最复杂,包含多数据源抓取、智能测速、DNS 配置逻辑
- `cleanup.sh`: 系统清理核心逻辑,包含多发行版兼容处理
- `terminal_optimizer.sh`: 终端配置模板生成

---

## 🔍 相关模块

- [Sh/utils](../utils/CLAUDE.md): 通用工具脚本(SSH 密钥、镜像源切换等)
- [lib](../../lib/CLAUDE.md): 公共函数库(`common.sh`)

---

**维护者**: Silentely
**最后更新**: 2025-12-13
