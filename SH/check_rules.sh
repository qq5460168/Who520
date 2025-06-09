#!/bin/bash
set -euo pipefail

# 获取根目录（如果是 Git 仓库则取仓库根目录，否则使用当前目录）
ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
FILES=("$ROOT_DIR/black.txt" "$ROOT_DIR/white.txt")
REPORT_DIR="$ROOT_DIR/rule_reports"
ERROR_FILE="$REPORT_DIR/error.txt"
FORMATTED_ERROR_FILE="$REPORT_DIR/formatted-error.md"
LOG_FILE="$REPORT_DIR/rule-check.log"

# 创建报告目录
mkdir -p "$REPORT_DIR"

# 初始化错误报告文件
cat > "$ERROR_FILE" <<EOF
# 规则检查错误报告
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')
# 报告位置: $REPORT_DIR
========================================
EOF

# 初始化日志文件
cat > "$LOG_FILE" <<EOF
# 规则检查日志
## 开始时间: $(date '+%Y-%m-%d %H:%M:%S')

EOF

# 初始化格式化错误报告文件
cat > "$FORMATTED_ERROR_FILE" <<EOF
# 规则检查错误报告
## 生成时间: $(date '+%Y-%m-%d %H:%M:%S')

## 错误代码说明
| 代码 | 描述 |
|------|------|
| E1 | 无效的 .c 域名后缀 |
| E2 | 包含 .comqq^ 的错误格式 |
| E3 | 连续 ^^ 符号 |
| E5 | 无效的通配符组合 *- |
| E6 | 包含 qq.comqq 的错误格式 |
| E7 | 包含 .comc^ 的错误格式 |

## 错误详情
EOF

# 遍历处理每个规则文件
for file in "${FILES[@]}"; do
    filename="$(basename "$file")"
    echo "### 正在处理文件: $filename" | tee -a "$LOG_FILE"
    
    awk -v fname="$filename" -v err_file="$ERROR_FILE" -v fmt_file="$FORMATTED_ERROR_FILE" '
    BEGIN {
        print "[" fname "]" >> err_file
        print "### " fname >> fmt_file
    }
    # 跳过注释和空行
    /^#/ || /^!/ || /^$/ { next }
    function is_error(line) {
        # 如果规则为合法的 .c 或 .co 格式则不返回错误 (返回 0)
        if (line ~ /\|\|[a-zA-Z0-9\-\*\.]+\.c\^[\$]?/) return 0
        if (line ~ /\|\|[a-zA-Z0-9\-\*\.]+\.co\^[\$]?/) return 0
        if (line ~ /\|\|[a-zA-Z0-9\-\*\.]+\.c(\^|$)/) return "E1"
        if (line ~ /\|\|[a-zA-Z0-9\-\*\.]+\.comqq\^/) return "E2"
        if (line ~ /\^\^/) return "E3"
        if (line ~ /\*\-.*\*/) return "E5"
        if (line ~ /(qq\.comqq|\.comqq\^)/) return "E6"
        if (line ~ /\|\|[a-zA-Z0-9\-\*\.]+\.comc\^/) return "E7"
        return 0
    }
    {
        err_code = is_error($0)
        if (err_code) {
            printf "%s\tL%d\t%s\n", err_code, NR, $0 >> err_file
            printf("- **%s** - 行号: %d  \n  `%s`\n\n", err_code, NR, $0) >> fmt_file
        }
    }
    ' "$file"
    
    # 统计当前文件错误数量（统计 ERROR_FILE 中以 E 开头的错误行）
    error_count=$(grep -E "^E[0-9]" "$ERROR_FILE" | wc -l)
    
    if [[ $error_count -gt 0 ]]; then
        echo "  - 发现 $error_count 条无效规则" | tee -a "$LOG_FILE"
    else
        echo "  - 未发现无效规则" | tee -a "$LOG_FILE"
        echo "无错误" >> "$FORMATTED_ERROR_FILE"
    fi
    
    echo "" >> "$FORMATTED_ERROR_FILE"
done

# 添加统计信息到日志文件
{
    echo "## 处理结果统计"
    echo "### 错误规则总数: $(grep -cE '^E[0-9]' "$ERROR_FILE" || echo 0)"
    echo "### 按错误类型统计:"
    awk -F '\t' '{print $1}' "$ERROR_FILE" | grep -E '^E[0-9]' | sort | uniq -c | sort -nr
    echo ""
    echo "## 报告文件"
    echo "- [错误报告]($ERROR_FILE)"
    echo "- [格式化错误报告]($FORMATTED_ERROR_FILE)"
    echo "- [完整日志]($LOG_FILE)"
} >> "$LOG_FILE"

echo "========================================" >> "$ERROR_FILE"
{
    echo "处理完成时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "错误报告位置: $ERROR_FILE"
    echo "格式化报告位置: $FORMATTED_ERROR_FILE"
} | tee -a "$LOG_FILE"