3#!/bin/sh
LC_ALL='C'

rm *.txt

wait
echo '创建临时文件夹'
mkdir -p ./tmp/

#添加补充规则
cp ./data/rules/adblock.txt ./tmp/rules01.txt
cp ./data/rules/whitelist.txt ./tmp/allow01.txt

echo '下载规则'
rules=(
  "https://raw.githubusercontent.com/qq5460168/dangchu/main/black.txt" #5460
  "https://raw.githubusercontent.com/damengzhu/banad/main/jiekouAD.txt" #大萌主
  "https://raw.githubusercontent.com/afwfv/DD-AD/main/rule/DD-AD.txt"  #DD
  "https://raw.githubusercontent.com/Cats-Team/dns-filter/main/abp.txt" #AdRules DNS Filter
  "https://raw.hellogithub.com/hosts" #GitHub加速
  "https://raw.githubusercontent.com/qq5460168/dangchu/main/adhosts.txt" #测试hosts
  "https://raw.githubusercontent.com/qq5460168/dangchu/main/white.txt" #白名单
  "" #
  "https://raw.githubusercontent.com/mphin/AdGuardHomeRules/main/Blacklist.txt" #mphin
  "https://gitee.com/zjqz/ad-guard-home-dns/raw/master/black-list" #周木木
  "https://raw.githubusercontent.com/liwenjie119/adg-rules/master/black.txt" #liwenjie119
  "https://github.com/entr0pia/fcm-hosts/raw/fcm/fcm-hosts" #FCM Hosts
 "https://raw.githubusercontent.com/790953214/qy-Ads-Rule/refs/heads/main/black.txt" #晴雅
  "https://raw.githubusercontent.com/TG-Twilight/AWAvenue-Ads-Rule/main/AWAvenue-Ads-Rule.txt" #秋风规则
   #"https://raw.githubusercontent.com/qq5460168/dangchu/main/T%E7%99%BD%E5%90%8D%E5%8D%95.txt" #T白
   "" #
  "https://raw.githubusercontent.com/tongxin0520/AdFilterForAdGuard/refs/heads/main/KR_DNS_Filter.txt" #tongxin0520
  "https://raw.githubusercontent.com/Zisbusy/AdGuardHome-Rules/refs/heads/main/Rules/blacklist.txt" #Zisbusy

#"https://gh.llkk.cc/https://raw.githubusercontent.com/790953214/qy-Ads-Rule/refs/heads/main/black.txt" #晴雅

"https://raw.githubusercontent.com/Kuroba-Sayuki/FuLing-AdRules/Master/FuLingRules/FuLingBlockList.txt" #茯苓

"https://raw.githubusercontent.com/qq5460168/dangchu/refs/heads/main/%E5%85%94%E5%85%94%E8%87%AA%E7%94%A8%E5%B9%BF%E5%91%8A%E6%8B%A6%E6%88%AA%E8%A7%84%E5%88%99%EF%BC%8C%E7%A6%81%E6%AD%A2%E9%9A%90%E7%A7%81%E6%94%B6%E9%9B%86.txt" #兔兔自用
  
 
 )

allow=(
 "https://raw.githubusercontent.com/qq5460168/dangchu/main/white.txt" #
  "https://raw.githubusercontent.com/mphin/AdGuardHomeRules/main/Allowlist.txt"
  "https://file-git.trli.club/file-hosts/allow/Domains"#冷漠
   "https://raw.githubusercontent.com/user001235/112/main/white.txt" #浅笑
  "https://ghp.ci/https://raw.githubusercontent.com/jhsvip/ADRuls/main/white.txt" #jhsvip
  #"https://mirror.ghproxy.com/raw.githubusercontent.com/8680/GOODBYEADS/master/allow.txt" #8680
  "https://raw.githubusercontent.com/liwenjie119/adg-rules/master/white.txt" #liwenjie119
  "https://raw.githubusercontent.com/qq5460168/dangchu/main/T%E7%99%BD%E5%90%8D%E5%8D%95.txt" #T白名单
  "https://raw.githubusercontent.com/miaoermua/AdguardFilter/main/whitelist.txt" #喵二白名单
  "https://raw.githubusercontent.com/Zisbusy/AdGuardHome-Rules/refs/heads/main/Rules/whitelist.txt" #Zisbusy
 "https://raw.githubusercontent.com/Kuroba-Sayuki/FuLing-AdRules/Master/FuLingRules/FuLingAllowList.txt" #茯苓

"https://raw.githubusercontent.com/qq5460168/dangchu/refs/heads/main/%E5%85%94%E5%85%94%E8%87%AA%E7%94%A8%E5%B9%BF%E5%91%8A%E6%8B%A6%E6%88%AA%E8%A7%84%E5%88%99%EF%BC%8C%E7%A6%81%E6%AD%A2%E9%9A%90%E7%A7%81%E6%94%B6%E9%9B%86.txt" #兔兔自用
      "" #
       "" #
 
 
)

