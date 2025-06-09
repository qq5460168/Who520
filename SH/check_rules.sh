#!/bin/bash

set -e

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
FILES=("$ROOT_DIR/black.txt" "$ROOT_DIR/white.txt")

for file in "${FILES[@]}"; do
  echo "正在处理文件：$(basename "$file")"

  tmpfile=$(mktemp)

  awk '
  # 保留 # 开头的注释行
  /^#/ { print $0; next }

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
      print "[已删除] " FILENAME ": " $0 > "/dev/stderr"
    } else {
      print $0
    }
  }
  ' "$file" > "$tmpfile"

  mv "$tmpfile" "$file"
  echo "处理完毕：$(basename "$file")"
done

echo "所有错误规则已在运行时输出（未生成 artifacts）"