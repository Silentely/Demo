# Demo 项目 - AI 上下文索引

> **最后更新**: 2026-09-27
> **维护状态**: 佛系维护 | 自用工具集

---

## 1. 基础检索（交叉验证策略）

### 核心原则
- **禁止基于假设（Assumption）回答**，所有结论必须有代码依据
- **交叉检索强制执行**：必须同时调用 `mcp__ace-tool__search_context` + `mcp__fast-context__fast_context_search`，对比结果取交集

### 工具调用顺序
1. **先用 `mcp__ace-tool__search_context`** — 语义代码搜索，自然语言查询
2. **再用 `mcp__fast-context__fast_context_search`** — 补充检索，返回文件+行号+grep关键词
3. **对比两个工具的结果** — 取交集作为可靠上下文
4. **若结果不一致** — 增加检索深度（max_turns）或调整查询词重新检索

### 使用场景优先级

**必须用 fast_context_search 的场景**：
- 探索性搜索（不确定代码所在文件或目录）
- 用自然语言描述要找的逻辑（如"XX部署流程"、"XX事件处理"）
- 理解业务逻辑和调用链路
- 跨模块、跨层级查询（如从 router 追到 service 再到 model）
- 新任务开始前的代码调研和架构理解
- 中文语义搜索（工具支持中英文双语查询）

**根据需求选择工具**：
| 场景 | 首选工具 | 说明 |
|------|----------|------|
| 语义搜索 / 不确定位置 | `fast_context_search` | 返回文件+行号范围+grep关键词建议 |
| 精确关键词搜索 | Grep | 精准定位已知标识符 |
| 已知文件路径，查看内容 | Read | 直接读取文件内容 |
| 按文件名模式查找 | Glob | 模式匹配文件名 |
| 编辑已有文件 | Edit | 局部修改 |
| 提示词增强 | `mcp__ace-tool__enhance_prompt` | 优化任务描述以获得更精准结果 |

### 参数调优指南
- `tree_depth=1, max_turns=1` — 快速粗查，适合小项目或初步定位
- `tree_depth=3, max_turns=3`（默认）— 平衡精度与速度，适合大多数场景
- `max_turns=5` — 深度搜索，适合复杂调用链追踪
- `project_path` — 指定搜索的项目根目录，默认为当前工作目录

### 完整性检查
- 必须获取相关类、函数、变量的**完整定义与签名**
- 若上下文不足，增加 `max_turns` 参数进行递归检索直至信息完整
- 若两个工具结果不一致，需增加检索深度或调整查询词重新检索

### 需求对齐
- 若检索后需求仍有模糊空间，必须向用户输出引导性问题列表
- 直至需求边界清晰（无遗漏、无冗余）

---

## 2. 网络检索（Smart Search CLI）

### 激活条件
**触发场景**：网络搜索 / 网页抓取 / 最新信息查询 / 事实核查 / 官方文档查询
**首选工具**：`smart-search-cli` 作为默认搜索执行层

### 工具路由矩阵

| 场景 | 首选命令 | 说明 |
|------|----------|------|
| 广度探索 / 实时综合 | `smart-search search "query" --format json` | 主搜索入口，自动路由到配置的提供商 |
| 中文搜索 / 国内资讯 / 政策法规 | `smart-search zhipu-search "query" --format json` | 智谱 Web Search API |
| 官方文档 / API / SDK 查询 | `smart-search context7-library/doc "query" --format json` | Context7 优先，Exa 补充 |
| 官方域名 / 论文 / 可信站点 | `smart-search exa-search "query" --format json` | 低噪声精准发现 |
| 抓取网页内容 | `smart-search fetch "url" --format markdown` | Tavily 优先，Firecrawl 兜底 |
| 站点结构探索 | `smart-search map "url" --format json` | 文档站结构分析 |
| 深度研究 / 多源验证 | `smart-search deep "question" --format json` | 离线规划 → 分步执行 → 证据收集 |

---

## 📋 变更记录 (Changelog)

