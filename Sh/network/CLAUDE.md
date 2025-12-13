[根目录](../../CLAUDE.md) > [Sh](../) > **network**

---

# Sh/network - 网络配置与代理工具

> **模块职责**: 提供网络代理部署、防火墙配置、IP 封锁、系统重装等网络相关工具

---

## 📋 变更记录 (Changelog)

### 2025-12-13
- 初始化模块文档
- 完成脚本清单与接口说明

---

## 🎯 模块职责

本模块包含网络配置与管理工具,涵盖:
- 多种代理服务器部署(Gost/HTTP/SOCKS5)
- 防火墙规则配置(UFW + Cloudflare)
- IP 地址封锁工具
- 网络系统重装工具

---

## 🚪 入口与启动

### 主要脚本入口

| 脚本名 | 功能 | 使用频率 | 执行方式 |
|-------|------|---------|---------|
| `gost.sh` | Gost 代理服务器安装 | ★★☆☆☆ | `bash gost.sh` |
| `http_install.sh` | Squid HTTP 代理安装 | ★★☆☆☆ | `bash http_install.sh` |
| `socks5_install.sh` | Dante SOCKS5 代理安装 | ★★☆☆☆ | `bash socks5_install.sh [--port=] [--user=] [--passwd=]` |
| `all_http_socks5.sh` | HTTP + SOCKS5 一键部署 | ★★☆☆☆ | `bash all_http_socks5.sh` |
| `install_ufw_cloudflare.sh` | UFW + Cloudflare IP 白名单 | ★★☆☆☆ | `bash install_ufw_cloudflare.sh` |
| `block-ips.sh` | 国家 IP 封禁工具 | ★☆☆☆☆ | `bash block-ips.sh` |
| `dd-od.sh` | 系统网络重装神器 | ★★☆☆☆ | `bash dd-od.sh` |

---

## 🔌 对外接口

### gost.sh
**功能**: 自动检测系统架构,下载并安装最新版本的 Gost 代理服务器

**支持协议**:
- HTTP/HTTPS
- SOCKS4/SOCKS5
- SS (Shadowsocks)
- SSR (ShadowsocksR)

**输出**: Gost 二进制文件安装路径,配置建议

---

### http_install.sh
**功能**: 安装并配置 Squid HTTP 代理服务器

**默认端口**: 25562
**认证**: 支持用户名/密码认证
**配置文件**: `/etc/squid/squid.conf`

---

### socks5_install.sh
**参数**:
- `--port=<端口>`: 指定 SOCKS5 端口(默认:25543)
- `--user=<用户名>`: 指定认证用户名
- `--passwd=<密码>`: 指定认证密码
- `--no-github`: 使用备用下载源

**功能**: 安装 Dante SOCKS5 服务器,支持自定义端口和认证

**系统支持**: Debian/Ubuntu/CentOS

---

### all_http_socks5.sh
**功能**: 一键部署 HTTP(Squid) + SOCKS5(Dante) 双代理

**默认端口**:
- HTTP: 25562
- SOCKS5: 25543

**使用场景**: 需要同时提供 HTTP 和 SOCKS5 代理服务

---

### install_ufw_cloudflare.sh
**功能**:
- 自动安装 UFW 防火墙
- 获取最新 Cloudflare IPv4/IPv6 地址列表
- 仅允许 Cloudflare IP 访问 80/443 端口
- 自动开放 SSH(22)端口
- 默认拒绝其他入站连接

**使用场景**: 网站使用 Cloudflare CDN,防止直接攻击源站

**配置来源**:
- https://www.cloudflare.com/ips-v4
- https://www.cloudflare.com/ips-v6

---

### block-ips.sh
**功能**: 根据国家代码封禁整个国家的 IP 段

**功能选项**:
1. 封禁 IP - 输入国家代码(如 `cn`)
2. 解封 IP - 输入国家代码解除封禁
3. 查看封禁列表 - 显示当前所有封禁规则

**技术**: 使用 `ipset` 高效管理大量 IP 规则

**国家代码示例**:
- `cn` - 中国
- `us` - 美国
- `ru` - 俄罗斯

---

### dd-od.sh
**功能**: 通过网络一键重装各种 Linux/Windows 系统

**支持系统**:
- Debian/Ubuntu/CentOS 等主流 Linux 发行版
- Windows Server 2012/2016/2019

**注意事项**:
- ⚠️ 操作不可逆,会清空硬盘数据
- 需要 VPS/独立服务器环境
- 建议提前备份重要数据

---

## 🔗 关键依赖与配置

### 系统依赖
- **必需**: curl, wget, iptables/nftables
- **代理工具**: squid, dante-server, gost (脚本自动安装)
- **防火墙**: ufw, ipset

### 配置文件
- `/etc/squid/squid.conf`: Squid HTTP 代理配置
- `/etc/danted.conf`: Dante SOCKS5 配置
- `/etc/ufw/`: UFW 防火墙规则

### 网络端口
- 25562: HTTP 代理(Squid)
- 25543: SOCKS5 代理(Dante)
- 22: SSH(默认保持开放)
- 80/443: HTTP/HTTPS(Cloudflare 白名单)

---

## 🧪 测试与质量

### 手动测试
- 代理功能: 使用 `curl -x` 测试代理连通性
- 防火墙规则: 使用 `ufw status verbose` 检查规则
- IP 封禁: 使用 `ipset list` 查看封禁列表

### 测试命令示例
```bash
# 测试 HTTP 代理
curl -x http://username:password@server_ip:25562 https://ifconfig.me

# 测试 SOCKS5 代理
curl --socks5 username:password@server_ip:25543 https://ifconfig.me

# 检查 UFW 规则
sudo ufw status numbered
```

---

## ❓ 常见问题 (FAQ)

**Q: Gost 安装后无法启动?**
A: 检查防火墙是否开放对应端口,查看 systemd 日志: `journalctl -u gost -f`

**Q: Squid 代理无法连接?**
A: 确认 `/etc/squid/squid.conf` 中的 ACL 规则,检查防火墙是否允许 25562 端口。

**Q: SOCKS5 认证失败?**
A: 检查 `/etc/danted.conf` 中的用户配置,确保用户名密码正确。

**Q: UFW Cloudflare 规则更新频率?**
A: 脚本执行时一次性获取并配置,建议定期重新运行脚本更新 IP 列表。

**Q: block-ips.sh 封禁后无法解封?**
A: 确保使用相同的国家代码执行解封操作,或手动删除 ipset: `ipset destroy <setname>`

---

## 📂 相关文件清单

```
Sh/network/
├── gost.sh                      # Gost 代理安装
├── http_install.sh              # Squid HTTP 代理
├── socks5_install.sh            # Dante SOCKS5 代理
├── all_http_socks5.sh           # HTTP+SOCKS5 一键部署
├── install_ufw_cloudflare.sh    # UFW + Cloudflare 白名单
├── block-ips.sh                 # 国家 IP 封禁
└── dd-od.sh                     # 系统网络重装
```

---

## 🔍 相关模块

- [Sh/system](../system/CLAUDE.md): 系统相关工具脚本
- [Sh/utils](../utils/CLAUDE.md): 通用工具脚本

---

**维护者**: Silentely
**最后更新**: 2025-12-13
