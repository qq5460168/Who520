#!/bin/bash

set -e

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
FILES=("$ROOT_DIR/black.txt" "$ROOT_DIR/white.txt")
REPORT_DIR="$ROOT_DIR/rule_reports"
ERROR_FILE="$REPORT_DIR/error.txt"
LOG_FILE="$REPORT_DIR/rule-check.log"

# 创建报告目录
mkdir -p "$REPORT_DIR"

# 初始化错误文件
echo "# 规则检查错误报告" > "$ERROR_FILE"
echo "# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')" >> "$ERROR_FILE"
echo "# 报告位置: $REPORT_DIR" >> "$ERROR_FILE"
echo "========================================" >> "$ERROR_FILE"

# 初始化日志文件
echo "# 规则检查日志" > "$LOG_FILE"
echo "# 开始时间: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"

for file in "${FILES[@]}"; do
  echo "正在处理文件：$(basename "$file")" | tee -a "$LOG_FILE"
  
  tmpfile=$(mktemp)
  error_count=0

  awk -v filename="$(basename "$file")" -v error_file="$ERROR_FILE" '
    BEGIN { 
      print "[" filename "]" >> error_file
    }
    
    # 保留注释行、备注行和空行
    /^#/ || /^!/ || /^$/ { 
      print $0
      next 
    }
    
    function is_error(line) {
      # 修复域名后缀误判（允许 .c^/.co^ 等有效格式）
      if (line ~ /\|\|[a-zA-Z0-9\-\*\.]+\.c\^[\$]?/) return 0
      if (line ~ /\|\|[a-zA-Z0-9\-\*\.]+\.co\^[\$]?/) return 0
      
      # 错误模式检测
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
        # 记录错误到文件（格式：错误类型 行号 原始内容）
        printf "%s\tL%d\t%s\n", err_code, NR, $0 >> error_file
        next
      }
      print $0
    }
  ' "$file" > "$tmpfile"
  
  # 统计错误数量
  error_count=$(grep -c "$(basename "$file")" "$ERROR_FILE" || true)
  
  if [[ $error_count -gt 0 ]]; then
    echo "  └─ 发现 $error_count 条无效规则" | tee -a "$LOG_FILE"
    mv "$tmpfile" "$file"
  else
    echo "  └─ 未发现无效规则" | tee -a "$LOG_FILE"
    rm "$tmpfile"
  fi
done

# 添加错误统计到日志
echo "## 错误规则统计 ##" >> "$LOG_FILE"
grep -cE '^E[0-9]' "$ERROR_FILE" | xargs -I {} echo "错误规则总数: {}" >> "$LOG_FILE"
echo "按错误类型统计:" >> "$LOG_FILE"
awk -F '\t' '{print $1}' "$ERROR_FILE" | grep -E '^E[0-9]' | sort | uniq -c | sort -nr >> "$LOG_FILE"

# 添加完成时间
echo "========================================" >> "$ERROR_FILE"
echo "错误报告位置: $ERROR_FILE" | tee -a "$LOG_FILE"
echo "日志文件位置: $LOG_FILE" | tee -a "$LOG_FILE"
echo "处理完成时间: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_FILE"