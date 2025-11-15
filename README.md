# 🚀 Demo 

*日常工具箱 - by Silentely*

<p align="center">
  <img src="https://img.shields.io/badge/维护状态-佛系-orange?style=for-the-badge&logo=buddhism" alt="佛系维护">
  <img src="https://img.shields.io/badge/用途-自用-blue?style=for-the-badge&logo=linux" alt="自用脚本">
  <img src="https://img.shields.io/badge/环境-Shell-brightgreen?style=for-the-badge&logo=gnubash" alt="Shell">
</p>

> **🔧 纯自用，佛系维护，如果有任何问题，请自己解决 🔧**  
> **🕙 最后更新: 2025-11-15**

## 📁 项目结构

```
Demo/
├── Sh/              # 主要的Shell脚本目录
│   ├── system/      # 系统相关脚本
│   ├── network/     # 网络相关脚本
│   ├── docker/      # Docker相关脚本
│   └── utils/       # 通用工具脚本
├── Action/          # 自动化动作脚本
├── Work/            # 工作相关脚本
├── py/              # Python脚本
├── lib/             # 公共库文件
├── docs/            # 项目文档
├── LICENSE          # 许可证文件
└── README.md        # 项目说明文件
```

其中 `Sh/` 目录包含了大部分实用的Shell脚本工具，涵盖了系统优化、网络配置、环境安装等多个方面。

## 🚀 快速开始

选择您需要的脚本并直接运行：

```bash
# 示例：运行系统清理脚本
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/system/cleanup.sh)

# 示例：运行Docker安装脚本
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/docker/DockerInstallation.sh)
```

查看 [使用示例文档](docs/examples.md) 获取更多详细使用方法。

## 📚 Shell脚本使用说明

### 🔐 install-system-information.sh
**脚本概述**: 
```
╭──────────────────────────────────────────╮
│    系统信息美化工具 FastFetch 自动安装   │
╰──────────────────────────────────────────╯
```
**功能**: 
- 🔍 自动检测系统架构并选择合适的安装包
- 🌐 智能判断中国大陆网络环境，使用镜像加速下载
- 🎨 自动配置美观的系统信息显示界面
- 🔄 为Debian 11提供neofetch替代方案
- 📋 显示系统详细硬件与软件信息，美化登录界面

**使用方法**:
```bash
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/utils/install-system-information.sh)
```

### 🇨🇳 LocaleCN.sh - 简体中文环境设置工具
**脚本概述**: 
```
 ______     __  __     __     __   __     ______     ______     ______    
/\  ___\   /\ \_\ \   /\ \   /\ "-.\ \   /\  ___\   /\  ___\   /\  ___\   
\ \ \____  \ \  __ \  \ \ \  \ \ \-.  \  \ \  __\   \ \___  \  \ \  __\   
 \ \_____\  \ \_\ \_\  \ \_\  \ \_\\"\_\  \ \_____\  \/\_____\  \ \_____\ 
  \/_____/   \/_/\/_/   \/_/   \/_/ \/_/   \/_____/   \/_____/   \/_____/ 
```
**功能**: 
- 🇨🇳 一键设置系统全局语言环境为简体中文
- 🖥️ 支持各种主流Linux发行版（CentOS、Debian、Ubuntu等）
- 🔄 自动备份原有语言配置，确保操作安全
- 📦 智能安装必要的中文语言包
- 🛠️ 自动处理各发行版的配置文件差异
- 🚫 适配不同操作系统的安装方式，自动处理异常情况

**使用方法**:
```bash
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/system/LocaleCN.sh)
```

**支持参数**:
- `-h, --help`  help 显示帮助信息
- `-f, --force` 💪 强制执行，不进行确认提示

### 🌍 gost.sh
**脚本概述**: 
```
┌─────────────────────────┐
│  Gost代理服务器安装脚本 │
└─────────────────────────┘
```
**功能**: 自动检测系统环境、获取最新版本的Gost并进行安装

**使用方法**:
```bash
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/network/gost.sh)
```

### 💾 dd-od.sh
**脚本概述**: 
```
╔═══════════════════╗
║  系统重装神器     ║
╚═══════════════════╝
```
**功能**: 支持多种Linux发行版和Windows系统的一键网络重装

**使用方法**:
```bash
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/network/dd-od.sh)
```

### 🧹 cleanup.sh - 系统垃圾清理加速器
**脚本概述**: 
```
⚡️ 系统垃圾清理加速器 ⚡️
```
**功能**: 
- 🗑️ 清理系统缓存、日志、临时文件等，释放磁盘空间
- 📊 显示清理前后的磁盘使用情况
- 🛡️ 安全操作，避免误删重要文件

