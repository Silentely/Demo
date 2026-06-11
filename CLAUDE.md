# Demo 项目 - AI 上下文索引

> **最后更新**: 2025-12-19
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

### 执行策略

**搜索构建**：
- 广度搜索：`search --extra-sources 1..3`（增加额外来源）
- 深度验证：`search --validation strict`（严格验证模式）
- 中文内容：`zhipu-search`（智谱 API 优化）
- 技术文档：`context7-library/doc`（官方文档优先）

**证据策略**（`fetch_before_claim`）：
1. **候选 URL 发现** — 使用 `search` / `exa-search` / `zhipu-search` / `context7-*`
2. **关键页面抓取** — 使用 `fetch` 获取完整内容
3. **交叉验证** — 多源对比，确认信息一致性

**结果整合**：
- 强制标注来源格式：`[标题](URL)`
- 区分 `primary_sources`（已验证）和 `extra_sources`（候选）
- 时间敏感信息必须注明日期

### 错误恢复

| 错误类型 | 处理方式 |
|----------|----------|
| 超时 | 重试 3 次 `--timeout 180`，间隔 5 秒 |
| 全部超时 | 降级到 `exa-search` + `fetch` 手动取证 |
| 无结果 | 放宽查询条件 / 切换提供商 |
| 配置异常 | `smart-search doctor --format json` 诊断 |

### 核心约束

✅ **必须做到**：
- 首选 smart-search-cli 作为网络搜索入口
- 输出必须包含来源引用
- 失败必须重试（最多 3 次）
- 关键信息必须验证

❌ **禁止行为**：
- 禁止无来源输出
- 禁止单次放弃
- 禁止未验证假设
- 禁止直接引用 `extra_sources` 作为证据

---

## 📋 变更记录 (Changelog)

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

### 2025-12-13
- 初始化 AI 上下文文档
- 完成项目结构扫描与模块识别
- 生成模块级文档索引
- **补充 Sh/docker 模块文档** - 证书生成流程与续期机制
- **补充 Sh/utils 模块文档** - backup_postgres.sh 配置说明
- **补充 Action 模块文档** - GitHub Actions 工作流说明

---

## 🎯 项目愿景

Demo 是一个个人维护的日常工具脚本仓库,主要服务于 Linux 系统运维、网络配置、Docker 管理、Cloudflare Workers 开发等场景。项目秉持"佛系维护,自用为主"的理念,提供经过实践验证的实用工具。

**设计哲学**:
- 实用优先,解决真实痛点
- 一键执行,降低使用门槛
- 社区友好,支持远程直接运行
- 模块化组织,便于维护与扩展

---

## 🏗️ 架构总览

### 技术栈
- **Shell**: Bash 脚本,适配主流 Linux 发行版(CentOS/Debian/Ubuntu/Alpine)
- **Python**: 3.x,用于复杂逻辑处理和数据转换
- **JavaScript**: Cloudflare Workers 运行时
- **文档工具**: openpyxl、python-docx、olefile

### 核心特性
1. **系统优化**: 系统清理、语言配置、终端美化、swap 管理
2. **网络工具**: 代理部署(HTTP/SOCKS5/Gost)、防火墙配置、NAT64 优选
3. **容器管理**: Docker 安装与 TLS 证书自动配置
4. **边缘计算**: Docker Hub 镜像代理、Telegram Bot API 代理
5. **数据处理**: 多格式题库转换(Excel/Word/Doc → 标准格式)

---

## 🗂️ 模块结构图

```mermaid
graph TD
    A["(根) Demo"] --> B["Sh"];
    B --> C["system"];
    B --> D["network"];
    B --> E["docker"];
    B --> F["utils"];
    A --> G["Work"];
    A --> H["py"];
    A --> I["tiku"];
    A --> J["Action"];
    A --> K["docs"];
    A --> L["lib"];

    click C "./Sh/system/CLAUDE.md" "查看 system 模块文档"
    click D "./Sh/network/CLAUDE.md" "查看 network 模块文档"
    click E "./Sh/docker/CLAUDE.md" "查看 docker 模块文档"
    click F "./Sh/utils/CLAUDE.md" "查看 utils 模块文档"
    click G "./Work/CLAUDE.md" "查看 Work 模块文档"
    click H "./py/CLAUDE.md" "查看 py 模块文档"
    click I "./tiku/CLAUDE.md" "查看 tiku 模块文档"
    click J "./Action/CLAUDE.md" "查看 Action 模块文档"
```

---

## 📚 模块索引

