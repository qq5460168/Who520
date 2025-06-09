#!/bin/bash

set -e

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
FILES=("$ROOT_DIR/black.txt" "$ROOT_DIR/white.txt")
REPORT_DIR="$ROOT_DIR/rule_reports"
ERROR_FILE="$REPORT_DIR/error.txt"
FORMATTED_ERROR_FILE="$REPORT_DIR/formatted-error.md"
LOG_FILE="$REPORT_DIR/rule-check.log"

# 创建报告目录
mkdir -p "$REPORT_DIR"

# 初始化文件
echo "# 规则检查错误报告" > "$ERROR_FILE"
echo "# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')" >> "$ERROR_FILE"
echo "# 报告位置: $REPORT_DIR" >> "$ERROR_FILE"
echo "========================================" >> "$ERROR_FILE"

echo "# 规则检查日志" > "$LOG_FILE"
echo "## 开始时间: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# 创建格式化错误报告
echo "# 规则检查错误报告" > "$FORMATTED_ERROR_FILE"
echo "## 生成时间: $(date '+%Y-%m-%d %H:%M:%S')" >> "$FORMATTED_ERROR_FILE"
echo "" >> "$FORMATTED_ERROR_FILE"
echo "## 错误代码说明" >> "$FORMATTED_ERROR_FILE"
echo "| 代码 | 描述 |" >> "$FORMATTED_ERROR_FILE"
echo "|------|------|" >> "$FORMATTED_ERROR_FILE"
echo "| E1 | 无效的 .c 域名后缀 |" >> "$FORMATTED_ERROR_FILE"
echo "| E2 | 包含 .comqq^ 的错误格式 |" >> "$FORMATTED_ERROR_FILE"
echo "| E3 | 连续 ^^ 符号 |" >> "$FORMATTED_ERROR_FILE"
echo "| E5 | 无效的通配符组合 *- |" >> "$FORMATTED_ERROR_FILE"
echo "| E6 | 包含 qq.comqq 的错误格式 |" >> "$FORMATTED_ERROR_FILE"
echo "| E7 | 包含 .comc^ 的错误格式 |" >> "$FORMATTED_ERROR_FILE"
echo "" >> "$FORMATTED_ERROR_FILE"
echo "## 错误详情" >> "$FORMATTED_ERROR_FILE"

for file in "${FILES[@]}"; do
  echo "### 正在处理文件: $(basename "$file")" | tee -a "$LOG_FILE"

  error_count=0

  awk -v filename="$(basename "$file")" -v error_file="$ERROR_FILE" -v formatted_file="$FORMATTED_ERROR_FILE" '
    BEGIN {
      print "[" filename "]" >> error_file
      print "### " filename >> formatted_file
    }
    # 跳过注释和空行
    /^#/ || /^!/ || /^$/ { next }
    function is_error(line) {
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
        printf "%s\tL%d\t%s\n", err_code, NR, $0 >> error_file
        printf("- **%s** - 行号: %d  \n  `%s`\n\n", err_code, NR, $0) >> formatted_file
      }
    }
  ' "$file"

  # 统计错误数量
  error_count=$(awk -v fname="$(basename "$file")" '$0 ~ fname {c++} END{print c+0}' "$ERROR_FILE")

  if [[ $error_count -gt 0 ]]; then
    echo "  - 发现 $error_count 条无效规则" | tee -a "$LOG_FILE"
  else
    echo "  - 未发现无效规则" | tee -a "$LOG_FILE"
    echo "无错误" >> "$FORMATTED_ERROR_FILE"
  fi

  echo "" >> "$FORMATTED_ERROR_FILE"
done

# 添加统计信息
echo "## 处理结果统计" >> "$LOG_FILE"
echo "### 错误规则总数: $(grep -cE '^E[0-9]' "$ERROR_FILE" || echo 0)" >> "$LOG_FILE"
echo "### 按错误类型统计:" >> "$LOG_FILE"
awk -F '\t' '{print $1}' "$ERROR_FILE" | grep -E '^E[0-9]' | sort | uniq -c | sort -nr >> "$LOG_FILE"

echo "" >> "$LOG_FILE"
echo "## 报告文件" >> "$LOG_FILE"
echo "- [错误报告]($ERROR_FILE)" >> "$LOG_FILE"
echo "- [格式化错误报告]($FORMATTED_ERROR_FILE)" >> "$LOG_FILE"
echo "- [完整日志]($LOG_FILE)" >> "$LOG_FILE"

# 添加完成时间
echo "========================================" >> "$ERROR_FILE"
echo "处理完成时间: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_FILE"
echo "错误报告位置: $ERROR_FILE" | tee -a "$LOG_FILE"
echo "格式化报告位置: $FORMATTED_ERROR_FILE" | tee -a "$LOG_FILE"
