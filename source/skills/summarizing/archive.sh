#!/usr/bin/env bash
# archive.sh — 归档项目级 projects/ 下超过 1 天的总结文件到 archive/projects/
#
# 大白话：这个脚本是 /summarizing 命令的"清理工"。
#   每次你跑 /summarizing 都会自动调用它，把过期总结（1 天前）从 projects/ 移到 archive/。
#   用 mv 而非 rm——文件还在，只是换个目录存着，方便回溯。
#   装了 lancedb 的话，移动前会把总结全文存进 ~/.lancedb/summaries/（可选增强，没装就跳过）。
#
# 原理：
#   1. 接一个参数：要归档的项目级 projects/ 目录路径
#   2. 截止日期 = 今天 - 1 天（字符串比较 YYYYMMDD 格式）
#   3. 遍历 projects/*.md，文件名前 8 位 ≤ 截止日期则移动
#   4. 移动前若 lancedb 可用，调 archive_to_lancedb.py 写入全文（失败静默跳过）
#   5. 移动日志写到 .archive.log
#   6. 无文件需归档时静默退出（不报错）
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

# 计算截止日期（1 天前）
CUTOFF=$(date -d "1 day ago" +%Y%m%d)

# LanceDB 可用性探测（可选增强：没装 lancedb 就全程跳过，不影响归档）
LANCEDB_OK=false
LANCEDB_SCRIPT=""
if command -v python3 >/dev/null 2>&1 && python3 -c "import lancedb" >/dev/null 2>&1; then
    LANCEDB_OK=true
    LANCEDB_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/archive_to_lancedb.py"
fi

# 项目名：从 projects/ 路径向上推三级得项目根目录，取目录名
PROJECT_NAME="$(basename "$(dirname "$(dirname "$(dirname "$PROJECTS_DIR")")")")"

# 归档目录 = projects/ 的兄弟目录 archive/projects/
ARCHIVE_DIR="$(dirname "$PROJECTS_DIR")/archive/projects"
mkdir -p "$ARCHIVE_DIR"

# 遍历移动
count=0
lancedb_count=0
for f in "$PROJECTS_DIR"/*.md; do
    [ -e "$f" ] || continue  # glob 无匹配时跳过（避免空目录报错）
    fname=$(basename "$f")
    date_prefix="${fname:0:8}"

    # 文件名前 8 位必须是 8 位数字
    if [[ "$date_prefix" =~ ^[0-9]{8}$ ]] && [ "$date_prefix" -le "$CUTOFF" ]; then
        # 移动前先写 LanceDB（可选增强，写失败静默跳过）
        if [ "$LANCEDB_OK" = true ] && [ -f "$LANCEDB_SCRIPT" ]; then
            if python3 "$LANCEDB_SCRIPT" "$PROJECT_NAME" "$f" >/dev/null 2>&1; then
                lancedb_count=$((lancedb_count+1))
            fi
        fi
        mv "$f" "$ARCHIVE_DIR/$fname"
        echo "[$(date +%H:%M:%S)] 归档: $fname" >> "$PROJECTS_DIR/.archive.log"
        count=$((count+1))
    fi
done

echo "归档完成: $count 个文件"
if [ "$LANCEDB_OK" = true ]; then
    echo "LanceDB 写入: $lancedb_count 个"
fi
exit 0
