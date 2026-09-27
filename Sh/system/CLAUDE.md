[根目录](../../CLAUDE.md) > [Sh](../) > **system**

---

# Sh/system - 系统相关工具脚本

> **模块职责**: 提供系统深度优化、清理加速、环境配置、美化及存储调优工具

---

## 📋 变更记录 (Changelog)

### 2026-09-27
- **`cleanup.sh` 现代化深度清理升级**:
  - 新增现代 Linux 核心日志占用大户 `systemd-journald` 深度清理（`journalctl --vacuum-time=2d --vacuum-size=50M`）。
  - 新增全发行版包缓存与无用依赖深度清理：Debian/Ubuntu (`apt clean/autoremove/dpkg --purge`)、RHEL/CentOS/Rocky/Alma/Fedora (`dnf/yum clean all/autoremove`)、Arch (`pacman -Sc`)、Alpine (`apk cache clean`)。
  - 修复全局变量输出时机导致的未格式化乱码与提示覆盖，统计展示实际释放空间。
- **`swap.sh` 文件系统兼容性与稳定性增强**:
  - 采用 `fallocate` 极速分配与 `dd` 块写入智能 fallback 机制，彻底规避 XFS、Btrfs 及精简卷上 `swapon: file has holes / Invalid argument` 错误。
  - 支持 `sysctl vm.swappiness=60` 自动调优写入，前置 `-h/--help` 参数无 root 限制。
- **`clean_snap.sh` 安全卸载优化**:
  - 移除盲目 `snap stop` 杀死所有正在运行应用的破坏性操作，仅精准定位并卸载已禁用的旧 revision 包，实现线上零中断运维。
- **`terminal_optimizer.sh` 自动化与管道增强**:
  - 修复传递 `-u/--uninstall` 或 `-f/--force` 参数时依旧弹出交互式菜单阻塞自动化执行的问题。
  - 增加管道输入重定向，支持 `bash <(curl ...)` 远程调用。

### 2025-12-13
- 初始化模块文档
- 完成脚本清单与接口说明

---

## 🎯 模块职责

本模块包含系统级维护工具,涵盖:
- 系统垃圾清理与磁盘空间深度释放 (全发行版包缓存、journald、日志轮转)
- 终端环境优化与美化 (支持全自动参数)
- 语言环境配置 (简体中文)
- Swap 交换分区安全管理 (兼容 XFS/Btrfs)
- Snap 历史包零中断安全清理
- NAT64/DNS64 智能多源选优与配置

---

## 🚪 入口与启动

### 主要脚本入口

| 脚本名 | 功能 | 使用频率 | 执行方式 |
|-------|------|---------|---------|
| `cleanup.sh` | 系统垃圾清理加速器 (全平台+journald) | ★★★★★ | `bash cleanup.sh [-y]` |
| `swap.sh` | Swap 分区管理工具 (含 Btrfs/XFS 兼容) | ★★★★☆ | `bash swap.sh` |
| `clean_snap.sh` | Snap 历史包安全清理 (零中断) | ★★★☆☆ | `bash clean_snap.sh` |
| `nat64_optimizer.sh` | NAT64/DNS64 自动优选 (核心测速) | ★★★★★ | `bash nat64_optimizer.sh [-a/-c/-t]` |
| `terminal_optimizer.sh` | 终端优化美化工具 (支持自动化) | ★★★★☆ | `bash terminal_optimizer.sh [-u/-f]` |
| `LocaleCN.sh` | 简体中文环境设置 | ★★★★☆ | `bash LocaleCN.sh [-f]` |

---

## 📁 相关文件清单

```
Sh/system/
├── cleanup.sh                  # 系统垃圾清理加速器 ⭐
├── swap.sh                     # Swap 分区管理 (含 dd fallback) ⭐
├── clean_snap.sh               # Snap 历史禁用包清理 ⭐
├── nat64_optimizer.sh          # NAT64/DNS64 自动优选 (827行) ⭐
├── terminal_optimizer.sh       # 终端美化与别名增强 (支持自动化)
├── LocaleCN.sh                 # 简体中文环境一键配置
└── CLAUDE.md                   # 本文档
```

---

**维护者**: Silentely
**最后更新**: 2026-09-27