### 2026-09-27
- **全项目核心运维脚本与文档现代化加固升级**:
  - **SSH 密钥加固 (`ssh_key.sh`)**: 采用 `/etc/ssh/sshd_config.d/00-security.conf` drop-in 优先策略彻底解决云厂商镜像自带配置覆盖问题；适配 Ubuntu 24.04+ `ssh.socket` 激活机制杜绝改端口失联；新增 `-a/-k/-p/-h` CLI 非交互参数与 5 份备份轮转。
  - **UFW 防火墙配置 (`install_ufw_cloudflare.sh`)**: 动态探测当前实际 SSH 监听端口自动放行，彻底消除开启防火墙后非标 SSH 端口立即失联的重大安全事故。
  - **Docker 安装与全架构 Compose (`DockerInstallation.sh`)**: 弃用 `apt-key add`，升级为标准 `/etc/apt/keyrings/docker.gpg` 密钥管理，完美支持 Debian 12 / Ubuntu 24.04；全面支持 Docker Compose v2 二进制与官方插件版，移除旧 Python pip 编译链路。
  - **系统垃圾清理 (`cleanup.sh`)**: 引入现代 Linux `systemd-journald` 深度清理及全发行版包缓存/孤立包清理；修复输出时机与磁盘使用率统计。
  - **网络代理工具 (`gost.sh`, `all_http_socks5.sh`, `socks5_install.sh`)**: 移除 SysVinit 与外部 Gist 下载依赖，全面改用标准 systemd 服务托管；修复 SOCKS5 脚本 404 死链，采用 `apache2-utils` 本地动态安全生成认证账号；扩展 Rocky/AlmaLinux/Kali/Pop!_OS 支持。
  - **国家 IP 封禁 (`block-ips.sh`)**: 重构为管道化 `ipset restore` 批量导入，规则加载由数分钟缩减至 0.1 秒；强制走 HTTPS 并支持 curl/wget 互备与防重放。
  - **交换空间管理 (`swap.sh`)**: 引入 `fallocate` + `dd` 块写入智能 fallback 机制，完美兼容 XFS/Btrfs 文件系统。
  - **数据库备份 (`backup_postgres.sh`)**: 动态探测 `pg_dump`，支持用户环境变量覆盖与高版本自适应 (PostgreSQL 12-17+)。
  - **系统信息与依赖管理 (`install-system-information.sh`, `QLOneKeyDependency.sh`)**: 迁移 Fastfetch 上游至官方组织 `fastfetch-cli/fastfetch`；适配 Python 3.12+ (PEP 668) `--break-system-packages`。
  - **WARP 代理与终端美化 (`menu.sh`, `terminal_optimizer.sh`)**: 修复 Bash 单引号变量展开 bug 与 warp-cli 现代语法回退；修复终端美化脚本在 `-u/-f` 参数下的非交互执行逻辑与管道输入。
  - **GitHub Actions 模板**: 升级 Action 依赖至最新主流稳定版本（Node 20 runner 兼容）。

### 2025-12-19
- **tiku 模块 v1.1.1 功能增强**
  - 判断题答案识别新增罗马数字及更多叉号变体
  - 去重功能显示原题库位置（工作表名+行号）

### 2025-12-15
- **tiku 模块 v1.1.0 重大更新**
  - 新增 argparse CLI 参数解析（`--version`, `-v/--verbose`, `--dry-run`）
  - 新增数据质量验证功能
  - 优化文件编码检测性能
  - 增强错误处理与转换报告

---

## 3. 项目结构索引

```
.
├── Action/                  # GitHub Actions 工作流
│   └── docker.yml          # Docker Hub 镜像推送 CI (v4/v5 现代化)
├── Sh/                      # Shell 脚本工具集 (全套生产加固)
│   ├── docker/             # Docker 相关脚本 (Keyrings/TLS 加固)
│   ├── network/            # 网络与代理配置 (UFW防失联/systemd gost/ipset极速)
│   ├── system/             # 系统优化/清理/swap/终端美化
│   └── utils/              # 通用运维 (ssh_key/backup_postgres/ChangeMirrors)
├── Work/                    # Cloudflare Workers / Deno 边缘网关脚本
├── py/                      # Python 自动化脚本
└── tiku/                    # 题库解析与转换工具集
```
