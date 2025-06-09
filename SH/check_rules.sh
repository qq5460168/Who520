#!/bin/bash
# 脚本用途：
# 检查 black.txt 和 white.txt 中不符合 AdGuard Home 规则语法的规则，
# 并将检查到的错误信息输出到 invalid_rules.txt 文件中。
#
# 注意：本脚本认为以 "!"、"！"（中文感叹号）或 "#" 开头的行是备注信息，不作检查。

OUTPUT="invalid_rules.txt"
> "$OUTPUT"  # 清空或创建错误输出文件

FILES=("black.txt" "white.txt")
errors=()  # 使用数组存储错误信息

# 定义 trim 函数，使用 Bash 内置语法去除前后空格
trim() {
  local var="$1"
  # Remove leading and trailing whitespace
  var="${var#"${var%%[![:space:]]*}"}"
  var="${var%"${var##*[![:space:]]}"}"
  echo "$var"
}

# 定义检测不支持选项的函数
check_not_supported() {
  local rule="$1"
  if [[ "$rule" == *"\$app="* ]]; then
    echo " 规则 \"$rule\" 含有不支持的选项 \$app="
  fi
}

lineno=0
for file in "${FILES[@]}"; do
  if [ ! -f "$file" ]; then
    errors+=("文件 $file 不存在")
    continue
  fi
  lineno=0
  while IFS= read -r line || [ -n "$line" ]; do
    lineno=$((lineno+1))
    trimmed=$(trim "$line")
    # 跳过空行
    if [ -z "$trimmed" ]; then
      continue
    fi
    # 如果行以 "!"、"！" 或 "#" 开头，则认为是备注，跳过检查
    first_char="${trimmed:0:1}"
    if [[ "$first_char" == "!" || "$first_char" == "！" || "$first_char" == "#" ]]; then
      continue
    fi

    if [[ "$file" == "white.txt" ]]; then
      # white.txt 的规则应以 @@|| 开头
      if [[ "$trimmed" =~ ^@@\|\| ]]; then
        msg=$(check_not_supported "$trimmed")
        [ -n "$msg" ] && errors+=("$file:$lineno: $msg")
      else
        errors+=("$file:$lineno: 规则 \"$trimmed\" 不符合白名单规则语法（应以 @@|| 开头或为备注信息）")
      fi
    else  # black.txt
      # 黑名单规则应以 || 开头
      if [[ "$trimmed" =~ ^\|\| ]]; then
        msg=$(check_not_supported "$trimmed")
        [ -n "$msg" ] && errors+=("$file:$lineno: $msg")
      else
        errors+=("$file:$lineno: 规则 \"$trimmed\" 不符合黑名单规则语法（非备注规则应以 || 开头）")
      fi
    fi
  done < "$file"
done

# 输出所有错误信息到文件
for err in "${errors[@]}"; do
  echo "$err" >> "$OUTPUT"
done

echo "检查完成，错误详情请查看文件：$OUTPUT"