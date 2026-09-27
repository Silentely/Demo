[根目录](../../CLAUDE.md) > [Sh](../) > **docker**

---

# Sh/docker - Docker 安装与证书管理

> **模块职责**: 提供 Docker 一键安装和 TLS 证书自动配置与管理工具

---

## 变更记录 (Changelog)

### 2026-09-27
- **`DockerInstallation.sh` 现代系统适配与 Compose 架构升级**:
  - 弃用已被废弃的 `apt-key add`，升级为现代标准 `/etc/apt/keyrings/docker.gpg` 存储签名密钥，向下回退兼容旧系统。
  - 完美解决 Debian 12 (Bookworm) 与 Ubuntu 24.04 (Noble) 下 `apt-key` 报错导致安装中断的问题。
  - Docker Compose 全架构现代化适配：升级至 v2 二进制与 `docker-compose-plugin`，移除过时且易因 PEP 668 报错的 Python pip 编译链路。
  - 增加管道输入重定向，适配 `bash <(curl ...)` 远程执行。
- **`docker-ca.sh` 鲁棒性与权限加固**:
  - 改用现代 systemd drop-in 配置 (`/etc/systemd/system/docker.service.d/override.conf`)，避免直接修改系统软件包 service 文件导致的更新冲突与覆盖。
  - 私钥安全权限收紧：严格设置 `chmod 0400` 保护 CA 与服务/客户端私钥文件。
  - 外网 IP 探测自适应：支持多源自动重试（ipify, ifconfig.me, icanhazip）与交互式手动输入兜底。
  - 自动续期脚本目录路径动态获取，修复脚本移动后定时任务找不到路径的隐患。
- **`docker-cas.sh` 健壮性加固**:
  - 增加 IP 参数为空校验与用法提示，修复多次运行导致 `extfile.cnf` 无限重复追加问题。

### 2025-12-13
- 初始化模块文档
- 完成证书生成流程与续期机制说明
- 添加详细的接口文档

---

## 模块职责

本模块包含 Docker 相关的部署与安全配置工具:
- Docker CE 多源一键安装 (支持国内镜像加速、Debian 12/Ubuntu 24.04 密钥兼容)
- Docker TLS 证书自动生成与配置 (systemd drop-in 规范)
- 证书自动续期定时任务
- Docker Compose v2 全架构安装与软链接

---

## 入口与启动

### 主要脚本入口

| 脚本名 | 功能 | 复杂度 | 执行方式 |
|-------|------|--------|---------|
| `DockerInstallation.sh` | Docker CE 多源一键安装 (现代 Keyrings 版) | 高 (600+行) | `bash DockerInstallation.sh` |
| `docker-ca.sh` | Docker TLS 证书自动配置 (加固版) | 中 (135行) | `bash docker-ca.sh` |
| `docker-cas.sh` | 简化版证书生成 (参数校验加固) | 低 (25行) | `bash docker-cas.sh <IP地址>` |

---

## 重点脚本说明

### docker-ca.sh (加固版)

**功能概述**:
- 自动检测并安装 Docker（若未安装）。
- 生成 4096 位 RSA CA 根证书与服务器/客户端证书，并赋予 `0400` 安全只读权限。
- 通过 `/etc/systemd/system/docker.service.d/override.conf` 规范挂载 TLS 证书，监听 `2376` 端口。
- 启动失败自动回滚默认配置，确保宿主机 Docker 不崩溃。
- 每 15 天定期检查并续期有效时长不足 20 天的证书。

---

## 相关文件清单

```
Sh/docker/
├── DockerInstallation.sh    # Docker CE 多源一键安装 (现代系统适配) ⭐
├── docker-ca.sh             # Docker TLS 证书自动配置 (drop-in 加固) ⭐
├── docker-cas.sh            # 简化版证书生成 (防膨胀加固)
└── CLAUDE.md                # 本文档
```

---

**维护者**: Silentely
**最后更新**: 2026-09-27
