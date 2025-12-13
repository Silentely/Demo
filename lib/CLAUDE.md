[根目录](../CLAUDE.md) > **lib**

---

# lib - 公共库文件

> **模块职责**: 提供所有 Shell 脚本共享的函数库,包括颜色定义、日志函数、错误处理等

---

## 📋 变更记录 (Changelog)

### 2025-12-13
- 初始化模块文档
- 完成公共函数清单

---

## 🎯 模块职责

本模块提供统一的 Shell 脚本工具函数,确保:
- 统一的颜色输出方案
- 标准化的日志函数
- 通用的错误处理机制
- 复用的交互函数

---

## 🚪 入口与启动

### 引用方式
```bash
#!/bin/bash
# 在脚本开头引用公共库
source "$(dirname "$0")/../../lib/common.sh"

# 或使用绝对路径
source "/path/to/lib/common.sh"
```

---

## 🔌 对外接口

### 颜色定义
```bash
COLOR_RED='\033[0;31m'       # 红色(错误)
COLOR_GREEN='\033[0;32m'     # 绿色(成功)
COLOR_YELLOW='\033[1;33m'    # 黄色(警告)
COLOR_BLUE='\033[0;34m'      # 蓝色(信息)
COLOR_CYAN='\033[0;36m'      # 青色(提示)
COLOR_BOLD='\033[1m'         # 粗体
COLOR_NC='\033[0m'           # 无颜色(重置)
```

### 日志函数

#### log_info
```bash
log_info "信息内容"
# 输出: [INFO] 信息内容 (青色)
```

#### log_warn
```bash
log_warn "警告内容"
# 输出: [WARN] 警告内容 (黄色)
```

#### log_error
```bash
log_error "错误内容"
# 输出: [ERROR] 错误内容 (红色,输出到 stderr)
```

#### log_success
```bash
log_success "成功内容"
# 输出: [SUCCESS] 成功内容 (绿色)
```

---

### 错误处理函数

#### error_exit
```bash
error_exit "错误信息"
# 输出错误信息并退出(exit 1)
```

**使用示例**:
```bash
if ! command -v docker &> /dev/null; then
    error_exit "Docker 未安装"
fi
```

---

### 依赖检查函数

#### check_dependency
```bash
check_dependency "命令名"
# 返回 0(成功) 或 1(失败)
```

**使用示例**:
```bash
if check_dependency "curl"; then
    log_success "curl 已安装"
else
    log_warn "curl 未安装,正在安装..."
    apt-get install -y curl
fi
```

---

### 交互函数

#### confirm
```bash
confirm "确认提示信息?"
# 返回 0(用户确认) 或 1(用户取消)
```

**使用示例**:
```bash
if confirm "确认清理系统缓存?"; then
    log_info "开始清理..."
    # 执行清理操作
else
    log_warn "已取消操作"
    exit 0
fi
```

---

### 进度条函数

#### show_progress
```bash
show_progress [持续时间秒数]
# 默认 10 秒
```

**使用示例**:
```bash
log_info "正在下载文件..."
show_progress 5
log_success "下载完成"
```

**输出示例**:
```
进度: [████████████████████░░░░░░░░░░░░] 65%
```

---

### 帮助信息函数

#### show_help
```bash
show_help
# 显示通用帮助信息
```

**输出示例**:
```
用法: script.sh [选项]
选项:
  -h, --help     显示帮助信息
  -v, --version  显示版本信息
```

---

## 🔗 关键依赖与配置

### 系统依赖
- Bash 4.0+
- `echo` 命令支持 `-e` 参数(转义序列)

### 兼容性
- 已测试系统: Debian/Ubuntu/CentOS/Alpine
- 终端: 支持 ANSI 转义序列的终端(xterm/gnome-terminal/iTerm2 等)

---

## 📦 数据模型

无数据模型,仅提供纯函数。

---

## 🧪 测试与质量

### 手动测试
```bash
# 测试日志函数
source lib/common.sh
log_info "这是信息"
log_warn "这是警告"
log_error "这是错误"
log_success "这是成功"

# 测试确认函数
if confirm "测试确认函数?"; then
    echo "用户确认"
else
    echo "用户取消"
fi

# 测试进度条
show_progress 3
```

### 颜色输出测试
```bash
# 测试所有颜色
echo -e "${COLOR_RED}红色${COLOR_NC}"
echo -e "${COLOR_GREEN}绿色${COLOR_NC}"
echo -e "${COLOR_YELLOW}黄色${COLOR_NC}"
echo -e "${COLOR_BLUE}蓝色${COLOR_NC}"
echo -e "${COLOR_CYAN}青色${COLOR_NC}"
echo -e "${COLOR_BOLD}粗体${COLOR_NC}"
```

---

## ❓ 常见问题 (FAQ)

**Q: 颜色输出不生效?**
A: 检查终端是否支持 ANSI 转义序列,或环境变量 `TERM` 设置。

**Q: `source` 命令报 "No such file or directory"?**
A: 确认 `common.sh` 路径正确,建议使用相对路径或绝对路径。

**Q: 进度条显示混乱?**
A: 确保终端宽度足够(建议 ≥ 80 字符),检查是否有其他输出干扰。

**Q: `error_exit` 后脚本未退出?**
A: 确认脚本开头使用了 `#!/bin/bash` 而非 `#!/bin/sh`,某些 shell 可能不支持 `exit`。

---

## 📂 相关文件清单

```
lib/
└── common.sh    # 公共函数库(100行)
```

**函数清单**:
1. 颜色定义(7个)
2. 日志函数(4个)
3. 错误处理函数(1个)
4. 依赖检查函数(1个)
5. 交互函数(1个)
6. 进度条函数(1个)
7. 帮助信息函数(1个)

---

## 🔍 使用此库的模块

- [Sh/system](../Sh/system/CLAUDE.md): 系统工具脚本
- [Sh/network](../Sh/network/CLAUDE.md): 网络工具脚本
- [Sh/docker](../Sh/docker/CLAUDE.md): Docker 工具脚本
- [Sh/utils](../Sh/utils/CLAUDE.md): 通用工具脚本

---

## 🚀 开发指南

### 添加新函数
```bash
# 在 common.sh 末尾添加
my_custom_function() {
    local param1="$1"
    local param2="$2"

    # 函数逻辑
    log_info "执行自定义函数: $param1, $param2"

    return 0
}
```

### 函数命名规范
- 小写字母 + 下划线分隔
- 动词开头(如 `check_`, `log_`, `show_`)
- 见名知意

### 错误处理规范
- 使用 `return 0`(成功) 或 `return 1`(失败)
- 错误信息输出到 `stderr`: `>&2`
- 严重错误使用 `error_exit` 退出

---

**维护者**: Silentely
**最后更新**: 2025-12-13
