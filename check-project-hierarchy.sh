#!/usr/bin/env bash
# check-project-hierarchy.sh — 检查当前项目目录的 CLAUDE.md 层级
#
# 大白话：体检脚本。
#   - 对固定的目录（项目根、memory 子目录）：硬性要求，缺失就提醒当事人补建
#   - 对 CLAUDE.md（一级子目录）：只做事实陈述，由当事人判断
#
# 用法：
#   ./check-project-hierarchy.sh                  # 检查当前目录
#   ./check-project-hierarchy.sh /path/to/project  # 检查指定目录
#   ./check-project-hierarchy.sh --help           # 看帮助
#
# 退出码：
#   0 - 全部硬性要求满足
#   1 - 有硬性要求缺失
#   2 - 路径不存在

set -euo pipefail

# ====== 参数解析 ======
TARGET_DIR="$PWD"

for arg in "$@"; do
    case "$arg" in
        -h|--help)
            echo "用法: $0 [项目根路径]"
            echo ""
            echo "硬性要求检查 + CLAUDE.md 事实陈述，由当事人判断"
            exit 0
            ;;
        *)
            if [ -d "$arg" ]; then
                TARGET_DIR="$arg"
            else
                echo "❌ 路径不存在或不是目录: $arg" >&2
                exit 2
            fi
            ;;
    esac
done

log()  { echo "[$(date +%H:%M:%S)] $*"; }
warn() { echo "[$(date +%H:%M:%S)] ⚠️  $*" >&2; }

# 检查路径状态
check_path() {
    local path="$1"
    if [ -e "$path" ]; then
        if [ -d "$path" ]; then
            local count
            count=$(find "$path" -maxdepth 1 -type f 2>/dev/null | wc -l)
            echo "✅ 目录|$count 个文件"
        else
            local lines
            lines=$(wc -l < "$path" 2>/dev/null || echo "0")
            echo "✅ 文件|$lines 行"
        fi
    else
        echo "❌ 缺失|-"
    fi
}

# 加载黑名单（仅参考）
BLACKLIST_FILE="$HOME/claude-template-distribute/blacklist.md"
BLACKLIST=()
if [ -f "$BLACKLIST_FILE" ]; then
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*-[[:space:]]+([a-zA-Z0-9_./\*-]+)/?[[:space:]]*$ ]]; then
            entry="${BASH_REMATCH[1]}"
            entry="${entry%/}"
            BLACKLIST+=("$entry")
        fi
    done < "$BLACKLIST_FILE"
fi

is_blacklisted() {
    local dir_name="$1"
    for entry in "${BLACKLIST[@]}"; do
        if [[ "$dir_name" == "$entry" ]] || [[ "$dir_name" == $entry ]]; then
            return 0
        fi
    done
    return 1
}

# ====== 标题 ======
log ""
log "╔════════════════════════════════════════════════════════════════╗"
log "║ 项目目录 CLAUDE.md 层级检查报告                                ║"
log "╠════════════════════════════════════════════════════════════════╣"
log "║ 项目根：$TARGET_DIR"
log "║ 检查时间：$(date '+%Y-%m-%d %H:%M:%S')"
log "╚════════════════════════════════════════════════════════════════╝"
log ""

# ====== 硬性要求检查（必须全部满足）======
log "【硬性要求】固定目录 + 文件（必须全部存在，缺失会提醒）"
log "----------------------------------------------------------------"
log "| 路径                                              | 状态     | 详情"
log "|--------------------------------------------------|----------|--------"

HARD_MISSING=()

# 目录级硬性要求（7 项）
for spec in \
    "CLAUDE.md|项目根 CLAUDE.md（/init 时建）" \
    ".claude/memory|记忆系统根目录" \
    ".claude/memory/projects|项目总结存放" \
    ".claude/memory/archive/projects|归档目录" \
    ".claude/memory/references|外部引用" \
    ".claude/memory/about-me|个人画像" \
    ".claude/memory/preferences|偏好设置"
do
    IFS='|' read -r sub_path note <<< "$spec"
    status=$(check_path "$TARGET_DIR/$sub_path")
    state=$(echo "$status" | cut -d'|' -f1)
    detail=$(echo "$status" | cut -d'|' -f2)

    printf "| %-48s | %-8s | %s（%s）\n" "$sub_path" "$state" "$detail" "$note"

    if [[ "$state" == "❌ 缺失" ]]; then
        HARD_MISSING+=("$sub_path")
    fi
done

