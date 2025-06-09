#!/bin/bash
# 脚本用途：
# 检查 black.txt 和 white.txt 中不符合 AdGuard Home 规则语法的规则，
# 并将检查到的错误信息输出到 invalid_rules.txt 文件中。
#
# 注意：本脚本认为以 "!"、"！"（中文感叹号）或 "#" 开头的行为备注信息，
# 不做进一步检查。

OUTPUT="invalid_rules.txt"
# 清空或创建错误输出文件
> "$OUTPUT"

# 要检查的文件列表
FILES=("black.txt" "white.txt")

for file in "${FILES[@]}"; do
  if [ ! -f "$file" ]; then
    echo "文件 $file 不存在" >> "$OUTPUT"
    continue
  fi

  lineno=0
  while IFS= read -r line || [ -n "$line" ]; do
    lineno=$((lineno+1))
    # 去掉前后空格
    trimmed=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    # 跳过空行
    if [ -z "$trimmed" ]; then
      continue
    fi

    # 如果行以 "!"、"！" 或 "#" 开头，则认为是备注信息，跳过检查
    first_char=$(echo "$trimmed" | cut -c1)
    if [[ "$first_char" == "!" || "$first_char" == "！" || "$first_char" == "#" ]]; then
      continue
    fi

    if [[ "$file" == "white.txt" ]]; then
      # white.txt 的规则应以 @@|| 开头
      if [[ "$trimmed" =~ ^@@\|\| ]]; then
        # 检查是否含有 AdGuard Home 不支持的选项，例如 "$app="
        if [[ "$trimmed" == *"\$app="* ]]; then
          echo "$file:$lineno: 规则 \"$trimmed\" 含有不支持的选项 \$app=" >> "$OUTPUT"
        fi
      else
        echo "$file:$lineno: 规则 \"$trimmed\" 不符合白名单规则语法（应以 @@|| 开头或为备注信息）" >> "$OUTPUT"
      fi
    else
      # 对于 black.txt 的规则，非备注行应以 "||" 开头
      if [[ "$trimmed" =~ ^\|\| ]]; then
        # 检查是否含有不支持的选项（如 "$app="）
        if [[ "$trimmed" == *"\$app="* ]]; then
          echo "$file:$lineno: 规则 \"$trimmed\" 含有不支持的选项 \$app=" >> "$OUTPUT"
        fi
      else
        echo "$file:$lineno: 规则 \"$trimmed\" 不符合黑名单规则语法（非备注规则应以 || 开头）" >> "$OUTPUT"
      fi
    fi
  done < "$file"
done

echo "检查完成，错误详情请查看文件：$OUTPUT"