#!/usr/bin/env bash
# setup-claude-template.sh — 一键分发 claude 记忆系统模板到全新环境
#
# 大白话：这是个"开箱即用"脚本。
#   把 ~/claude-template-distribute/source/ 下的所有模板
#   复制到目标用户的 ~/.claude/ 和 ~/.claude/memory/。
#   带 6 条防呆：检测 claude/备份/确认/dry-run/about-me 不覆盖/CLAUDE.md 追加。
#
# 用法：
#   ./setup-claude-template.sh           # 默认（带交互确认）
#   ./setup-claude-template.sh --dry-run # 演练（显示将做什么，不真做）
#   ./setup-claude-template.sh --force   # 跳过所有确认（仅调试用）
#
# 退出码：
#   0 - 成功
#   1 - 环境检测失败
#   2 - 用户取消操作
#   3 - 复制过程失败
#
# ====== 📋 幂等性审计表（v1.6 新增） ======
# 脚本遵循 CLAUDE.md 第 5 条"幂等性"约束。除 ~/.claude/CLAUDE.md 智能追加外，
# 其他所有操作均"存在则跳过，无则创建"，重复运行结果一致：
#
# | Step | 目标                              | 幂等策略                              |
# |------|-----------------------------------|---------------------------------------|
# | 1.4  | 关键文件检测                       | 不创建文件，只读源校验                |
# | 2    | backup（memory/、summarizing.md、init-template.md） | 已存在则 mv/cp 备份后缀 .bak-YYYYMMDD  |
# | 3    | mkdir memory/{about-me,preferences}、commands/     | mkdir -p 已存在不报错                  |
# | 4    | preferences/*.md、MEMORY.md        | ⚠️ 覆盖式（用户要求保留 v1.5 行为）     |
# | 5    | about-me/{profile,tech,family}    | ✅ 已存在且非空 → 跳过；空/不存在 → 复制 |
# | 6    | commands/{summarizing,init-template}.md + skills/ | ⚠️ 覆盖式（脚本即命令本身，需保持最新） |
# | 6.5  | blacklist.md                      | ✅ 缺失或内容不一致 → 覆盖；一致 → 跳过 |
# | 6.6  | Harness架构.md                    | ✅ 已存在 → 跳过覆盖（保护用户手改）   |
# | 6.7  | 初始化要求.md、记忆系统架构.md      | ✅ 已存在 → 跳过覆盖（保护用户手改）   |
# | 7    | ~/.claude/CLAUDE.md                | 🔀 智能追加（grep 标记检测，避免重复） |
#
# ✅ = 严格幂等   ⚠️ = 覆盖式幂等（运行结果一致，但内容可能更新）   🔀 = 智能追加

set -euo pipefail

# ====== 配置 ======
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_HOME="${HOME:-/root}"
BACKUP_DATE="$(date +%Y%m%d)"

# ====== 工具函数（log/warn/err 提前定义） ======
# 提前到配置区之后：系统目录检测块会调用 warn，定义必须先于调用
log()  { echo "[$(date +%H:%M:%S)] $*"; }
warn() { echo "[$(date +%H:%M:%S)] ⚠️  $*" >&2; }
err()  { echo "[$(date +%H:%M:%S)] ❌ $*" >&2; }

