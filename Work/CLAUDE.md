[根目录](../CLAUDE.md) > **Work**

---

# Work - Cloudflare Workers 脚本

> **模块职责**: 提供运行在 Cloudflare Workers 上的边缘计算脚本,包括代理、镜像、API 转发等功能

---

## 📋 变更记录 (Changelog)

### 2025-12-13
- 初始化模块文档
- 完成脚本清单与接口说明

---

## 🎯 模块职责

本模块包含 Cloudflare Workers 脚本,利用 CDN 边缘节点提供:
- Docker Hub 镜像代理(加速国内拉取)
- 通用 Web 代理(绕过访问限制)
- Telegram Bot API 代理
- 企业微信消息推送服务

---

## 🚪 入口与启动

### 主要脚本入口

| 脚本名 | 功能 | 运行环境 | 使用场景 |
|-------|------|---------|---------|
| `mirror.js` | Docker Hub 镜像代理 | Cloudflare Workers | 加速 Docker 镜像拉取 |
| `proxy.js` | 通用 Web 代理 | Cloudflare Workers | HTTP/HTTPS 代理服务 |
| `tgapi.js` | Telegram Bot API 代理 | Cloudflare Workers | 解决 Telegram API 访问限制 |
| `wx.js` | 企业微信消息推送 | Cloudflare Workers | 消息通知服务 |
| `dns.js` | DNS 相关功能 | Cloudflare Workers | DNS 解析辅助 |
| `git.js` | Git 相关功能 | Cloudflare Workers | Git 操作辅助 |
| `channel.js` | 频道相关功能 | Cloudflare Workers | 频道管理辅助 |
| `cosr.js` | CORS 处理 | Cloudflare Workers | 跨域问题解决 |

---

## 🔌 对外接口

### mirror.js - Docker 镜像代理
**核心功能**:
- 代理 Docker Hub 镜像请求(`registry-1.docker.io`)
- 自动处理认证(`auth.docker.io`)
- 支持 library 仓库自动补全(如 `mysql/mysql-server` → `library/mysql/mysql-server`)

**使用方式**:
```json
// /etc/docker/daemon.json
{
  "registry-mirrors": ["https://your-domain.workers.dev"]
}
```

**拉取示例**:
```bash
docker pull your-domain.workers.dev/mysql/mysql-server:latest
```

**关键变量**:
- `hub_host`: `registry-1.docker.io`(Docker Hub 地址)
- `auth_url`: `https://auth.docker.io`(认证服务地址)
- `workers_url`: 需自定义为你的 Workers 域名

**请求流程**:
1. 客户端请求 Workers URL
2. Workers 解析路径,补全 library 前缀(如需)
3. 转发请求到 Docker Hub
4. 处理认证头(`Www-Authenticate`)
5. 返回镜像层数据或重定向到 CDN

---

### proxy.js - 通用 Web 代理
**核心功能**:
- 通用 HTTP/HTTPS 代理
- CORS 预检请求处理
- 自动添加 CORS 响应头

**使用场景**: 绕过访问限制,代理第三方 API 请求

**关键函数**:
- `fetchHandler()`: 主请求处理器
- `httpHandler()`: HTTP 代理逻辑
- `proxy()`: 实际代理请求与响应处理

---

### tgapi.js - Telegram Bot API 代理
**核心功能**: 代理 Telegram Bot API 请求,解决国内访问限制

**使用方式**: 将 Bot 的 API 端点替换为 Workers URL
```javascript
// 原始端点
https://api.telegram.org/bot<TOKEN>/sendMessage

// Workers 代理端点
https://your-tg-proxy.workers.dev/bot<TOKEN>/sendMessage
```

---

### wx.js - 企业微信推送
**核心功能**: 企业微信消息推送服务,支持多种消息格式

**支持格式**:
- 文本消息
- 图文消息
- Markdown 消息

**使用场景**: 服务器监控告警、脚本执行通知

---

## 🔗 关键依赖与配置

### 运行环境
- **平台**: Cloudflare Workers (V8 引擎)
- **限制**:
  - 免费套餐: 100,000 请求/天
  - CPU 时间: 10ms/请求(免费)或 50ms/请求(付费)
  - 内存: 128MB

