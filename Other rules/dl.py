import os
import re
import subprocess
import time
import shutil
from pathlib import Path
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed, Future

# 配置常量
MAX_WORKERS = 5  # 并发下载数量
TIMEOUT = 60      # 超时时间(秒)
RETRY = 5         # 重试次数
RETRY_DELAY = 2   # 重试间隔(秒)
ENCODING = "utf-8"  # 目标编码

# 路径计算（基于脚本绝对路径）
SCRIPT_DIR = Path(__file__).resolve().parent
ROOT_DIR = SCRIPT_DIR.parent.parent.parent  # 项目根目录
TMP_DIR = ROOT_DIR / "tmp"                  # 临时目录
ADBLOCK_SUPPLEMENT = ROOT_DIR / "data/mod/adblock.txt"  # 补充规则
WHITELIST_SUPPLEMENT = ROOT_DIR / "data/mod/whitelist.txt"  # 补充白名单

# 日志函数
def log(msg: str):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] [DL] {msg}")

# 1. 初始化环境
def init_env():
    # 清理临时目录
    if TMP_DIR.exists():
        shutil.rmtree(TMP_DIR, ignore_errors=True)
    TMP_DIR.mkdir(parents=True, exist_ok=True)
    log(f"初始化临时目录成功: {TMP_DIR}")

    # 清理根目录旧规则
    for file in ["adblock.txt", "allow.txt", "rules.txt"]:
        file_path = ROOT_DIR / file
        if file_path.exists():
            file_path.unlink()
            log(f"清理旧规则文件: {file}")

    # 复制补充规则
    if ADBLOCK_SUPPLEMENT.exists():
        shutil.copy2(ADBLOCK_SUPPLEMENT, TMP_DIR / "rules01.txt")
        log(f"复制补充拦截规则: rules01.txt")
    else:
        log(f"警告: 补充拦截规则不存在 {ADBLOCK_SUPPLEMENT}")

    if WHITELIST_SUPPLEMENT.exists():
        shutil.copy2(WHITELIST_SUPPLEMENT, TMP_DIR / "allow01.txt")
        log(f"复制补充白名单规则: allow01.txt")
    else:
        log(f"警告: 补充白名单规则不存在 {WHITELIST_SUPPLEMENT}")

# 2. 下载函数（支持并发）
def download_url(url: str, save_path: Path) -> bool:
    """下载单个URL并转码"""
    try:
        # 构造curl命令
        cmd = [
            "curl",
            "-m", str(TIMEOUT),
            "--retry", str(RETRY),
            "--retry-delay", str(RETRY_DELAY),
            "-k", "-L", "-C", "-",  # 忽略证书、跟随重定向、断点续传
            "--connect-timeout", str(TIMEOUT),
            "-s", url
        ]

        # 执行命令并处理输出
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=False  # 先按字节流处理
        )

        if result.returncode != 0:
            log(f"[ERROR] 下载失败 {url} (返回码: {result.returncode})")
            return False

        # 转码处理（兼容多种编码）
        content = None
        for encoding in ["utf-8", "latin-1", "gbk"]:
            try:
                content = result.stdout.decode(encoding)
                break
            except UnicodeDecodeError:
                continue
        if content is None:
            log(f"[ERROR] 转码失败 {url}")
            return False

        # 写入文件（确保末尾有换行）
        with open(save_path, "w", encoding=ENCODING) as f:
            f.write(content.rstrip() + "\n")  # 统一处理换行

        log(f"[INFO] 下载成功 {url.split('/')[-1]} -> {save_path.name}")
        return True

    except Exception as e:
        log(f"[ERROR] 下载异常 {url}: {str(e)}")
        return False