# ====== ⚠️ 使用前必读（前置提示） ======
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Claude Code 模板分发脚本 v1.6                              ║"
echo "╠════════════════════════════════════════════════════════════╣"
echo "║  📁 使用要求：                                              ║"
echo "║    1. source/ 目录必须与本脚本位于同一目录                   ║"
echo "║       ✅ 正确: ~/tools/claude-template-distribute/setup-*.sh ║"
echo "║                 ~/tools/claude-template-distribute/source/  ║"
echo "║       ❌ 错误: 仅复制 setup-*.sh 到其他目录执行              ║"
echo "║    2. 推荐放在项目根目录的上一级（用户家目录下）              ║"
echo "║    3. 不要放在 /usr /etc /var /opt 等系统目录                ║"
echo "║       （会警告提示，但脚本不会终止——你有最终决定权）         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# ====== 系统目录检测（宽松模式：仅警告，不退出） ======
SYSTEM_DIR_REGEX='^/(usr|etc|var|opt|bin|sbin|lib)/'
if [[ "$SCRIPT_DIR" =~ $SYSTEM_DIR_REGEX ]]; then
    warn "⚠️  检测到脚本位于系统目录: $SCRIPT_DIR"
    warn "    系统目录通常用于安装系统软件包，不建议存放用户脚本"
    warn "    推荐位置: ~/tools/ 或 ~/projects/ 或 ~/.local/share/"
    warn "    脚本将继续执行——如果你确定这是临时测试，可忽略此警告"
    echo ""
fi

# ====== 参数解析 ======
DRY_RUN=false
FORCE=false
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --force)   FORCE=true ;;
        -h|--help)
            echo "用法: $0 [--dry-run] [--force]"
            echo "  --dry-run  仅显示将做什么"
            echo "  --force    跳过所有确认"
            exit 0
            ;;
        *)
            echo "未知参数: $arg" >&2
            exit 1
            ;;
    esac
done

# ====== 工具函数 ======
# log/warn/err 已上移至配置区之后（系统目录检测块会调用 warn，定义必须先于调用）

confirm() {
    local prompt="$1"
    if [ "$FORCE" = true ]; then
        log "[force] 跳过确认: $prompt"
        return 0
    fi
    if [ ! -t 0 ]; then
        # 非交互式终端（管道输入）默认 y，避免卡住
        log "[非交互] 自动确认: $prompt"
        return 0
    fi
    read -r -p "$prompt [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]]
}

run_cmd() {
    local desc="$1"
    shift
    if [ "$DRY_RUN" = true ]; then
        log "[dry-run] $desc"
        log "[dry-run]   命令: $*"
    else
        log "$desc"
        "$@"
    fi
}

# 备份目标名递增：先试 .bak-YYYYMMDD，已存在则追加 -2/-3 序号
# 解决同一天重跑时 mv 目标已存在导致的嵌套备份/失败（set -e 中止）
next_backup_name() {
    local base="$1"
    local candidate="${base}.bak-${BACKUP_DATE}"
    local n=2
    while [ -e "$candidate" ]; do
        candidate="${base}.bak-${BACKUP_DATE}-${n}"
        n=$((n + 1))
    done
    printf '%s' "$candidate"
}

# ====== 源目录多路径查找（4 优先级） ======
# 优先级 1：脚本身边 source/（整包复制场景）
# 优先级 2：$HOME/claude-template-distribute/source/（标准安装位置）
# 优先级 3：$CLAUDE_TEMPLATE_HOME/source/（环境变量覆盖）
# 优先级 4：全部失败 → 报错并提示修法
SOURCE_DIR=""
if [ -d "$SCRIPT_DIR/source" ]; then
    SOURCE_DIR="$SCRIPT_DIR/source"
    log "✅ 源目录命中: 脚本身边 ($SOURCE_DIR)"
elif [ -d "$HOME/claude-template-distribute/source" ]; then
    SOURCE_DIR="$HOME/claude-template-distribute/source"
    log "✅ 源目录命中: 家目录默认 ($SOURCE_DIR)"
elif [ -n "${CLAUDE_TEMPLATE_HOME:-}" ] && [ -d "$CLAUDE_TEMPLATE_HOME/source" ]; then
    SOURCE_DIR="$CLAUDE_TEMPLATE_HOME/source"
    log "✅ 源目录命中: CLAUDE_TEMPLATE_HOME ($SOURCE_DIR)"
