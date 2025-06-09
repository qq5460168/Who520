#!/bin/bash

# 获取 git 仓库根目录
ROOT_DIR="$(git rev-parse --show-toplevel)"
ERROR_FILE="$ROOT_DIR/error.txt"

# 检查主目录下的 black.txt 和 white.txt
FILES=("$ROOT_DIR/black.txt" "$ROOT_DIR/white.txt")

# 清空 error.txt
> "$ERROR_FILE"

for file in "${FILES[@]}"; do
  echo "正在处理文件：$file"
  tmpfile=$(mktemp)

  awk -v ERROR_FILE="$ERROR_FILE" '
  function is_error(line) {
    if (line ~ /\|\|[a-zA-Z0-9\-\*\.]+\.c(\^|$)/) return 1
    if (line ~ /\|\|[a-zA-Z0-9\-\*\.]+\.comqq\^/) return 1
    if (line ~ /\|\|[a-zA-Z0-9\-\*\.]+\.\^[\$\^]?/) return 1
    if (line ~ /\^\^/) return 1
    if (line ~ /^![^ ]/ && line !~ /^! /) return 1
    if (line ~ /\*\-.*\*/) return 1
    if (line ~ /(qq\.comqq|\.c\^|\.comqq\^)/) return 1
    if (line ~ /[\x80-\xFF]/) return 1
    if (line ~ /\|\|[a-zA-Z0-9\-\*\.]+\.c\^/) return 1
    if (line ~ /\|\|[a-zA-Z0-9\-\*\.]+\.co\^/) return 1
    if (line ~ /\|\|[a-zA-Z0-9\-\*\.]+\.comc\^/) return 1
    return 0
  }
  {
    if (is_error($0)) {
      print $0 >> ERROR_FILE
    } else {
      print $0
    }
  }
  ' "$file" > "$tmpfile"

  mv "$tmpfile" "$file"
  echo "已删除错误规则，写入 $ERROR_FILE"
done

echo "全部处理完成。"
