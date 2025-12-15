[根目录](../CLAUDE.md) > **tiku**

---

# tiku - 题库格式转换工具

> **模块职责**: 提供多格式题库文件转换功能,支持 Excel、Word、Doc 格式,输出为标准导入模板

---

## 📋 变更记录 (Changelog)

### 2025-12-15
- **v1.1.0 重大更新**
  - 新增 argparse CLI 参数解析（`--version`, `-v/--verbose`, `--dry-run`, `-o/--output`）
  - 新增数据质量验证功能（题干/选项/答案完整性检查）
  - 优化文件编码检测（只读取 8KB 头部，大文件性能提升）
  - 增强错误处理（失败/跳过文件收集与汇总报告）
  - 双脚本功能同步，版本号统一为 v1.1.0

### 2025-12-13
- 初始化模块文档
- 完成脚本清单与接口说明

---

## 🎯 模块职责

本模块包含题库格式转换工具,主要功能:
- 解析多种格式题库文件(Excel/Word/Doc/纯文本)
- 自动识别题型(单选/多选/判断/填空/简答)
- 规范化答案格式
- 输出为标准导入模板(磨题帮/刷题搭档)

**支持题型**:
- 单选题
- 多选题
- 判断题
- 填空题
- 简答题

---

## 🚪 入口与启动

### 主要脚本入口

| 脚本名 | 版本 | 功能 | 输出格式 |
|-------|------|------|---------|
| `convert_all_questions_motibang.py` | v1.1.0 | 多格式转磨题帮模板 | 磨题帮 Excel 模板 |
| `convert_all_questions_shuatidadang.py` | v1.1.0 | 多格式转刷题搭档模板 | 刷题搭档 Excel 模板 |

### 使用示例
```bash
# 查看版本
python3 convert_all_questions_motibang.py --version

# 转换指定文件
python3 convert_all_questions_motibang.py 我的题库.xlsx 另一个题库.docx

# 转换当前目录所有 Excel 文件
python3 convert_all_questions_motibang.py *.xlsx

# 详细模式（显示验证警告）
python3 convert_all_questions_motibang.py -v 题库.xlsx

# 仅验证不输出文件（干运行模式）
python3 convert_all_questions_motibang.py --dry-run 题库.xlsx

# 指定输出目录
python3 convert_all_questions_motibang.py -o /path/to/output 题库.xlsx

# 显示帮助
python3 convert_all_questions_motibang.py --help
```

---

## 🔌 对外接口

### 命令行参数 (v1.1.0)
```bash
python3 convert_all_questions_motibang.py [选项] [文件1] [文件2] ...

选项:
  -h, --help      显示帮助信息
  --version       显示版本号
  -v, --verbose   详细模式，显示验证警告信息
  --dry-run       仅解析验证，不输出文件
  -o, --output    指定输出目录（默认为文件所在目录）
```

### 输出报告格式 (v1.1.0 新增)
```
============================================================
转换报告
============================================================
处理题目总数: 1234 道

✓ 成功生成文件 (3 个):
  - 题库1_磨题帮.xlsx
  - 题库2_磨题帮.xlsx

⚠ 数据质量警告: 15 个
  (使用 -v 参数查看详细警告信息)

✗ 处理失败 (1 个):
  - 损坏的文件.xlsx: 解析失败或无题目

○ 已跳过 (2 个):
  - 不存在.xlsx: 文件不存在
  - 图片.png: 不支持的格式
============================================================
```

### 支持的输入格式
- `.xlsx` - Excel 文件(推荐)
- `.docx` - Word 文档
- `.doc` - 旧版 WPS/Word 文档
- `.txt` - 纯文本文件

### 输出格式

**磨题帮模板** (`convert_all_questions_motibang.py`):
```
| 题干 | 题型 | 选择项1 | ... | 选择项10 | 答案 | 解析 | 得分 |
```

**刷题搭档模板** (`convert_all_questions_shuatidadang.py`):
(根据实际需求调整列结构)

### 题型映射规则
| 原始题型 | 输出题型 | 答案格式 |
|---------|---------|---------|
| 单选题 | 选择题 | A/B/C/D |
| 多选题 | 选择题 | AB/ABC/BCD |
| 判断题 | 判断题 | 对/错 |
| 填空题 | 填空题 | 答案1\|\|答案2 |
| 简答题 | 简答题 | 文本答案 |

---

## 🔗 关键依赖与配置

### Python 依赖
```bash
# 必需依赖
pip install openpyxl          # Excel 读写
pip install python-docx        # Word 文档解析
pip install olefile            # 旧版 .doc 文件解析
```

### 系统要求
- Python 3.6+
- 内存: ≥ 512MB(处理大型题库时)

---

## 📦 数据模型

### 题目对象结构
```python
{
    'question': '题干内容',
    'type': '单选题',  # 单选题/多选题/判断题/填空题/简答题
    'options': {       # 仅选择题有此字段
        'A': '选项A内容',
        'B': '选项B内容',
        'C': '选项C内容',
        'D': '选项D内容'
    },
    'answer': 'A',     # 答案(选择题:A/AB/BCD; 判断题:对/错)
    'answers': [],     # 填空题多个答案
    'raw_answer': '',  # 原始答案字符串
    'source': '文件名' # 来源文件基础名(不含扩展名)
}
```

