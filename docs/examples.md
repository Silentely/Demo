# 脚本使用示例

本文档提供了项目中主要脚本的使用示例和预期输出。

## 系统优化类脚本

### cleanup.sh - 系统垃圾清理加速器

清理系统缓存、日志、临时文件等，释放磁盘空间。

```bash
# 直接运行脚本
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/system/cleanup.sh)

# 或者下载后运行
curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/system/cleanup.sh -o cleanup.sh
chmod +x cleanup.sh
./cleanup.sh
```

预期输出：
```
   _____ _           _             
  / ____| |         | |            
 | |    | | ___  ___| |_ ___  _ __ 
 | |    | |/ _ \/ __| __/ _ \| '__|
 | |____| |  __/ (__| || (_) | |   
  \_____|_|\___|\___|\__\___/|_|   
                                  
============================================================
[INFO] 开始清理系统垃圾文件...
[INFO] 清理 APT 缓存...
[SUCCESS] APT 缓存清理完成
[INFO] 清理日志文件...
[SUCCESS] 日志文件清理完成
[INFO] 清理临时文件...
[SUCCESS] 临时文件清理完成
[SUCCESS] 系统垃圾清理完成，共释放 X MB 空间
```

### terminal_optimizer.sh - 终端优化美化脚本

优化与美化 Linux 终端体验。

```bash
# 运行终端优化脚本
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/system/terminal_optimizer.sh)
```

支持的参数：
```bash
# 显示帮助信息
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/system/terminal_optimizer.sh) -h

# 卸载配置并还原
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/system/terminal_optimizer.sh) -u

# 强制执行，不进行确认提示
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/system/terminal_optimizer.sh) -f
```

### LocaleCN.sh - 简体中文环境设置工具

一键设置系统全局语言环境为简体中文。

```bash
# 设置系统语言为简体中文
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/system/LocaleCN.sh)
```

支持的参数：
```bash
# 显示帮助信息
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/system/LocaleCN.sh) -h

# 强制执行，不进行确认提示
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/system/LocaleCN.sh) -f
```

### swap.sh - Swap分区管理工具

一键添加或删除swap分区。

```bash
# 添加或管理 swap 分区
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/system/swap.sh)
```

支持的参数：
```bash
# 显示帮助信息
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/system/swap.sh) -h
```

### clean_snap.sh - Snap包清理小工具

删除系统中不再需要的旧版本snap包。

```bash
# 清理旧版本snap包
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/system/clean_snap.sh)
```

支持的参数：
```bash
# 显示帮助信息
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/system/clean_snap.sh) -h
```

## 网络工具类脚本

### gost.sh - Gost代理服务器安装脚本

自动检测系统环境、获取最新版本的Gost并进行安装。

```bash
# 安装 Gost 代理服务器
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/network/gost.sh)
```

### http_install.sh - HTTP代理自动配置工具

自动安装和配置Squid HTTP代理服务器。

```bash
# 安装 HTTP 代理服务器
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/network/http_install.sh)
```

## 安装工具类脚本

### DockerInstallation.sh - Docker一键安装脚本

自动安装和配置Docker环境。

```bash
# 安装 Docker 环境
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/docker/DockerInstallation.sh)
```

预期输出：
```
 ------------ 脚本执行结束 ------------ 

┌────────────────────────────────────────┐
│   __  __ ____  ____  _   _ _____ _____ │
│  |  \/  |___ \|  _ \| | | | ____|_   _|│
│  | |\/| | __) | |_) | |_| |  _|   | |  │
│  | |  | |/ __/|  __/|  _  | |___  | |  │
│  |_|  |_|_____|_|   |_| |_|_____| |_|  │
└────────────────────────────────────────┘

 官方网站 https://supermanito.github.io/LinuxMirrors

[INFO] Docker 版本: 20.10.17
[SUCCESS] Docker 安装完成
[INFO] Docker Compose 版本: v2.6.0
[SUCCESS] Docker Compose 安装完成
```

### install-system-information.sh - 系统信息美化工具

安装并配置 FastFetch 或 Neofetch 来美化系统信息显示。

```bash
# 安装系统信息显示工具
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/utils/install-system-information.sh)
```

## 镜像源管理脚本

### ChangeMirrors.sh - 镜像源切换工具

自动切换系统软件源到更快的镜像。

```bash
# 切换系统软件源
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/utils/ChangeMirrors.sh)
```

## 系统重装脚本

### dd-od.sh - 系统重装神器

支持多种Linux发行版和Windows系统的一键网络重装。

```bash
# 网络重装系统
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/network/dd-od.sh)
```

以上脚本均支持 `-h` 或 `--help` 参数查看详细使用说明。