else
    err "❌ 找不到 source/ 目录（4 优先级全部失败）"
    err ""
    err "请按以下顺序检查："
    err "  1. 脚本身边是否有 source/ 目录？（整包复制）"
    err "  2. \$HOME/claude-template-distribute/source/ 是否存在？"
    err "  3. 是否设置了 CLAUDE_TEMPLATE_HOME 环境变量？"
    err "     export CLAUDE_TEMPLATE_HOME=~/your-tool-dir"
    err ""
    err "常见解法："
    err "  - 在标准位置解压: tar xzf claude-template-distribute.tar.gz -C ~/"
    err "  - 或者设置环境变量告诉脚本 source/ 在哪"
    exit 1
fi

# 模板分发包根目录（用于复制 blacklist.md 等顶层文件）
DIST_ROOT="$(dirname "$SOURCE_DIR")"
log "📦 分发包根目录: $DIST_ROOT"

# ====== Step 1: 环境检测 ======
log "===== Step 1: 环境检测 ====="

# 1.1 检测 claude 命令
if ! command -v claude >/dev/null 2>&1; then
    err "未检测到 claude 命令，请先安装 Claude Code"
    err "安装: https://docs.claude.com/en/docs/claude-code/installation"
    exit 1
fi
log "✅ 检测到 claude: $(command -v claude)"

# 1.2 检测目标 ~/.claude/ 可写
if [ ! -d "$TARGET_HOME/.claude" ]; then
    err "目标目录不存在: $TARGET_HOME/.claude"
    err "请先运行 claude 一次以初始化"
    exit 1
fi
if [ ! -w "$TARGET_HOME/.claude" ]; then
    err "目标目录不可写: $TARGET_HOME/.claude"
    exit 1
fi
log "✅ 目标目录可写: $TARGET_HOME/.claude"

# 1.3 检测源目录
if [ ! -d "$SOURCE_DIR" ]; then
    err "源目录不存在: $SOURCE_DIR"
    exit 1
fi
log "✅ 源目录存在: $SOURCE_DIR"

# 1.4 检测关键文件
for f in "$SOURCE_DIR/memory/MEMORY.md" "$SOURCE_DIR/memory/_frontmatter-template.md" \
         "$SOURCE_DIR/commands/summarizing.md" "$SOURCE_DIR/commands/init-template.md" \
         "$SOURCE_DIR/skills/summarizing/SKILL.md" \
         "$SOURCE_DIR/skills/summarizing/archive.sh"; do
    if [ ! -f "$f" ]; then
        err "源文件缺失: $f"
        exit 1
    fi
done
log "✅ 所有关键源文件存在"

# ====== Step 2: 备份现有文件 ======
log ""
log "===== Step 2: 备份现有文件 ====="

MEMORY_DIR="$TARGET_HOME/.claude/memory"
MEMORY_BAK=""  # 本次 memory/ 备份目标（用于完成日志的恢复提示）
if [ -d "$MEMORY_DIR" ]; then
    MEMORY_BAK="$(next_backup_name "$MEMORY_DIR")"
    warn "检测到现有 memory/ 目录: $MEMORY_DIR"
    if confirm "将备份为 $MEMORY_BAK，是否继续？"; then
        run_cmd "备份现有 memory/" mv "$MEMORY_DIR" "$MEMORY_BAK"
    else
        err "用户取消"
        exit 2
    fi
else
    log "memory/ 不存在，跳过备份"
fi

# 备份已有 commands/summarizing.md
if [ -f "$TARGET_HOME/.claude/commands/summarizing.md" ]; then
    warn "检测到现有 commands/summarizing.md"
    if confirm "将备份为 .bak-${BACKUP_DATE}，是否继续？"; then
        run_cmd "备份 summarizing.md" \
            cp "$TARGET_HOME/.claude/commands/summarizing.md" \
               "$TARGET_HOME/.claude/commands/summarizing.md.bak-${BACKUP_DATE}"
    else
        log "用户选择不备份"
    fi
fi

# 备份已有 commands/init-template.md
if [ -f "$TARGET_HOME/.claude/commands/init-template.md" ]; then
    warn "检测到现有 commands/init-template.md"
    if confirm "将备份为 .bak-${BACKUP_DATE}，是否继续？"; then
        run_cmd "备份 init-template.md" \
            cp "$TARGET_HOME/.claude/commands/init-template.md" \
               "$TARGET_HOME/.claude/commands/init-template.md.bak-${BACKUP_DATE}"
    else
        log "用户选择不备份"
    fi