# 文件级硬性要求（13 项）
# 记忆系统根文件（2 个）
for spec in \
    ".claude/memory/MEMORY.md|全局记忆索引" \
    ".claude/memory/_frontmatter-template.md|frontmatter 规范模板"
do
    IFS='|' read -r sub_path note <<< "$spec"
    status=$(check_path "$TARGET_DIR/$sub_path")
    state=$(echo "$status" | cut -d'|' -f1)
    detail=$(echo "$status" | cut -d'|' -f2)

    printf "| %-48s | %-8s | %s（%s）\n" "$sub_path" "$state" "$detail" "$note"

    if [[ "$state" == "❌ 缺失" ]]; then
        HARD_MISSING+=("$sub_path")
    fi
done

# about-me/ 必填（3 个）
for f in profile.md tech-stack.md family.md; do
    sub_path=".claude/memory/about-me/$f"
    status=$(check_path "$TARGET_DIR/$sub_path")
    state=$(echo "$status" | cut -d'|' -f1)
    detail=$(echo "$status" | cut -d'|' -f2)

    printf "| %-48s | %-8s | %s（about-me 占位）\n" "$sub_path" "$state" "$detail"

    if [[ "$state" == "❌ 缺失" ]]; then
        HARD_MISSING+=("$sub_path")
    fi
done

# preferences/ 必填（7 个，不含 Feedback.md）
for f in code-style.md command-style.md engineering-process.md principle.md report-style.md role.md selection-report.md; do
    sub_path=".claude/memory/preferences/$f"
    status=$(check_path "$TARGET_DIR/$sub_path")
    state=$(echo "$status" | cut -d'|' -f1)
    detail=$(echo "$status" | cut -d'|' -f2)

    printf "| %-48s | %-8s | %s（preferences 占位）\n" "$sub_path" "$state" "$detail"

    if [[ "$state" == "❌ 缺失" ]]; then
        HARD_MISSING+=("$sub_path")
    fi
done

# 选填（1 个：Feedback.md）
sub_path=".claude/memory/preferences/Feedback.md"
status=$(check_path "$TARGET_DIR/$sub_path")
state=$(echo "$status" | cut -d'|' -f1)
detail=$(echo "$status" | cut -d'|' -f2)
printf "| %-48s | %-8s | %s（选填，/summarizing 跑后才有）\n" "$sub_path" "$state" "$detail"

log "|--------------------------------------------------|----------|--------"
log ""

# ====== CLAUDE.md 事实陈述（只列，不判断）======
log "【CLAUDE.md 事实陈述】脚本不判断是否应有，由当事人判断"
log "----------------------------------------------------------------"
log "| 子目录                              | CLAUDE.md  | 黑名单"
log "|-------------------------------------|------------|--------"

for subdir in "$TARGET_DIR"/*/ "$TARGET_DIR"/.[!.]*/; do
    [ -d "$subdir" ] || continue
    dir_name=$(basename "$subdir")

    if is_blacklisted "$dir_name"; then
        bl_mark="✅ 黑名单"
    else
        bl_mark="❌ 否"
    fi

    if [ -f "$subdir/CLAUDE.md" ]; then
        printf "| %-35s | ✅ 存在     | %s\n" "$dir_name/" "$bl_mark"
    else
        printf "| %-35s | ❌ 缺失     | %s\n" "$dir_name/" "$bl_mark"
    fi
done

log "|-------------------------------------|------------|--------"
log ""

# ====== 总结 + 当事人判断提醒 ======
log "【总结】"
log "----------------------------------------------------------------"

if [ "${#HARD_MISSING[@]}" -eq 0 ]; then
    log "✅ 硬性要求全部满足"
else
    log "❌ 硬性要求缺失 ${#HARD_MISSING[@]} 项，需补建："
    for m in "${HARD_MISSING[@]}"; do
        log "   - $m"
    done
fi
log ""

log "【当事人判断指南】"
log "----------------------------------------------------------------"
log "✅ 黑名单目录（如 .venv/、__pycache__/）缺失 CLAUDE.md → 正常"
log "❌ 黑名单目录（机器生成）缺失 → 正常"
log "❌ 源码/文档目录（如 src/、docs/、tests/）缺失 CLAUDE.md → 需补建"
log "✅ 源码/文档目录存在 CLAUDE.md → 正确"
log ""
log "判断标准：手动写的目录应该有 CLAUDE.md，机器生成的目录不需要。"
log "补建方法：在缺失目录下手动写 CLAUDE.md，或跑 /init 让 AI 自动建。"
log ""

# 退出码
if [ "${#HARD_MISSING[@]}" -gt 0 ]; then
    exit 1
fi
exit 0