**使用方法**:
```bash
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/system/cleanup.sh)
```

**支持参数**:
- `-h, --help`  help 显示帮助信息
- `-v, --verbose` 📢 详细输出模式
- `-y, --yes` ✅ 自动确认所有操作

### 🎨 terminal_optimizer.sh - 终端优化美化脚本
**脚本概述**: 
```
╔════════════════════════════════════════════╗
║   终端优化美化脚本（Terminal Optimizer）  ║
```
**功能**:
- 🖥️ 优化与美化 Linux 终端体验
- 🛠️ 自动检测主流发行版和包管理器
- 🔧 快速配置炫酷 PS1、Git 集成与常用别名
- 📝 历史命令增强，提升效率
- 🧹 一键还原、无残留
- 👤 支持 root 和普通用户

**使用方法**:
```bash
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/system/terminal_optimizer.sh)
```

**支持参数**:
- `-h, --help`  help 显示帮助信息
- `-v, --version` 🔢 显示脚本版本
- `-u, --uninstall` 🔙 恢复到原始配置
- `-f, --force` 💪 强制执行，不进行确认提示

### 🔑 ssh_key.sh
**脚本概述**: 
```
 ___ ___ _  _   _  _____   __
/ __/ __| || | | |/ / __| _\ \
\__ \__ \ __ | | ' <\__ \| | |
|___/___/_||_| |_|\_\___/ | |_|
                          \__/
```
**功能**: 
- 🛡️ 配置SSH密钥登录
- 🔒 管理SSH安全设置
- 🔧 支持多种登录方式配置

**使用方法**:
```bash
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/utils/ssh_key.sh)
```

### 💫 swap.sh - Swap分区管理工具
**脚本概述**: 
```
 ____  _      ___    ____  
/ ___|| |    / _ \  |  _ \ 
\___ \| |   | | | | | |_) |
 ___) | |___| |_| | |  __/ 
|____/|_____|\__\_\ |_|    
```
**功能**: 
- ➕ 一键添加swap分区
- ➖ 一键删除swap分区
- 📏 自定义swap大小
- 🛡️ 检测OpenVZ虚拟化环境兼容性

**使用方法**:
```bash
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/system/swap.sh)
```

**支持参数**:
- `-h, --help`  help 显示帮助信息

### 🌐 nat64_optimizer.sh - NAT64/DNS64 自动优选工具
**脚本概述**:
```
╭──────────────────────────────────────────╮
│    NAT64/DNS64 自动优选脚本              │
╰──────────────────────────────────────────╯
```
**功能**:
- 🔍 自动从多个源获取NAT64/DNS64服务器列表
- 📊 智能测试延迟并选择最佳服务器
- ⚙️ 自动配置系统DNS和systemd-resolved
- 🔄 支持自动应用或交互式确认
- 📝 详细的日志记录和错误处理

**使用方法**:
```bash
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/system/nat64_optimizer.sh)
```

**支持参数**:
- `-a, --auto-apply` 🤖 自动应用最佳DNS64，无需交互
- `-c, --count <N>` 📊 每台服务器发送的ping次数（默认：4）
- `-t, --timeout <sec>` ⏱️ ping命令整体超时秒数（默认：5）
- `-h, --help` ❓ 显示帮助信息

### 🔄 all_http_socks5.sh - HTTP与SOCKS5代理一键部署
**脚本概述**:
```
┌─────────────────────────┐
│  代理服务器一键部署工具  │
└─────────────────────────┘
```
**功能**:
- 🌐 自动安装和配置Squid HTTP代理（端口25562）
- 🔐 配置HTTP代理认证
- 🧦 自动安装SOCKS5代理（端口25543）
- 📦 一键完成双代理部署

**使用方法**:
```bash
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/network/all_http_socks5.sh)
```

### 🧦 socks5_install.sh - Dante SOCKS5服务器安装
**脚本概述**:
```
Dante Socks5 Server AutoInstall
```
**功能**:
- 🔧 自动检测系统类型（Debian/Ubuntu/CentOS）
- 📥 从GitHub或备用源下载安装脚本
- ⚙️ 支持自定义端口、用户名和密码

**使用方法**:
```bash
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/network/socks5_install.sh)
```

**支持参数**:
- `--port=<端口>` 指定SOCKS5端口
- `--user=<用户名>` 指定认证用户名
- `--passwd=<密码>` 指定认证密码
- `--no-github` 使用备用下载源

