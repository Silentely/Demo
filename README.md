# 🚀 Demo 

*日常工具箱 - by Silentely*

<p align="center">
  <img src="https://img.shields.io/badge/维护状态-佛系-orange?style=for-the-badge&logo=buddhism" alt="佛系维护">
  <img src="https://img.shields.io/badge/用途-自用-blue?style=for-the-badge&logo=linux" alt="自用脚本">
  <img src="https://img.shields.io/badge/环境-Shell-brightgreen?style=for-the-badge&logo=gnubash" alt="Shell">
</p>

> **🔧 纯自用，佛系维护，如果有任何问题，请自己解决 🔧**  
> **🕙 最后更新: 2025-07-29**

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

## 📖 文档

- [目录结构说明](docs/structure.md) - 详细介绍项目目录结构
- [使用示例](docs/examples.md) - 各个脚本的详细使用示例
- [贡献指南](docs/contributing.md) - 如何为项目贡献代码

## 📊 脚本使用统计

```
# 使用频率统计 (仅供参考)
statistics = {
    'install-latest-ssh.sh': '★★★★★',
    'LocaleCN.sh': '★★★★★',
    'cleanup.sh': '★★★★☆',
    'terminal_optimizer.sh': '新脚本待统计',
    'ssh_key.sh': '★★★★☆',
    'swap.sh': '★★★☆☆',
    'ChangeMirrors.sh': '★★★☆☆',
    'DockerInstallation.sh': '★★★☆☆',
    'dd-od.sh': '★★☆☆☆',
    'gost.sh': '★★☆☆☆',
    'http_install.sh': '★★☆☆☆',
    'clean_snap.sh': '★☆☆☆☆',
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