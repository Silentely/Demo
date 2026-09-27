[根目录](../../CLAUDE.md) > [Sh](../) > **network**

---

# Sh/network - 网络配置与代理工具

> **模块职责**: 提供网络代理部署、防火墙配置、IP 封锁、系统重装等网络相关工具

---

## 📋 变更记录 (Changelog)

### 2026-09-27
- **`install_ufw_cloudflare.sh` 端口自适应防失联升级**:
  - 动态检测系统实际运行或配置的 SSH 端口（扫描 `sshd_config.d`、`sshd_config` 及 `ss -tlpn`），同时放行自定义端口与默认 22 端口，彻底解决修改 SSH 端口后运行防火墙导致服务器永久失联的重大事故。
  - 新增 `-y/--yes` 命令行参数支持静默无交互执行。
- **`block-ips.sh` 极速载入与健壮性升级**:
  - 重构逐行 `ipset -A` 为管道化 `ipset restore` 批量导入，万级别 CIDR 规则导入耗时由数分钟缩减至 0.1 秒。
  - 强制走 HTTPS 下载源并支持 curl/wget 互为降级。
  - 增加 iptables 规则重复检测与终端管道输入支持。
- **`socks5_install.sh` 跨发行版增强**:
  - 新增对现代 Linux 衍生版（Rocky/AlmaLinux/Kali/Pop!_OS/Armbian）的自动识别与依赖安装。
  - 增加远程与本地互备获取机制。
- **`gost.sh` 现代化与稳定性升级**:
  - 弃用传统的 SysVinit 脚本与被墙的 GitHub Gist 外部依赖，全面改用标准 systemd 服务托管（`/etc/systemd/system/gost.service`）。
  - 内置稳定版本兜底与快速本地配置生成。
- **`all_http_socks5.sh` & `http_install.sh` 死链修复与认证强化**:
  - 修复远程脚本下载 404 错误路径（修正为 `Sh/network/socks5_install.sh`），优先调用本地脚本。
  - 弃用下载外部固定 `passwd` 文件的风险行为，直接通过 `apache2-utils` 本地动态安全生成认证账号密码。

### 2025-12-13
- 初始化模块文档
- 完成脚本清单与接口说明

---

## 🎯 模块职责

本模块包含网络配置与管理工具,涵盖:
- 多种代理服务器部署 (Gost/Squid HTTP/Dante SOCKS5)
- 防火墙规则配置 (UFW + Cloudflare CDN IP 白名单，带 SSH 自适应保护)
- IP 地址封锁工具 (基于 ipset restore 极速导入)
- 网络系统重装工具

---

## 🚪 入口与启动

### 主要脚本入口

| 脚本名 | 功能 | 使用频率 | 执行方式 |
|-------|------|---------|---------|
| `install_ufw_cloudflare.sh` | UFW + Cloudflare IP 白名单 (SSH 自适应防失联) | ★★★★★ | `bash install_ufw_cloudflare.sh [-y]` |
| `gost.sh` | Gost 代理服务器安装 (systemd 托管) | ★★★★☆ | `bash gost.sh` |
| `all_http_socks5.sh` | HTTP + SOCKS5 一键部署 (本地动态认证) | ★★★★☆ | `bash all_http_socks5.sh` |
| `http_install.sh` | Squid HTTP 代理安装 | ★★★☆☆ | `bash http_install.sh` |
| `socks5_install.sh` | Dante SOCKS5 代理安装 (多发行版适配) | ★★★☆☆ | `bash socks5_install.sh [--port=] [--user=] [--passwd=]` |
| `block-ips.sh` | 国家 IP 封禁工具 (ipset restore 极速版) | ★★★☆☆ | `bash block-ips.sh` |
| `dd-od.sh` | 系统网络重装神器 | ★★★☆☆ | `bash dd-od.sh` |

---

## 🔌 重点脚本说明

### install_ufw_cloudflare.sh (防失联加固版)
**功能**:
- 自动安装并配置 UFW 防火墙。
- **端口自适应安全探测**: 动态检测当前正在监听的所有 SSH 端口并自动放行，杜绝修改非标端口后的失联风险。
- 从官方实时获取最新的 Cloudflare IPv4 和 IPv6 地址段，仅允许其访问 80/443。
- 设置 UFW 默认入站规则为 `deny`。

### gost.sh (systemd 托管版)
**功能**:
- 自动检测主机架构并拉取适配的 Gost 二进制文件。
- 使用现代 systemd 服务文件 `/etc/systemd/system/gost.service` 托管，支持开机自启、崩溃自动重启。
- 支持 HTTP/HTTPS/SOCKS5 转发与链式代理配置。

### all_http_socks5.sh
**功能**:
- 自动安装配置 Squid (HTTP 代理, 默认端口 25562) 与 Dante (SOCKS5 代理, 默认端口 25543)。
- 使用 `htpasswd` 本地动态初始化认证文件，安全可靠。

---

## 📁 相关文件清单

```
Sh/network/
├── install_ufw_cloudflare.sh    # UFW + Cloudflare 白名单 (SSH 防失联) ⭐
├── gost.sh                      # Gost 代理安装与配置 (systemd) ⭐
├── all_http_socks5.sh           # HTTP+SOCKS5 一键部署 ⭐
├── http_install.sh              # Squid HTTP 代理
├── socks5_install.sh            # Dante SOCKS5 代理 (全系统适配)
├── block-ips.sh                 # 国家 IP 封禁 (ipset restore 极速版) ⭐
├── dd-od.sh                     # 系统网络重装
└── CLAUDE.md                    # 本文档
```

---

**维护者**: Silentely
**最后更新**: 2026-09-27
