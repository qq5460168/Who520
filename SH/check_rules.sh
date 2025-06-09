#!/bin/bash
# 自动检测规则语法错误，错误项写入 error.txt，并从原文件中删除

# 支持批量检测（默认 black.txt 和 white.txt）
files=("$@")
if [ ${#files[@]} -eq 0 ]; then
  files=("black.txt" "white.txt")
fi

# 错误规则集中写入 error.txt
> error.txt

for file in "${files[@]}"; do
  echo "正在处理文件：$file"
  tmpfile=$(mktemp)

  awk '
  # 错误规则匹配正则
  function is_error(line) {
    # 域名不完整
    if (line ~ /\|\|[a-zA-Z0-9\-\*\.]+\.c(\^|$)/) return 1
    if (line ~ /\|\|[a-zA-Z0-9\-\*\.]+\.comqq\^/) return 1
    if (line ~ /\|\|[a-zA-Z0-9\-\*\.]+\.\^[\$\^]?/) return 1
    # 有 ^^
    if (line ~ /\^\^/) return 1
    # !后直接跟规则
    if (line ~ /^![^ ]/ && line !~ /^! /) return 1
    # 多余通配符
    if (line ~ /\*\-.*\*/) return 1
    # 明显拼写错误
    if (line ~ /(qq\.comqq|\.c\^|\.comqq\^)/) return 1
    # 非法字符（高位字节）
    if (line ~ /[\x80-\xFF]/) return 1
    # 域名后缀不完整
    if (line ~ /\|\|[a-zA-Z0-9\-\*\.]+\.c\^/) return 1
    if (line ~ /\|\|[a-zA-Z0-9\-\*\.]+\.co\^/) return 1
    if (line ~ /\|\|[a-zA-Z0-9\-\*\.]+\.comc\^/) return 1
    return 0
  }
  {
    if (is_error($0)) {
      print $0 >> "error.txt"
    } else {
      print $0
    }
  }
  ' "$file" > "$tmpfile"

  # 替换原文件
  mv "$tmpfile" "$file"
  echo "已删除错误规则，并写入 error.txt"
done

echo "全部处理完成。"