fi

# 备份已有 skills/summarizing/
if [ -d "$TARGET_HOME/.claude/skills/summarizing" ]; then
    SKILLS_BAK="$(next_backup_name "$TARGET_HOME/.claude/skills/summarizing")"
    warn "检测到现有 skills/summarizing/"
    if confirm "将备份为 $SKILLS_BAK，是否继续？"; then
        run_cmd "备份 skills/summarizing/" \
            mv "$TARGET_HOME/.claude/skills/summarizing" "$SKILLS_BAK"
    fi
fi

# ====== Step 3: 复制目录结构 ======
log ""
log "===== Step 3: 复制目录结构 ====="

run_cmd "创建 memory/ 目录" mkdir -p "$MEMORY_DIR"
run_cmd "创建 about-me/ 目录" mkdir -p "$MEMORY_DIR/about-me"
run_cmd "创建 preferences/ 目录" mkdir -p "$MEMORY_DIR/preferences"
run_cmd "创建 commands/ 目录" mkdir -p "$TARGET_HOME/.claude/commands"
run_cmd "创建 skills/summarizing/ 目录" \
    mkdir -p "$TARGET_HOME/.claude/skills/summarizing"

# ====== Step 4: 复制 memory 文件（覆盖）======
log ""
log "===== Step 4: 复制 memory 文件 ====="

# preferences/ 全覆盖（7 个占位：不含 Feedback.md）
# 注意：Feedback.md 由项目级 /summarizing 命令动态创建（项目根/.claude/memory/preferences/Feedback.md），
# 不分发到全局 memory/。原因：踩坑记录是项目特定的，不应污染全局。
if confirm "将覆盖 preferences/*.md（7 个文件，不含 Feedback 占位），确认？"; then
    # 用 find 排除 Feedback.md，复制其余 7 个
    # 必须用 bash -c + 函数传参，否则 find 的 -name 引号会被 run_cmd 的 log "$*" 误解析
    run_cmd "复制 preferences/*.md（排除 Feedback.md）" \
        bash -c 'find "$1" -maxdepth 1 -name "*.md" ! -name "Feedback.md" -exec cp {} "$2/" \;' _ \
            "$SOURCE_DIR/memory/preferences" "$MEMORY_DIR/preferences"
fi

# MEMORY.md 和 _frontmatter-template.md
run_cmd "复制 MEMORY.md" cp "$SOURCE_DIR/memory/MEMORY.md" "$MEMORY_DIR/MEMORY.md"
run_cmd "复制 _frontmatter-template.md" cp "$SOURCE_DIR/memory/_frontmatter-template.md" "$MEMORY_DIR/_frontmatter-template.md"

# ====== Step 5: about-me/ 骨架保护（不覆盖已有内容）======
log ""
log "===== Step 5: 处理 about-me/ 骨架 ====="

# 简化版两步逻辑：
# - 目标文件已存在且非空 → 跳过（保护用户真实信息）
# - 目标文件不存在或为空 → 复制骨架
# 之前的"从备份恢复"伪逻辑已删除（同一次脚本刚 mv 出来的备份等于 mv 前状态）

for f in profile.md tech-stack.md family.md; do
    target="$MEMORY_DIR/about-me/$f"
    if [ -f "$target" ] && [ -s "$target" ]; then
        warn "$target 已存在且非空，跳过覆盖（保护用户内容）"
        continue
    fi
    run_cmd "复制骨架 $f" cp "$SOURCE_DIR/memory/about-me/$f" "$target"
done

# ====== Step 6: 复制 commands + skills ======
log ""
log "===== Step 6: 复制 commands + skills ====="

run_cmd "复制 commands/summarizing.md" \
    cp "$SOURCE_DIR/commands/summarizing.md" "$TARGET_HOME/.claude/commands/summarizing.md"