### 特定文件解析器
```python
# 针对特定格式的题库文件
parse_mid_level_excel()       # 车辆检修工练习题-中级.xlsx
parse_2024_summary_excel()    # 2-车辆题库汇总2024.xlsx
parse_doc_file()              # 题库1.doc
parse_crh6_docx()             # CRH6集团竞赛题库.docx

# 通用解析器
parse_generic_excel()         # 通用 Excel 文件
parse_generic_docx()          # 通用 Word 文档
parse_text_file()             # 纯文本文件
```

---

## 🧪 测试与质量

### 数据质量验证 (v1.1.0 新增)

脚本内置 `validate_question()` 函数，自动检测以下问题：

| 验证项 | 严重性 | 说明 |
|-------|-------|------|
| 题干为空或过短 | ⚠️ 警告 | 题干少于 2 个字符 |
| 选择题无选项 | ⚠️ 警告 | 单选/多选题缺少选项 |
| 选择题选项不足 | ⚠️ 警告 | 选项数量少于 2 个 |
| 选择题缺少答案 | ⚠️ 警告 | 答案字段为空 |
| 填空题缺少答案 | ⚠️ 警告 | answers 列表为空 |

使用 `-v` 参数可查看详细验证警告：
```bash
python3 convert_all_questions_motibang.py -v 题库.xlsx
# 输出示例:
# ⚠ 验证警告 (第 15 题): 选择题选项数量不足
# ⚠ 验证警告 (第 23 题): 题干为空或过短
```

### 字符规范化测试
```python
# 全角 → 半角转换
normalize_text("Ａ１．")  # → "A1."
normalize_text("（对）")  # → "(对)"
normalize_text("，、：")  # → ",、:"
```

### 判断题答案规范化
支持的输入格式:
- 正确: `Y/YES/T/TRUE/1/对/正确/√/✓/是`
- 错误: `N/NO/F/FALSE/0/错/错误/×/✗/否`

统一输出: `对` 或 `错`

### 题型自动识别测试
```python
# 有选项 → 选择题
"1. 题干内容 A. 选项A B. 选项B 答案:(A)"

# 有判断答案 → 判断题
"1. 题干内容。答案:(√)"

# 有空格占位符 → 填空题
"1. ____是Python的优点。答案:简洁"

# 有问号 → 简答题
"1. 简述Python的优点？"
```

---

## ❓ 常见问题 (FAQ)

**Q: 解析 Excel 时部分题目丢失?**
A: 检查文件格式是否标准,确保题干/选项/答案列对应正确。可尝试使用通用解析器。

**Q: 判断题答案识别错误?**
A: 确认原始答案格式是否在支持列表中,可手动调整为 `对`/`错` 或 `√`/`×`。

**Q: 多选题答案顺序错乱?**
A: 脚本会自动按选项字母顺序重新映射(A-J),原始答案 `ABCD` 会保持相对顺序。

**Q: .doc 文件解析失败?**
A: 旧版 .doc 文件格式复杂,解析成功率依赖文件规范程度。建议转为 .docx 或手动整理。

**Q: 输出文件名冲突?**
A: 输出文件名格式为 `原文件名_磨题帮.xlsx`,如已存在会覆盖。建议备份原文件。

**Q: 填空题答案分隔符不统一?**
A: 脚本自动识别并统一为 `||` 分隔符,支持输入的分隔符:`,`/`，`/`、`/`;`/`；`

---

## 📂 相关文件清单

```
tiku/
├── convert_all_questions_motibang.py        # 磨题帮转换脚本 v1.1.0 (1300+ 行)
├── convert_all_questions_shuatidadang.py    # 刷题搭档转换脚本 v1.1.0
├── motibang_template1_磨题帮.xlsx           # 磨题帮模板示例
└── shuatidadang_question_刷题搭档.xlsx      # 刷题搭档模板示例
```

**关键文件**:
- `convert_all_questions_motibang.py`: 功能最完善，支持多种解析器、智能题型识别、数据验证

---

## 🔍 核心算法

### 选项提取正则
```python
# 匹配选项格式: A. / A、/ A: / A．
option_pattern = r'([A-L])[、.．:：]\s*([^\s]+(?:\s+[^\sA-L][^\s]*)*)'
```

### 题号分割正则
```python
# 匹配题号: 1. / 1、/ 1) / (1)
split_pattern = r'\n\s*(?=\d+[、.．:：\)\)]\s|\(\d+\)|\【\d+\】)'
```

### 答案提取正则
```python
# 匹配答案标记: 答案:(A) / 答案:A / 答案:(A,B)
answer_pattern = r'答案[：:]\s*[（(]\s*([A-Za-z,，\s]+)\s*[）)]'
```

---

## 🚀 开发指南

### 添加新的解析器
```python
def parse_my_custom_format(file_path):
    """
    自定义格式解析器
    返回: List[Dict] - 题目对象列表
    """
    questions = []

    # 1. 读取文件
    # 2. 解析题目
    # 3. 规范化数据

    return questions

# 注册到 get_parser_for_file() 函数
```

### 扩展题型支持
```python
# 在 parse_text_question() 中添加新题型检测逻辑
if '新题型特征' in text:
    return {
        'question': question,
        'type': '新题型',
        'answer': answer
    }
```

---

## 🔍 相关模块

- [py](../py/CLAUDE.md): Python 工具脚本
- [docs](../docs/CLAUDE.md): 项目文档

---

**维护者**: Silentely
**最后更新**: 2025-12-15
