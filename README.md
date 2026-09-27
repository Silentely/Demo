# 🚀 Demo 

*日常工具箱 - by Silentely*

<p align="center">
  <img src="https://img.shields.io/badge/维护状态-佛系-orange?style=for-the-badge&logo=buddhism" alt="佛系维护">
  <img src="https://img.shields.io/badge/用途-自用-blue?style=for-the-badge&logo=linux" alt="自用脚本">
  <img src="https://img.shields.io/badge/环境-Shell-brightgreen?style=for-the-badge&logo=gnubash" alt="Shell">
  <img src="https://img.shields.io/badge/Python-3.x-yellow?style=for-the-badge&logo=python" alt="Python">
</p>

<p align="center">
  <img src="https://img.shields.io/github/license/Silentely/Demo?style=flat-square" alt="License">
  <img src="https://img.shields.io/github/last-commit/Silentely/Demo?style=flat-square" alt="Last Commit">
  <img src="https://img.shields.io/github/stars/Silentely/Demo?style=flat-square" alt="Stars">
  <img src="https://img.shields.io/github/forks/Silentely/Demo?style=flat-square" alt="Forks">
</p>

> **🔧 纯自用，佛系维护，如果有任何问题，请自己解决 🔧**
> **🕙 最后更新: 2026-09-27**

---

## 📑 目录