### 🛡️ install_ufw_cloudflare.sh - UFW防火墙Cloudflare配置
**脚本概述**:
```
╔════════════════════════════════════╗
║  UFW + Cloudflare IP 白名单配置   ║
╚════════════════════════════════════╝
```
**功能**:
- 🔥 自动安装和配置UFW防火墙
- ☁️ 获取最新的Cloudflare IPv4/IPv6地址
- 🔓 仅允许Cloudflare IP访问80/443端口
- 🔑 自动开放SSH（22）端口
- 🛡️ 默认拒绝其他入站连接

**使用方法**:
```bash
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/network/install_ufw_cloudflare.sh)
```

### 🚫 block-ips.sh - 国家IP封禁工具
**脚本概述**:
```
Linux VPS一键屏蔽指定国家所有的IP访问
```
**功能**:
- 🌍 根据国家代码封禁整个国家的IP段
- 📋 使用ipset高效管理大量IP规则
- 🔓 支持解封已封禁的国家IP
- 📊 查看当前封禁列表

**使用方法**:
```bash
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/network/block-ips.sh)
```

**功能选项**:
1. 封禁IP - 输入国家代码（如cn）进行封禁
2. 解封IP - 输入国家代码进行解封
3. 查看封禁列表 - 显示当前所有封禁规则

### 🐳 docker-ca.sh - Docker TLS证书自动配置
**脚本概述**:
```
╭───────────────────────────╮
│  Docker TLS 安全配置工具  │
╰───────────────────────────╯
```
**功能**:
- 🔐 自动生成CA证书和服务器/客户端证书
- 🌐 支持IP地址和域名的TLS配置
- 🔄 自动配置证书续期定时任务（每15天检查）
- 🛡️ 配置Docker守护进程使用TLS验证
- 💾 自动备份原有配置

**使用方法**:
```bash
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/docker/docker-ca.sh)
```

### 💾 backup_postgres.sh - PostgreSQL自动备份工具
**脚本概述**:
```
╔═══════════════════════════════════╗
║  PostgreSQL 数据库自动化备份脚本  ║
╚═══════════════════════════════════╝
```
**功能**:
- 🗄️ 使用pg_dump进行数据库备份
- 🔐 通过.pgpass文件实现免密备份
- 📅 生成带时间戳的备份文件
- 📝 详细的执行日志记录
- 🧹 自动清理指定天数前的旧备份
- ⏰ 支持cron定时任务

**使用方法**:
```bash
# 1. 配置.pgpass文件（必需）
echo "localhost:5432:数据库名:用户名:密码" > ~/.pgpass
chmod 600 ~/.pgpass

# 2. 编辑脚本中的配置参数
# 3. 运行脚本
bash /path/to/backup_postgres.sh

# 4. 设置定时任务（可选）
# crontab -e
# 30 2 * * * /path/to/backup_postgres.sh > /dev/null 2>&1
```

### 📦 QLOneKeyDependency.sh - 青龙面板依赖一键安装
**脚本概述**:
```
青龙面板依赖一键安装脚本
```
**功能**:
- 📚 自动安装青龙面板所需的Node.js依赖
- 🐍 安装Python依赖包
- 🎨 安装Canvas等图形处理库
- 🔧 配置npm镜像源加速下载
- 🚀 支持pnpm包管理器

**使用方法**:
```bash
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/utils/QLOneKeyDependency.sh)
```

**注意事项**:
- 需要在青龙面板容器内执行
- 确保已安装Node.js和npm
- 安装完成后建议重启Docker容器

### 🌐 http_install.sh
**脚本概述**:
```
HTTP代理自动配置工具
```
**功能**: 自动安装和配置Squid HTTP代理服务器

**使用方法**:
```bash
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/network/http_install.sh)
```

### 🔄 ChangeMirrors.sh
**脚本概述**: 
```
┌─────────────────────────┐
│     镜像源切换工具      │
└─────────────────────────┘
```
**功能**: 自动切换系统软件源到更快的镜像

**使用方法**:
```bash
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/utils/ChangeMirrors.sh)
```

### 🧼 clean_snap.sh - Snap包清理小工具
**脚本概述**: 
```
Snap包清理小工具
```
**功能**: 
- 🗑️ 删除系统中不再需要的旧版本snap包
- 🛑 自动关闭所有snap应用后再清理
- 📋 安全操作，避免影响正在运行的服务

**使用方法**:
```bash
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/system/clean_snap.sh)
```

**支持参数**:
- `-h, --help`  help 显示帮助信息

### 🐳 DockerInstallation.sh
**脚本概述**: 
```
╭───────────────────╮
│ Docker一键安装脚本 │
╰───────────────────╯
```
**功能**: 自动安装和配置Docker环境