run_cmd "复制 commands/init-template.md" \
    cp "$SOURCE_DIR/commands/init-template.md" "$TARGET_HOME/.claude/commands/init-template.md"

run_cmd "复制 skills/summarizing/SKILL.md" \
    cp "$SOURCE_DIR/skills/summarizing/SKILL.md" "$TARGET_HOME/.claude/skills/summarizing/SKILL.md"

run_cmd "复制 skills/summarizing/archive.sh" \
    cp "$SOURCE_DIR/skills/summarizing/archive.sh" "$TARGET_HOME/.claude/skills/summarizing/archive.sh"

run_cmd "设置 archive.sh 可执行" \
    chmod +x "$TARGET_HOME/.claude/skills/summarizing/archive.sh"

# ====== Step 6.5: 安装 blacklist.md 到工具目录 ======
log ""
log "===== Step 6.5: 安装 blacklist.md ====="

BLACKLIST_TARGET="$HOME/claude-template-distribute/blacklist.md"
BLACKLIST_SOURCE="$DIST_ROOT/blacklist.md"

# 创建工具目录（如果不在标准位置）
run_cmd "创建 blacklist 工具目录" mkdir -p "$(dirname "$BLACKLIST_TARGET")"

if [ -f "$BLACKLIST_SOURCE" ]; then
    # 复制或更新 blacklist.md（总用最新版，覆盖）
    # 防呆：标准位置运行时源与目标是同一文件（cp 会报"同一文件"退出码 1 → set -e 中止），
    # 因此先判断：目标不存在或内容不一致时才复制
    if [ ! -f "$BLACKLIST_TARGET" ] || ! cmp -s "$BLACKLIST_SOURCE" "$BLACKLIST_TARGET"; then
        run_cmd "安装 blacklist.md 到 $BLACKLIST_TARGET" \
            cp "$BLACKLIST_SOURCE" "$BLACKLIST_TARGET"
        log "📋 blacklist.md 已就绪（~/.claude/CLAUDE.md 第 3 条固定引用此路径）"
    else
        log "📋 blacklist.md 已就绪且内容一致，跳过复制"
    fi
else
    warn "未找到 $BLACKLIST_SOURCE，跳过 blacklist.md 安装"
    warn "~/.claude/CLAUDE.md 第 3 条引用 ~/claude-template-distribute/blacklist.md 可能失效"
fi

# ====== Step 6.6: 安装 Harness架构.md 到 ~/.claude/ ======
log ""
log "===== Step 6.6: 安装 Harness架构.md ====="

HARNESS_TARGET="$TARGET_HOME/.claude/Harness架构.md"
HARNESS_SOURCE="$DIST_ROOT/Harness架构.md"

if [ -f "$HARNESS_SOURCE" ]; then
    if [ -f "$HARNESS_TARGET" ]; then
        warn "$HARNESS_TARGET 已存在，跳过覆盖（保护用户内容）"
        log "如需更新，请手动 cp $HARNESS_SOURCE $HARNESS_TARGET"
    else
        run_cmd "安装 Harness架构.md 到 $HARNESS_TARGET" \
            cp "$HARNESS_SOURCE" "$HARNESS_TARGET"
        log "📋 Harness架构.md 已就绪（~/.claude/CLAUDE.md Harness 章节固定引用此路径）"
    fi
else
    warn "未找到 $HARNESS_SOURCE，跳过 Harness架构.md 安装"
    warn "~/.claude/CLAUDE.md Harness 章节引用 ~/.claude/Harness架构.md 可能失效"
fi

# ====== Step 6.7: 安装 初始化要求.md / 记忆系统架构.md 到 ~/.claude/ ======
log ""
log "===== Step 6.7: 安装 初始化要求.md / 记忆系统架构.md ====="