# 3. 并发下载规则
def download_rules(concurrent: int = MAX_WORKERS):
    # 规则URL列表
    rules_urls = [
        "https://raw.githubusercontent.com/qq5460168/dangchu/main/black.txt", #5460
        "https://raw.githubusercontent.com/damengzhu/banad/main/jiekouAD.txt", #大萌主
        "https://raw.githubusercontent.com/afwfv/DD-AD/main/rule/DD-AD.txt",  #DD
        "https://raw.githubusercontent.com/Cats-Team/dns-filter/main/abp.txt", #AdRules DNS Filter
        "https://raw.hellogithub.com/hosts", #GitHub加速
        "https://raw.githubusercontent.com/qq5460168/dangchu/main/adhosts.txt", #测试hosts
        "https://raw.githubusercontent.com/qq5460168/dangchu/main/white.txt", #白名单
        "https://raw.githubusercontent.com/qq5460168/Who520/refs/heads/main/Other%20rules/Replenish.txt",#补充
        "https://raw.githubusercontent.com/mphin/AdGuardHomeRules/main/Blacklist.txt", #mphin
        "https://gitee.com/zjqz/ad-guard-home-dns/raw/master/black-list", #周木木
        "https://raw.githubusercontent.com/liwenjie119/adg-rules/master/black.txt", #liwenjie119
        "https://github.com/entr0pia/fcm-hosts/raw/fcm/fcm-hosts", #FCM Hosts
        "https://raw.githubusercontent.com/790953214/qy-Ads-Rule/refs/heads/main/black.txt", #晴雅
        "https://raw.githubusercontent.com/TG-Twilight/AWAvenue-Ads-Rule/main/AWAvenue-Ads-Rule.txt", #秋风规则
        "https://raw.githubusercontent.com/2Gardon/SM-Ad-FuckU-hosts/refs/heads/master/SMAdHosts", #下一个ID见
        "https://raw.githubusercontent.com/tongxin0520/AdFilterForAdGuard/refs/heads/main/KR_DNS_Filter.txt", #tongxin0520
        "https://raw.githubusercontent.com/Zisbusy/AdGuardHome-Rules/refs/heads/main/Rules/blacklist.txt", #Zisbusy
        "", # 空行（跳过下载）
        "https://raw.githubusercontent.com/Kuroba-Sayuki/FuLing-AdRules/refs/heads/main/FuLingRules/FuLingBlockList.txt", #茯苓
        "https://raw.githubusercontent.com/Kuroba-Sayuki/FuLing-AdRules/refs/heads/main/FuLingRules/FuLingAllowList.txt", #茯苓白名单
        "", # 空行（跳过下载）
    ]

    # 白名单URL列表
    allow_urls = [
        "https://raw.githubusercontent.com/qq5460168/dangchu/main/white.txt",
        "https://raw.githubusercontent.com/mphin/AdGuardHomeRules/main/Allowlist.txt",
        "https://file-git.trli.club/file-hosts/allow/Domains", #冷漠
        "https://raw.githubusercontent.com/user001235/112/main/white.txt", #浅笑
        "https://raw.githubusercontent.com/jhsvip/ADRuls/main/white.txt", #jhsvip
        "https://raw.githubusercontent.com/liwenjie119/adg-rules/master/white.txt", #liwenjie119
        "https://raw.githubusercontent.com/miaoermua/AdguardFilter/main/whitelist.txt", #喵二白名单
        "https://raw.githubusercontent.com/Zisbusy/AdGuardHome-Rules/refs/heads/main/Rules/whitelist.txt", #Zisbusy
        "https://raw.githubusercontent.com/Kuroba-Sayuki/FuLing-AdRules/refs/heads/main/FuLingRules/FuLingAllowList.txt", #茯苓
        "https://raw.githubusercontent.com/urkbio/adguardhomefilter/main/whitelist.txt", #酷安cocieto
        "",# 空行（跳过下载）
        "" # 空行（跳过下载）
    ]

    # 并发下载规则（跳过空字符串URL）
    log("\n开始下载拦截规则...")
    with ThreadPoolExecutor(max_workers=concurrent) as executor:
        futures = []
        for i, url in enumerate(rules_urls, start=2):  # 从2开始编号（1是补充规则）
            if not url.strip():  # 跳过空URL
                continue
            save_path = TMP_DIR / f"rules{i:02d}.txt"
            try:
                # 提交任务并验证返回类型
                future = executor.submit(download_url, url, save_path)
                if not isinstance(future, Future):
                    log(f"[WARNING] 任务返回非Future对象，类型={type(future)}，URL={url}")
                    continue
                futures.append(future)
            except Exception as e:
                log(f"[ERROR] 提交任务失败（{url}）：{str(e)}")
        
        # 等待所有任务完成并处理异常
        for future in as_completed(futures):
            try:
                future.result()  # 获取结果以捕获可能的异常
            except Exception as e:
                log(f"[ERROR] 任务执行异常：{str(e)}")

    # 并发下载白名单（跳过空字符串URL）
    log("\n开始下载白名单规则...")
    with ThreadPoolExecutor(max_workers=concurrent) as executor:
        futures = []
        for i, url in enumerate(allow_urls, start=2):
            if not url.strip():  # 跳过空URL
                continue
            save_path = TMP_DIR / f"allow{i:02d}.txt"
            try:
                future = executor.submit(download_url, url, save_path)
                if not isinstance(future, Future):
                    log(f"[WARNING] 任务返回非Future对象，类型={type(future)}，URL={url}")
                    continue
                futures.append(future)
            except Exception as e:
                log(f"[ERROR] 提交任务失败（{url}）：{str(e)}")
        
        # 等待所有任务完成并处理异常
        for future in as_completed(futures):
            try:
                future.result()  # 获取结果以捕获可能的异常
            except Exception as e:
                log(f"[ERROR] 任务执行异常：{str(e)}")

