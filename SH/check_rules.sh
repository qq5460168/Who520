#!/bin/bash

set -e

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
FILES=("$ROOT_DIR/black.txt" "$ROOT_DIR/white.txt")
ERROR_FILE="$ROOT_DIR/error.txt"

# 初始化错误文件
echo "# 规则检查错误报告" > "$ERROR_FILE"
echo "# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')" >> "$ERROR_FILE"
echo "========================================" >> "$ERROR_FILE"

for file in "${FILES[@]}"; do
  echo "正在处理文件：$(basename "$file")"
  
  tmpfile=$(mktemp)
  error_count=0

  awk -v filename="$(basename "$file")" -v error_file="$ERROR_FILE" '
    BEGIN { 
      print "[" filename "]" >> error_file
    }
    
    # 保留注释行和空行
    /^#/ || /^$/ { 
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
      if (line ~ /^![^ ]/ && line !~ /^! [a-zA-Z]/) return "E4"  # 放宽!规则限制
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
    echo "  └─ 发现 $error_count 条无效规则"
    mv "$tmpfile" "$file"
  else
    rm "$tmpfile"
  fi
done

echo "========================================" >> "$ERROR_FILE"
echo "错误报告已保存至: $ERROR_FILE"
echo "处理完成，所有错误规则已记录至 error.txt"