### 配置项(以 mirror.js 为例)
```javascript
const hub_host = 'registry-1.docker.io'        // Docker Hub 地址
const auth_url = 'https://auth.docker.io'       // 认证服务
const workers_url = 'https://自定义域名'        // 需修改为实际域名
```

### 部署方式
```bash
# 使用 Wrangler CLI 部署
wrangler publish mirror.js

# 或在 Cloudflare Dashboard 手动上传
```

---

## 📦 数据模型

### Docker 镜像请求路径格式
```
GET /v2/{namespace}/{repo}/{type}/{digest}
# 示例:
GET /v2/library/mysql/manifests/latest
GET /v2/library/mysql/blobs/sha256:abc123...
```

### 认证 Token 请求格式
```
GET /token?service=registry.docker.io&scope=repository:library/mysql:pull
```

---

## 🧪 测试与质量

### 功能测试
```bash
# 测试 Docker 镜像代理
docker pull your-domain.workers.dev/nginx:alpine

# 测试 Telegram API 代理
curl https://your-tg-proxy.workers.dev/bot<TOKEN>/getMe

# 测试企业微信推送
curl -X POST https://your-wx.workers.dev/send \
  -H "Content-Type: application/json" \
  -d '{"msgtype":"text","text":{"content":"测试消息"}}'
```

### 性能监控
在 Cloudflare Dashboard 查看:
- 请求数/成功率
- 错误率
- CPU 使用时间
- 带宽消耗

---

## ❓ 常见问题 (FAQ)

**Q: Docker 镜像代理拉取失败?**
A: 检查 `workers_url` 是否正确配置为你的 Workers 域名,确保路径中包含 `/v2/` 前缀。

**Q: Cloudflare Workers 报 "CPU time limit exceeded"?**
A: 优化代码逻辑,减少同步操作,考虑升级到付费套餐(50ms CPU 时间)。

**Q: CORS 错误无法解决?**
A: 确保 `PREFLIGHT_INIT` 中的 CORS 头配置正确,检查 `access-control-allow-origin` 是否为 `*`。

**Q: 企业微信推送无响应?**
A: 检查企业微信 Webhook 地址是否正确,确认消息格式符合官方文档要求。

---

## 📂 相关文件清单

```
Work/
├── mirror.js           # Docker Hub 镜像代理(核心)
├── proxy.js            # 通用 Web 代理
├── tgapi.js            # Telegram Bot API 代理
├── wx.js               # 企业微信消息推送
├── dns.js              # DNS 相关功能
├── git.js              # Git 操作辅助
├── channel.js          # 频道管理
├── cosr.js             # CORS 处理
├── proxy-1.js          # 代理备用版本
└── surge-replace-body.js  # Surge 脚本(响应体替换)
```

**关键文件**:
- `mirror.js` (211 行): 最复杂,处理 Docker Hub 完整代理逻辑
- `proxy.js`: 通用代理模板,可用于其他服务

---

## 🔍 相关模块

- [py](../py/CLAUDE.md): Python 工具脚本
- [Sh/network](../Sh/network/CLAUDE.md): 网络配置工具

---

## 🚀 部署指南

### 前置要求
1. Cloudflare 账号
2. 已绑定自定义域名(可选,但推荐)
3. 安装 Wrangler CLI: `npm install -g wrangler`

### 部署步骤
```bash
# 1. 登录 Cloudflare
wrangler login

# 2. 创建 Workers 项目
wrangler init my-docker-proxy

# 3. 复制脚本内容到 src/index.js
cp mirror.js my-docker-proxy/src/index.js

# 4. 修改 wrangler.toml 配置
# name = "my-docker-proxy"
# compatibility_date = "2023-01-01"

# 5. 部署
wrangler publish
```

### 配置 Docker
```bash
# 编辑 daemon.json
sudo nano /etc/docker/daemon.json

# 添加镜像地址
{
  "registry-mirrors": ["https://my-docker-proxy.your-domain.workers.dev"]
}

# 重启 Docker
sudo systemctl restart docker
```

---

**维护者**: Silentely
**最后更新**: 2025-12-13