# 4. 规则预处理
def process_rules():
    log("\n开始预处理规则...")

    # 合并所有规则文件
    all_rules = []
    for file in TMP_DIR.glob("*.txt"):
        try:
            with open(file, "r", encoding=ENCODING) as f:
                all_rules.extend(f.readlines())
        except Exception as e:
            log(f"[ERROR] 读取文件失败 {file}: {str(e)}")

    # 过滤与转换
    filtered = []
    for line in all_rules:
        line = line.strip()
        # 过滤注释行和空行
        if not line or line.startswith(("#", "!", "[")):
            continue
        # 过滤无效IP规则
        if re.match(r"^[0-9f\.:]+\s+(ip6\-|localhost|local|loopback)$", line):
            continue
        if re.match(r"local.*\.local.*$", line):
            continue
        # 转换IP格式
        line = line.replace("127.0.0.1", "0.0.0.0").replace("::", "0.0.0.0")
        # 保留有效的hosts规则
        if "0.0.0.0" in line and ".0.0.0.0 " not in line:
            filtered.append(line)

    # 去重并保存基础规则
    unique_rules = sorted(list(set(filtered)))
    base_hosts = TMP_DIR / "base-src-hosts.txt"
    with open(base_hosts, "w", encoding=ENCODING) as f:
        f.write("\n".join(unique_rules) + "\n")
    log(f"生成基础规则 {base_hosts.name}（{len(unique_rules)} 条）")

    # 提取AdGuard规则
    adblock_rules = []
    for line in all_rules:
        line = line.strip()
        if line and not line.startswith(("#", "!", "[")):
            adblock_rules.append(line)
    adblock_unique = sorted(list(set(adblock_rules)))
    tmp_rules = TMP_DIR / "tmp-rules.txt"
    with open(tmp_rules, "w", encoding=ENCODING) as f:
        f.write("\n".join(adblock_unique) + "\n")
    log(f"生成拦截规则 {tmp_rules.name}（{len(adblock_unique)} 条）")

    # 提取白名单规则
    allow_rules = []
    for line in all_rules:
        line = line.strip()
        if re.match(r"^@@\|\|.*\^(\$important)?$", line):
            allow_rules.append(line)
    
    # 保存白名单规则
    allow_unique = sorted(list(set(allow_rules)))
    tmp_allow = TMP_DIR / "tmp-allow.txt"
    with open(tmp_allow, "w", encoding=ENCODING) as f:
        f.write("\n".join(allow_unique) + "\n")
    log(f"生成白名单规则 {tmp_allow.name}（{len(allow_unique)} 条）")

# 主函数
def main():
    try:
        log("===== 开始规则下载与处理流程 =====")
        init_env()
        download_rules()
        process_rules()
        log("===== 规则下载与处理流程完成 =====")
    except Exception as e:
        log(f"[ERROR] 主流程失败: {str(e)}")
        exit(1)

if __name__ == "__main__":
    main()