#!/usr/bin/env bash
# archive.sh — 归档项目级 projects/ 下超过 3 天的总结文件到 archive/projects/
#
# 大白话：这个脚本是 /summarizing 命令的"清理工"。
#   每次你跑 /summarizing 都会自动调用它，把过期总结（3 天前）从 projects/ 移到 archive/。
#   用 mv 而非 rm——文件还在，只是换个目录存着，方便回溯。
#
# 原理：
#   1. 接一个参数：要归档的项目级 projects/ 目录路径
#   2. 截止日期 = 今天 - 3 天（字符串比较 YYYYMMDD 格式）
#   3. 遍历 projects/*.md，文件名前 8 位 ≤ 截止日期则移动
#   4. 移动日志写到 .archive.log
#   5. 无文件需归档时静默退出（不报错）
#
# 用法：
#   bash ~/.claude/skills/summarizing/archive.sh <projects_dir>
#
# 退出码：
#   0 - 成功（或无文件需处理）
#   1 - 参数错误或目录不存在

set -euo pipefail

# 参数校验
PROJECTS_DIR="${1:-}"
if [ -z "$PROJECTS_DIR" ]; then
    echo "错误：缺少参数" >&2
    echo "用法: $0 <projects_dir>" >&2
    exit 1
fi

if [ ! -d "$PROJECTS_DIR" ]; then
    echo "错误：目录不存在: $PROJECTS_DIR" >&2
    exit 1
fi

# 计算截止日期（3 天前）
CUTOFF=$(date -d "3 days ago" +%Y%m%d)

# 归档目录 = projects/ 的兄弟目录 archive/projects/
ARCHIVE_DIR="$(dirname "$PROJECTS_DIR")/archive/projects"
mkdir -p "$ARCHIVE_DIR"

# 遍历移动
count=0
for f in "$PROJECTS_DIR"/*.md; do
    [ -e "$f" ] || continue  # glob 无匹配时跳过（避免空目录报错）
    fname=$(basename "$f")
    date_prefix="${fname:0:8}"

    # 文件名前 8 位必须是 8 位数字
    if [[ "$date_prefix" =~ ^[0-9]{8}$ ]] && [ "$date_prefix" -le "$CUTOFF" ]; then
        mv "$f" "$ARCHIVE_DIR/$fname"
        echo "[$(date +%H:%M:%S)] 归档: $fname" >> "$PROJECTS_DIR/.archive.log"
        count=$((count+1))
    fi
done

echo "归档完成: $count 个文件"
exit 0