for doc in "初始化要求.md" "记忆系统架构.md"; do
    DOC_SOURCE="$DIST_ROOT/$doc"
    DOC_TARGET="$TARGET_HOME/.claude/$doc"
    if [ -f "$DOC_SOURCE" ]; then
        if [ -f "$DOC_TARGET" ]; then
            warn "$DOC_TARGET 已存在，跳过覆盖（保护用户内容）"
            log "如需更新，请手动 cp $DOC_SOURCE $DOC_TARGET"
        else
            run_cmd "安装 $doc 到 $DOC_TARGET" \
                cp "$DOC_SOURCE" "$DOC_TARGET"
            log "📋 $doc 已就绪（~/.claude/$doc）"
        fi
    else
        warn "未找到 $DOC_SOURCE，跳过 $doc 安装"
    fi
done

# ====== Step 7: CLAUDE.md 追加分发包内嵌内容 ======
log ""
log "===== Step 7: 处理 ~/.claude/CLAUDE.md ====="

DIST_CLAUDE_MD="$DIST_ROOT/CLAUDE.md"   # 分发包内嵌的 CLAUDE.md（你本机最新版）

# 检查分发包内嵌 CLAUDE.md 是否存在
if [ ! -f "$DIST_CLAUDE_MD" ]; then
    err "未找到分发包内嵌 CLAUDE.md: $DIST_CLAUDE_MD"
    err "请将本机 ~/.claude/CLAUDE.md 复制到分发包根目录"
    err "  cp ~/.claude/CLAUDE.md $DIST_ROOT/CLAUDE.md"
    exit 1
fi

# 找目标 CLAUDE.md（忽略大小写兼容）
# Linux 文件系统大小写敏感：CLAUDE.md / claude.md / Claude.md / CLAUDE.MD 都是不同文件
# 脚本依次查找，找到第一个就停
CLAUDE_MD=""
for variant in "CLAUDE.md" "claude.md" "Claude.md" "CLAUDE.MD" "CLAUDE_md" "claude_MD"; do
    candidate="$TARGET_HOME/.claude/$variant"
    if [ -f "$candidate" ]; then
        CLAUDE_MD="$candidate"
        log "🔍 找到目标 CLAUDE.md: $candidate"
        break
    fi
done

# 标准化输出文件名（用于显示）—— 用文件实际名
if [ -n "$CLAUDE_MD" ]; then
    FOUND_NAME="$(basename "$CLAUDE_MD")"
else
    FOUND_NAME="CLAUDE.md"  # 即将创建的文件名（默认用此名）
fi

# ====== CLAUDE.md 处理（4 选项 + 标记机制 + 失败降级）======
# 标记常量：重复运行脚本时检测此标记，若存在则全部 CLAUDE.md 操作无效
MARKER="<!-- CLAUDE_TEMPLATE_INSTALLED -->"
PWD_CLAUDE_MD="$PWD/CLAUDE.md"

# 探测可读 / 可写状态
CAN_READ_GLOBAL=false
CAN_WRITE_GLOBAL=false
HAS_MARKER=false

if [ -n "$CLAUDE_MD" ]; then
    [ -r "$CLAUDE_MD" ] && CAN_READ_GLOBAL=true
    [ -w "$CLAUDE_MD" ] && CAN_WRITE_GLOBAL=true
    grep -qF "$MARKER" "$CLAUDE_MD" 2>/dev/null && HAS_MARKER=true
fi

# 如果全局 CLAUDE.md 已含标记 → 全部操作无效（包括追加）
if [ "$HAS_MARKER" = true ]; then
    log "🚫 $FOUND_NAME 已含安装标记 $MARKER"
    log "   重复运行脚本不会再修改 CLAUDE.md（如需更新请手动编辑或删除标记）"