| 模块路径 | 职责 | 语言 | 入口文件 | 配置 |
|---------|------|------|---------|------|
| [Sh/system](./Sh/system/CLAUDE.md) | 系统相关工具脚本 | Shell | cleanup.sh, terminal_optimizer.sh, nat64_optimizer.sh 等 | - |
| [Sh/network](./Sh/network/CLAUDE.md) | 网络配置与代理工具 | Shell | gost.sh, http_install.sh, socks5_install.sh 等 | - |
| [Sh/docker](./Sh/docker/CLAUDE.md) | Docker 安装与证书管理 | Shell | DockerInstallation.sh, docker-ca.sh | ✅ 完整文档 |
| [Sh/utils](./Sh/utils/CLAUDE.md) | 通用工具脚本 | Shell | ssh_key.sh, ChangeMirrors.sh, backup_postgres.sh 等 | ✅ 完整文档 |
| [Work](./Work/CLAUDE.md) | Cloudflare Workers 脚本 | JavaScript | mirror.js, proxy.js, tgapi.js 等 | - |
| [py](./py/CLAUDE.md) | Python 工具脚本 | Python | cc.py | - |
| [tiku](./tiku/CLAUDE.md) | 题库格式转换工具 | Python | convert_all_questions_motibang.py, convert_all_questions_shuatidadang.py | ✅ v1.1.1 |
| [lib](./lib/CLAUDE.md) | 公共库文件 | Shell | common.sh | - |
| [docs](./docs/CLAUDE.md) | 项目文档 | Markdown | structure.md, examples.md, contributing.md | - |
| [Action](./Action/CLAUDE.md) | GitHub Actions 工作流模板 | YAML | docker.yml, sync.yml, repo_sync.yml 等 | ✅ 完整文档 |

---

## 🚀 运行与开发

### 快速开始

**远程直接运行**（推荐）:
```bash
# 示例: 系统清理
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/system/cleanup.sh)

# 示例: Docker 安装
bash <(curl -sSL https://raw.githubusercontent.com/Silentely/Demo/refs/heads/main/Sh/docker/DockerInstallation.sh)
```

**本地克隆运行**:
```bash
git clone https://github.com/Silentely/Demo.git
cd Demo
chmod +x Sh/**/*.sh
./Sh/system/cleanup.sh
```

### 开发环境

**依赖要求**:
- Bash 4.0+
- Python 3.6+ (可选,用于 Python 工具)
- curl, awk, grep 等基础工具

**推荐工具**:
- ShellCheck: Shell 脚本静态分析
- `lib/common.sh`: 统一的颜色定义与日志函数

---

## 🧪 测试策略

### 脚本测试
- **手动测试**: 在多个 Linux 发行版(Debian/Ubuntu/CentOS)上验证
- **安全性**: 所有脚本包含错误处理机制,支持 `-h/--help` 参数
- **回滚**: 关键操作(如配置修改)自动备份原文件

### Python 工具测试
- 运行单元测试(如有):
  ```bash
  python3 -m pytest tests/
  ```

---

## 📝 编码规范

### Shell 脚本规范
1. **头部注释**: 包含脚本用途、版本、作者信息
2. **错误处理**: 使用 `set -e` 或显式错误检查
3. **颜色输出**: 引用 `lib/common.sh` 中的统一颜色定义
4. **参数支持**: 提供 `-h/--help` 帮助信息
5. **依赖检查**: 脚本开始时检查必需命令是否存在

### Python 规范
1. **编码声明**: 文件头包含 `# -*- coding: utf-8 -*-`
2. **文档字符串**: 模块、函数使用 docstring 说明
3. **类型注解**: 关键函数提供类型提示
4. **错误处理**: 使用 try-except 捕获异常并输出友好错误信息

### 提交信息规范
- 格式: `feat/fix/docs/refactor: 简洁描述`
- 示例: `feat(system): 添加 NAT64 优选脚本`

---

## 🤖 AI 使用指引

### 高频任务
1. **添加新脚本**: 参考 `Sh/system/cleanup.sh` 的结构,复用 `lib/common.sh` 函数
2. **调试网络问题**: 查看 `Sh/network/nat64_optimizer.sh` 的日志输出与错误处理
3. **修改 Worker 脚本**: 理解 `Work/mirror.js` 的代理逻辑与 CORS 处理

### 关键路径
- **公共库**: `lib/common.sh` - 所有脚本共享的函数库
- **文档**: `docs/structure.md` - 目录结构说明
- **示例**: `docs/examples.md` - 各脚本使用示例

### 注意事项
- 所有脚本使用简体中文注释
- NAT64 优选脚本 (`nat64_optimizer.sh`) 包含复杂的测速与 DNS 配置逻辑,修改需谨慎
- Python DDoS 测试脚本 (`cc.py`) 仅用于授权安全测试,禁止攻击 .gov 网站

---

## 🔍 相关资源

- **GitHub 仓库**: https://github.com/Silentely/Demo
- **许可证**: MIT License (代码) + CC BY-NC-SA 4.0 (文档)
- **贡献指南**: [docs/contributing.md](./docs/contributing.md)
- **使用示例**: [docs/examples.md](./docs/examples.md)

---

## 📊 项目统计

- **总脚本数**: 26+ Shell 脚本
- **语言分布**: Shell 60%, Python 25%, JavaScript 10%, 其他 5%
- **最活跃模块**: Sh/system (5 星使用频率)
- **测试覆盖**: 手动测试 (多发行版验证)