for i in "${!rules[@]}" "${!allow[@]}"
do
  curl -m 60 --retry-delay 2 --retry 5 --parallel --parallel-immediate -k -L -C - -o "rules${i}.txt" --connect-timeout 60 -s "${rules[$i]}" |iconv -t utf-8 &
  curl -m 60 --retry-delay 2 --retry 5 --parallel --parallel-immediate -k -L -C - -o "allow${i}.txt" --connect-timeout 60 -s "${allow[$i]}" |iconv -t utf-8 &
done
wait
echo '规则下载完成'

# 添加空格
file="$(ls|sort -u)"
for i in $file; do
  echo -e '\n' >> $i &
done
wait

echo '处理规则中'

cat | sort -n| grep -v -E "^((#.*)|(\s*))$" \
 | grep -v -E "^[0-9f\.:]+\s+(ip6\-)|(localhost|local|loopback)$" \
 | grep -Ev "local.*\.local.*$" \
 | sed s/127.0.0.1/0.0.0.0/g | sed s/::/0.0.0.0/g |grep '0.0.0.0' |grep -Ev '.0.0.0.0 ' | sort \
 |uniq >base-src-hosts.txt &
wait
cat base-src-hosts.txt | grep -Ev '#|\$|@|!|/|\\|\*'\
 | grep -v -E "^((#.*)|(\s*))$" \
 | grep -v -E "^[0-9f\.:]+\s+(ip6\-)|(localhost|loopback)$" \
 | sed 's/127.0.0.1 //' | sed 's/0.0.0.0 //' \
 | sed "s/^/||&/g" |sed "s/$/&^/g"| sed '/^$/d' \
 | grep -v '^#' \
 | sort -n | uniq | awk '!a[$0]++' \
 | grep -E "^((\|\|)\S+\^)" & #Hosts规则转ABP规则

cat | sed '/^$/d' | grep -v '#' \
 | sed "s/^/@@||&/g" | sed "s/$/&^/g"  \
 | sort -n | uniq | awk '!a[$0]++' & #将允许域名转换为ABP规则

cat | sed '/^$/d' | grep -v "#" \
 |sed "s/^/@@||&/g" | sed "s/$/&^/g" | sort -n \
 | uniq | awk '!a[$0]++' & #将允许域名转换为ABP规则

cat | sed '/^$/d' | grep -v "#" \
 |sed "s/^/0.0.0.0 &/g" | sort -n \
 | uniq | awk '!a[$0]++' & #将允许域名转换为ABP规则

cat *.txt | sed '/^$/d' \
 |grep -E "^\/[a-z]([a-z]|\.)*\.$" \
 |sort -u > l.txt &

cat \
 | sed "s/^/||&/g" | sed "s/$/&^/g" &

cat \
 | sed "s/^/0.0.0.0 &/g" &


echo 开始合并

cat rules*.txt \
 |grep -Ev "^((\!)|(\[)).*" \
 | sort -n | uniq | awk '!a[$0]++' > tmp-rules.txt & #处理AdGuard的规则

cat \
 | grep -E "^[(\@\@)|(\|\|)][^\/\^]+\^$" \
 | grep -Ev "([0-9]{1,3}.){3}[0-9]{1,3}" \
 | sort | uniq > ll.txt &
wait


# 提取以 @@|| 开头并以 ^ 结尾的规则
cat *.txt \
 | grep '^@@||.*\^$' \
 | sort -u > allow_ends_with_caret.txt

# 提取以 @@|| 开头并以 ^$important 结尾的规则
cat *.txt \
 | grep '^@@||.*\^\$important$' \
 | sort -u > allow_ends_with_important.txt

# 合并两种规则到一个文件中
cat allow_ends_with_caret.txt allow_ends_with_important.txt \
 | sort -u > tmp-allow.txt
wait

cp tmp-allow.txt .././allow.txt
cp tmp-rules.txt .././rules.txt

echo 规则合并完成

# Python 处理重复规则
python .././data/python/rule.py
python .././data/python/filter-dns.py

# Start Add title and date
python .././data/python/title.py


wait
echo '更新成功'

exit