else
    if [ -n "$CLAUDE_MD" ]; then
        # 已存在 → 先备份（无论后面做什么）
        BAK_NAME="${FOUND_NAME}.bak-${BACKUP_DATE}"
        run_cmd "备份目标 $FOUND_NAME" cp "$CLAUDE_MD" "$TARGET_HOME/.claude/$BAK_NAME"

        # 展示 4 选项（按可读 / 可写动态调整）
        log ""
        log "📋 $FOUND_NAME 已存在，选择处理方式："
        log "  1) 跳过（不动 CLAUDE.md）"
        if [ "$CAN_WRITE_GLOBAL" = true ]; then
            log "  2) 覆盖 ~/.claude/CLAUDE.md（替换整个文件，⚠️ 危险）"
            log "  3) 追加到 ~/.claude/CLAUDE.md 末尾（带标记，重复运行自动跳过）"
        else
            log "  ⚠️  2) 覆盖 [不可用：文件不可写]"
            log "  ⚠️  3) 追加 [不可用：文件不可写]"
        fi
        log "  4) 复制到当前目录 $PWD_CLAUDE_MD（项目级，不动全局）"
        log ""

        # 决定可用选项
        if [ "$CAN_WRITE_GLOBAL" = true ]; then
            valid_choices="1 2 3 4"
        else
            valid_choices="1 4"
            log "⚠️  全局 CLAUDE.md 不可写，仅选项 1 和 4 可用"
            log ""
        fi

        # 交互式选择
        if [ "$FORCE" = true ]; then
            choice=4  # force 模式下默认选项 4（最安全）
            log "[force] 默认选择: $choice"
        elif [ ! -t 0 ]; then
            choice=4
            log "[非交互] 默认选择: $choice（最安全）"
        else
            while true; do
                read -r -p "请选择 [$valid_choices]: " choice
                if [[ " $valid_choices " == *" $choice "* ]]; then
                    break
                fi
                echo "无效选择: $choice（有效选项: $valid_choices）"
            done
        fi

        case "$choice" in
            1)
                log "⏭️  跳过 CLAUDE.md 处理"
                ;;
            2)
                # 覆盖全局
                if [ "$CAN_WRITE_GLOBAL" = true ]; then
                    if [ "$DIST_CLAUDE_MD" = "$CLAUDE_MD" ]; then
                        warn "分发包 CLAUDE.md 与目标为同一文件（脚本运行在 ~/.claude/ 下），跳过覆盖"
                        warn "如需更新请手动编辑 $CLAUDE_MD"
                    else
                        run_cmd "覆盖 $FOUND_NAME" cp "$DIST_CLAUDE_MD" "$CLAUDE_MD"
                        log "✅ 已覆盖 $CLAUDE_MD"
                    fi
                else
                    warn "全局 CLAUDE.md 不可写，跳过覆盖"
                fi
                ;;
            3)
                # 追加 + 打标记
                if [ "$CAN_WRITE_GLOBAL" = true ]; then
                    if [ "$DIST_CLAUDE_MD" = "$CLAUDE_MD" ]; then
                        warn "分发包 CLAUDE.md 与目标为同一文件（脚本运行在 ~/.claude/ 下），跳过追加"
                        warn "cat 同一文件会导致无限增长；如需项目级副本请选 4"
                    else
                        run_cmd "追加分发包 CLAUDE.md（含标记）" \
                            bash -c 'echo "$1" && cat "$2" >> "$3"' _ "$MARKER" "$DIST_CLAUDE_MD" "$CLAUDE_MD"
                        log "✅ 已追加（含标记 $MARKER，下次运行自动跳过）"
                    fi
                else
                    warn "全局 CLAUDE.md 不可写，跳过追加"
                fi
                ;;
            4)
                # 复制到当前目录（项目级）
                if [ "$DIST_CLAUDE_MD" = "$PWD_CLAUDE_MD" ]; then
                    warn "分发包 CLAUDE.md 与目标为同一文件（当前目录就是分发包目录），跳过复制"
                    warn "如需更新请手动编辑 $PWD_CLAUDE_MD"
                elif [ -f "$PWD_CLAUDE_MD" ] && [ "$FORCE" != true ]; then
                    warn "$PWD_CLAUDE_MD 已存在，跳过复制（如需覆盖请用 --force）"
                else
                    run_cmd "复制分发包 CLAUDE.md 到项目根" \
                        cp "$DIST_CLAUDE_MD" "$PWD_CLAUDE_MD"
                    log "✅ 已创建 $PWD_CLAUDE_MD（项目级，不影响全局）"
                fi
                ;;
        esac
    else
        # 不存在 → 全新环境：默认复制到当前目录 + 提示用户选择是否也建全局
        log "目标 CLAUDE.md 不存在（已查 6 种大小写变体）"
        log ""
        log "📋 选择处理方式："
        log "  1) 跳过（不创建 CLAUDE.md）"
        log "  2) 创建 ~/.claude/CLAUDE.md（全局默认）"
        log "  4) 复制到当前目录 $PWD_CLAUDE_MD（项目级）"
        log ""

        if [ "$FORCE" = true ] || [ ! -t 0 ]; then
            choice=2
            log "[自动] 默认选择: $choice（创建全局）"
        else
            while true; do
                read -r -p "请选择 [1/2/4]: " choice
                if [[ " $choice " == *" 1 "* ]] || [[ " $choice " == *" 2 "* ]] || [[ " $choice " == *" 4 "* ]]; then
                    break
                fi
                echo "无效选择: $choice（有效选项: 1/2/4）"
            done
        fi

        case "$choice" in
            1)
                log "⏭️  跳过 CLAUDE.md 创建"
                ;;
            2)
                run_cmd "创建全局 CLAUDE.md（从分发包复制）" \
                    cp "$DIST_CLAUDE_MD" "$TARGET_HOME/.claude/CLAUDE.md"
                log "✅ 已创建 $TARGET_HOME/.claude/CLAUDE.md"
                ;;
            4)
                run_cmd "创建项目级 CLAUDE.md（从分发包复制）" \
                    cp "$DIST_CLAUDE_MD" "$PWD_CLAUDE_MD"
                log "✅ 已创建 $PWD_CLAUDE_MD（项目级）"
                ;;
        esac
    fi