**使用方法**:
```bash
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/docker/DockerInstallation.sh)
```

### 🖥️ Network-Reinstall-System-Modify.sh
**脚本概述**: 
```
 _   _ _____ _____        _____  ____  
| \ | | ____|_   _|      |  __ \|  _ \ 
|  \| |  _|   | |  _____  | |  | | |_) |
| . ` | |___  | | |_____| | |  | |  _ < 
|_|\_\|_____| |_|         |_|  |_|_| \_\
```
**功能**: 通过网络一键重装各种Linux/Windows系统

**使用方法**:
```bash
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/utils/Network-Reinstall-System-Modify.sh)
```

## 📂 Work目录 - Cloudflare Workers脚本

### 🌐 mirror.js - Docker镜像代理
**功能**: 通过Cloudflare Workers代理Docker Hub，加速镜像拉取
**使用**: 修改daemon.json添加`"registry-mirrors": ["https://你的域名"]`

### 📱 wx.js - 企业微信推送
**功能**: 企业微信消息推送服务，支持文本、图文、Markdown等多种格式

### 🔐 tgapi.js - Telegram Bot API代理
**功能**: 代理Telegram Bot API请求，解决访问限制

### 🌉 proxy.js - 通用Web代理
**功能**: 基于Cloudflare Workers的通用HTTP/HTTPS代理

## 🐍 Python脚本

### ⚔️ cc.py - Layer 7 DDoS测试工具
**功能**: 支持CC、POST、Slowloris攻击模式，支持SOCKS4/5代理
**⚠️ 警告**: 仅用于授权的安全测试，禁止攻击.gov网站

## 🔧 GitHub Actions

### 🐳 deploy-docker.yml - Docker镜像CI/CD
**功能**: 自动构建Docker镜像并推送到Docker Hub，基于Git Tag管理版本

## 📖 文档

- [目录结构说明](docs/structure.md) - 详细介绍项目目录结构
- [使用示例](docs/examples.md) - 各个脚本的详细使用示例
- [贡献指南](docs/contributing.md) - 如何为项目贡献代码

## 📊 脚本使用统计

```
# 使用频率统计 (仅供参考)
statistics = {
    'nat64_optimizer.sh': '★★★★★',
    'install-system-information.sh': '★★★★★',
    'LocaleCN.sh': '★★★★★',
    'cleanup.sh': '★★★★☆',
    'terminal_optimizer.sh': '★★★★☆',
    'ssh_key.sh': '★★★★☆',
    'docker-ca.sh': '★★★☆☆',
    'backup_postgres.sh': '★★★☆☆',
    'swap.sh': '★★★☆☆',
    'ChangeMirrors.sh': '★★★☆☆',
    'DockerInstallation.sh': '★★★☆☆',
    'all_http_socks5.sh': '★★☆☆☆',
    'install_ufw_cloudflare.sh': '★★☆☆☆',
    'dd-od.sh': '★★☆☆☆',
    'gost.sh': '★★☆☆☆',
    'http_install.sh': '★★☆☆☆',
    'block-ips.sh': '★☆☆☆☆',
    'clean_snap.sh': '★☆☆☆☆',
    'QLOneKeyDependency.sh': '★☆☆☆☆',
    'Network-Reinstall-System-Modify.sh': '★☆☆☆☆'
}
```

## 🤝 贡献

欢迎提交 Pull Request 或 Issue。请查看 [贡献指南](docs/contributing.md) 了解详情。

## License

- 本项目的所有代码除另有说明外,均按照 [MIT License](LICENSE) 发布。
- 本项目的README.MD，wiki等资源基于 [CC BY-NC-SA 4.0][CC-NC-SA-4.0] 这意味着你可以拷贝、并再发行本项目的内容，<br/>
  但是你将必须同样**提供原作者信息以及协议声明**。同时你也**不能将本项目用于商业用途**，按照我们狭义的理解<br/>
  (增加附属条款)，凡是**任何盈利的活动皆属于商业用途**。
- 请在遵守当地相关法律法规的前提下使用本项目。

<p align="center">
  <img src="https://github.com/docker/dockercraft/raw/master/docs/img/contribute.png?raw=true" alt="贡献图示">
</p>

[github-hosts]: https://raw.githubusercontent.com/racaljk/hosts/master/hosts "hosts on Github"
[CC-NC-SA-4.0]: https://creativecommons.org/licenses/by-nc-sa/4.0/deed.zh

<div align="center">
  <sub>Made with ❤️ by <a href="https://github.com/Silentely">Silentely</a></sub>
</div>