- [项目结构](#-项目结构)
- [快速开始](#-快速开始)
- [Shell脚本使用说明](#-shell脚本使用说明)
  - [系统工具](#系统工具)
  - [网络工具](#网络工具)
  - [Docker工具](#docker工具)
  - [通用工具](#通用工具)
- [Cloudflare Workers](#-work目录---cloudflare-workers脚本)
- [Python脚本](#-python脚本)
- [题库转换工具](#-题库转换工具)
- [GitHub Actions](#-github-actions)
- [AI上下文文档](#-ai上下文文档)
- [文档](#-文档)
- [贡献](#-贡献)
- [License](#license)

---

## 📁 项目结构

```
Demo/
├── Sh/              # 主要的Shell脚本目录
│   ├── system/      # 系统相关脚本 (清理、优化、NAT64等)
│   ├── network/     # 网络相关脚本 (代理、防火墙等)
│   ├── docker/      # Docker相关脚本 (安装、证书)
│   └── utils/       # 通用工具脚本 (备份、SSH密钥加固等)
├── Action/          # GitHub Actions 工作流模板
├── Work/            # Cloudflare Workers 脚本
├── py/              # Python脚本
├── tiku/            # 题库格式转换工具
├── lib/             # 公共库文件
├── docs/            # 项目文档
├── CLAUDE.md        # AI上下文索引文档
├── LICENSE          # 许可证文件
└── README.md        # 项目说明文件
```

---

## 🚀 快速开始

选择您需要的脚本并直接运行：

```bash
# 示例：运行系统垃圾深度清理脚本
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/system/cleanup.sh)

# 示例：SSH 密钥加固一键配置 (支持指定 GitHub 用户公钥与自定义端口)
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/utils/ssh_key.sh) -a Silentely

# 示例：运行Docker安装脚本
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/docker/DockerInstallation.sh)
```

---

## 📚 Shell脚本使用说明

### 🔑 ssh_key.sh - SSH 密钥加固与端口管理
**脚本概述**: 
```
 ___ ___ _  _   _  _____   __
/ __/ __| || | | |/ / __| _\ \
\__ \__ \ __ | | ' <\__ \| | |
|___/___/_||_| |_|\_\___/ | |_|
                          \__/
```
**功能**: 
- 🛡️ **安全防覆盖**: 写入 `/etc/ssh/sshd_config.d/00-security.conf`，利用 OpenSSH 规则“首个出现值生效”特性，防止 VPS 云厂商自带配置覆盖 `PasswordAuthentication no`
- ⚡ **Ubuntu 24.04+ 完美适配**: 自动处理 `ssh.socket` 机制，改端口平滑过渡至守护进程服务，防止修改非标端口后无法监听失联
- 🔧 **支持 CLI 命令行选项**: 支持无交互快速注入公钥与调优
- 🔄 **自动安全回滚**: 修改前后语法检查，校验失败毫秒级自动还原，保留最近 5 份轮转备份

**使用方法**:
```bash
# 交互式菜单运行
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/utils/ssh_key.sh)

# 命令行一键非交互运行 (指定 GitHub 开发者用户名)
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/utils/ssh_key.sh) -a Silentely

# 指定端口与公钥
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/utils/ssh_key.sh) -p 2222 -a Silentely
```

**支持参数**:
- `-a, --author <username>` 拉取 GitHub 用户公钥并配置
- `-k, --key "<pubkey>"` 直接追加指定的公钥内容
- `-p, --port <port>` 修改 SSH 端口并自动放行防火墙
- `-h, --help` 显示帮助信息 (无需 root 权限)

---

### 🛡️ install_ufw_cloudflare.sh - UFW 防火墙 Cloudflare 白名单
**脚本概述**:
```
╔════════════════════════════════════╗
║  UFW + Cloudflare IP 白名单配置   ║
╚════════════════════════════════════╝
```
**功能**:
- 🔍 **SSH 端口自适应放行**: 动态探测当前实际运行及配置的所有 SSH 端口并自动放行，彻底消除改非标端口后被防火墙关在门外的致命风险
- ☁️ 获取官方最新的 Cloudflare IPv4/IPv6 地址白名单
- 🔓 仅允许 Cloudflare 代理访问 80/443 端口，防御源站直接探测与攻击
- 🛡️ 默认拒绝其他所有非授权入站流量，支持 `-y/--yes` 静默执行

**使用方法**:
```bash
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/network/install_ufw_cloudflare.sh)
```

---

### 🧹 cleanup.sh - 系统垃圾深度清理加速器
**功能**:
- 🗄️ **systemd-journald 深度清理**: 保留最近 2 天或 50M 日志，极大释放 VPS 磁盘
- 📦 **全发行版包缓存与残留清理**: 深度清理 Debian/Ubuntu (`apt autoremove --purge`)、RHEL/CentOS/Rocky/Fedora (`dnf/yum clean all`)、Arch (`pacman -Sc`)、Alpine (`apk cache clean`)
- 📄 日志归档轮转清理与超大日志安全截断
- 📊 准确统计清理前后磁盘使用率与释放空间

**使用方法**:
```bash
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/system/cleanup.sh)
```

---

### 💫 swap.sh - Swap 分区管理工具
**功能**:
- ➕ 一键添加 Swap 交换空间，自定义容量大小
- ⚙️ **文件系统自适应**: 优先采用 `fallocate` 极速分配，在 XFS/Btrfs 等不支持空洞的文件系统上自动 fallback 到 `dd` 块写入，确保 100% 成功激活
- 🚀 自动优化 `vm.swappiness=60` 并写入 `/etc/fstab` 实现开机持久化挂载
- ➖ 一键彻底卸载并清理 Swap 分区

**使用方法**:
```bash
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/system/swap.sh)
```

---

### 🌐 all_http_socks5.sh - HTTP 与 SOCKS5 代理一键部署
**功能**:
- 🌐 自动安装配置 Squid HTTP 代理（默认端口 25562）
- 🔐 本地动态生成 `htpasswd` 凭证，摆脱外网下载密码文件的故障隐患
- 🧦 自动部署 Dante SOCKS5 代理（默认端口 25543）
- 📦 一键完成双代理部署与开机自启

**使用方法**:
```bash
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/network/all_http_socks5.sh)
```

---

### 🌍 gost.sh - Gost 代理服务器管理
**功能**:
- 🚀 自动下载适配架构的最新或稳定版 Gost
- ⚙️ 全面采用现代标准 `systemd` 托管服务 (`/etc/systemd/system/gost.service`)，摆脱淘汰的 SysVinit 与外部 Gist 下载依赖
- 🔁 支持交互式可视化管理、多端口配置与链式代理转发

**使用方法**:
```bash
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/network/gost.sh)
```

---

### 🐳 docker-ca.sh - Docker TLS 证书安全配置
**功能**:
- 🔒 自动生成 4096 位 RSA CA 根证书与服务端/客户端双向验证证书
- 🛡️ 采用 systemd drop-in (`/etc/systemd/system/docker.service.d/override.conf`) 规范挂载，不改动包管理器原装服务文件
- 🔐 私钥赋予 `0400` 严格保护权限，防止凭据泄露
- ⏰ 自动创建定时检查与续期任务

**使用方法**:
```bash
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/docker/docker-ca.sh)
```

---

### 🇨🇳 LocaleCN.sh - 简体中文环境设置工具
**功能**:
- 🇨🇳 一键设置系统全局语言环境为简体中文 (`zh_CN.UTF-8`)
- 🖥️ 支持 CentOS、Debian、Ubuntu 等主流发行版并自动备份原有配置

**使用方法**:
```bash
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/system/LocaleCN.sh)
```

---

### 🌐 nat64_optimizer.sh - NAT64/DNS64 自动优选工具
**功能**:
- 🔍 聚合抓取全球 NAT64/DNS64 节点并多模式智能测速 (ICMP/TCP53/DNS)
- ⚙️ 自动写入最优配置到 `/etc/resolv.conf` 及 `systemd-resolved`

**使用方法**:
```bash
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/system/nat64_optimizer.sh)
```

---

## 📄 License

本项目基于 [MIT](LICENSE) 许可证开源。
