# 项目目录结构

## 主要目录

```
Demo/
├── Action/          # GitHub Actions 自动化脚本
├── docs/            # 项目文档
├── lib/             # 公共库文件
├── py/              # Python 脚本
├── Sh/              # Shell 脚本主目录
│   ├── system/      # 系统相关脚本
│   │   ├── cleanup.sh          # 系统垃圾清理
│   │   ├── terminal_optimizer.sh  # 终端优化
│   │   ├── LocaleCN.sh         # 中文语言设置
│   │   ├── swap.sh             # Swap分区管理
│   │   └── clean_snap.sh       # Snap包清理
│   ├── network/     # 网络相关脚本
│   │   ├── gost.sh             # Gost代理安装
│   │   ├── http_install.sh     # HTTP代理安装
│   │   ├── socks5_install.sh   # SOCKS5代理安装
│   │   ├── dd-od.sh            # 系统网络重装
│   │   ├── all_http_socks5.sh  # HTTP/SOCKS5代理组合
│   │   ├── block-ips.sh        # IP封锁工具
│   │   └── install_ufw_cloudflare.sh  # UFW Cloudflare规则
│   ├── docker/      # Docker相关脚本
│   │   ├── DockerInstallation.sh  # Docker安装
│   │   ├── docker-ca.sh        # Docker CA证书
│   │   └── docker-cas.sh       # Docker CAS证书
│   └── utils/       # 通用工具脚本
│       ├── install-system-information.sh  # 系统信息工具安装
│       ├── ssh_key.sh          # SSH密钥配置
│       ├── ChangeMirrors.sh    # 镜像源切换
│       ├── Network-Reinstall-System-Modify.sh  # 网络重装系统
│       ├── QLOneKeyDependency.sh  # 依赖一键安装
│       ├── install_ipset.sh    # IP集安装
│       ├── uninstall_ipset.sh  # IP集卸载
│       ├── 10-ipset            # IP集规则
│       └── network-reinstall-os.sh  # 网络重装OS
├── Work/            # 工作相关脚本
├── LICENSE          # 许可证文件
└── README.md        # 项目说明文件
```

## 脚本分类说明

### 系统相关脚本 (Sh/system/)
- **cleanup.sh** - 系统垃圾清理加速器，清理缓存、日志、临时文件等
- **terminal_optimizer.sh** - 终端优化美化脚本，提升终端使用体验
- **LocaleCN.sh** - 简体中文环境设置工具，一键设置系统语言
- **swap.sh** - Swap分区管理工具，添加或删除swap分区
- **clean_snap.sh** - Snap包清理小工具，删除旧版本snap包

### 网络相关脚本 (Sh/network/)
- **gost.sh** - Gost代理服务器安装脚本，支持多种协议
- **http_install.sh** - HTTP代理自动配置工具，安装配置Squid
- **socks5_install.sh** - SOCKS5代理安装脚本
- **dd-od.sh** - 系统重装神器，支持多种Linux/Windows系统
- **all_http_socks5.sh** - HTTP/SOCKS5代理组合安装
- **block-ips.sh** - IP封锁工具，批量阻止恶意IP
- **install_ufw_cloudflare.sh** - UFW Cloudflare规则配置

### Docker相关脚本 (Sh/docker/)
- **DockerInstallation.sh** - Docker一键安装脚本，自动安装配置Docker环境
- **docker-ca.sh** - Docker CA证书管理
- **docker-cas.sh** - Docker CAS证书管理

### 通用工具脚本 (Sh/utils/)
- **install-system-information.sh** - 系统信息美化工具，安装FastFetch/Neofetch
- **ssh_key.sh** - SSH密钥配置工具，增强系统安全性
- **ChangeMirrors.sh** - 镜像源切换工具，自动切换到更快的软件源
- **Network-Reinstall-System-Modify.sh** - 网络重装系统工具
- **QLOneKeyDependency.sh** - 依赖一键安装工具
- **install_ipset.sh** - IP集安装工具
- **uninstall_ipset.sh** - IP集卸载工具
- **10-ipset** - IP集规则文件
- **network-reinstall-os.sh** - 网络重装OS工具

## 其他目录说明

### Action/
存放 GitHub Actions 相关的自动化脚本，用于 CI/CD 流程。

### Work/
存放特定工作场景下的脚本，可能包含特定业务逻辑。

### py/
存放 Python 编写的工具脚本。

### lib/
存放公共库文件，供其他脚本调用，实现代码复用。