fi

# ====== 完成 ======
log ""
log "===== ✅ 安装完成 ====="
log ""
log "已复制/覆盖的文件："
log "  ~/.claude/commands/summarizing.md"
log "  ~/.claude/commands/init-template.md"
log "  ~/.claude/skills/summarizing/SKILL.md"
log "  ~/.claude/skills/summarizing/archive.sh"
log "  ~/.claude/memory/MEMORY.md"
log "  ~/.claude/memory/_frontmatter-template.md"
log "  ~/.claude/memory/preferences/*.md (7 个，不含 Feedback 占位)"
log ""
log "已保护的 about-me/ 文件（如果已存在则跳过）："
for f in profile.md tech-stack.md family.md; do
    if [ -f "$MEMORY_DIR/about-me/$f" ]; then
        log "  ~/.claude/memory/about-me/$f"
    fi
done
if [ -n "${MEMORY_BAK:-}" ] && [ -d "$MEMORY_BAK" ]; then
    log ""
    log "⏪ 旧 memory/ 内容已备份到: $MEMORY_BAK"
    log "   旧内容在备份目录里，如需恢复请手动合并（脚本不会自动覆盖用户数据）"
    log "   示例: cp -n $MEMORY_BAK/about-me/profile.md $MEMORY_DIR/about-me/"
fi
log ""
log "已安装到 ~/.claude/ 的参考文档（已存在则跳过）："
log "  ~/.claude/初始化要求.md"
log "  ~/.claude/记忆系统架构.md"
log ""
log "下一步："
log "  1. 重新启动 Claude Code 使命令生效"
log "  2. 编辑 ~/.claude/memory/about-me/profile.md 填你的信息"
log "  3. 在项目根目录跑 /init 创建项目级 memory/"
log "  4. 跑 /summarizing 测试总结命令"
log ""
log "📋 建议：全部完成后，跑一次检查脚本验证目录结构和文件都预建完毕："
log "    bash ~/claude-template-distribute/check-project-hierarchy.sh"
