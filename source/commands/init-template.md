---
description: 项目初始化模板——模拟内置 /init 流程（分析项目生成 CLAUDE.md）+ 按 初始化要求.md 创建记忆系统骨架与子目录 CLAUDE.md 指针链。幂等：已有跳过、缺失创建、绝不覆盖。
---

# /init-template 命令

## 角色

项目初始化执行者。第一次进入新项目时，按模板要求把项目初始化成 Claude Code 友好结构。

> **为什么叫"模拟 /init"**：内置 /init 无法被模型或自定义命令直接调用（Claude Code 架构限制——slash command 只能用户敲，`claude --init` 是 Setup hooks 触发器不是 /init）。本命令用模型复刻 /init 的核心产出：分析代码库 → 创建项目根 CLAUDE.md，同时补上模板要求的另外两件事（记忆骨架 + 子目录 CLAUDE.md 链）。每一步由本命令引导，幂等由本命令保证——比内置 /init 更可控、更"听话"。

## 铁律（用户硬性要求，违反 = 初始化失败）

1. **幂等**：已存在 → 跳过；冲突 → 跳过；缺失 → 创建。绝不覆盖、绝不修改已有内容。
2. **非侵入**：只创建本命令规定的文件/目录，不碰用户已有任何东西。
3. **只读区**：about-me/ 与 preferences/ 下 11 个文件只建 **0 字节占位**；之后 AI 只读不写（Feedback.md 由 AI 维护，例外）。
4. **失败预算 3 次**：任一步骤连续失败 3 次 → 停下汇报，不盲目重试。

## 执行步骤

### 步骤 1：定位并读取入口文档

按顺序找 `初始化要求.md`：

1. `~/claude-template-distribute/初始化要求.md`
2. `$PWD/claude-template-distribute/初始化要求.md`
3. `~/.claude/初始化要求.md`

读到后按它的指示读同目录的：
- `记忆系统架构.md`（必读——memory 骨架清单）
- `Harness架构.md`（必读——CLAUDE.md 三级指针链规则）

找不到 → 汇报"分发包缺失，请先跑 setup-claude-template.sh 安装"，**不继续**。

### 步骤 2：模拟内置 /init 流程（项目根 CLAUDE.md）

> ⚠️ **禁止运行 `claude --init`**——那是 Setup hooks 触发器，不是 /init 命令。

1. 检查 `$PWD/CLAUDE.md`：**已存在 → 跳过**（幂等，可顺带提议增量补充但不得修改）
2. 分析项目：README / 目录树 / 构建配置 / 测试指令 / 入口点 / 架构模式
3. 按 Harness架构.md 规则创建项目根 CLAUDE.md：
   - 只放**目录结构总览 + 全局摘要**（README 入口 + 技术栈 + 入口点 + 架构模式）
   - 具体内容用指针指向各一级子目录 CLAUDE.md
   - 不详细写，只做信息阅览

### 步骤 3：按 记忆系统架构.md 创建 memory 骨架

所有目录 `mkdir -p`（安全幂等），文件**存在跳过**：

| 路径 | 文件（0 字节占位） |
|------|-------------------|
| `.claude/memory/projects/` | — |
| `.claude/memory/archive/` | — |
| `.claude/memory/references/` | — |
| `.claude/memory/about-me/` | profile.md, tech-stack.md, family.md |
| `.claude/memory/preferences/` | Feedback.md, code-style.md, command-style.md, engineering-process.md, principle.md, report-style.md, role.md, selection-report.md |

**共 11 个 0 字节文件。创建后不写入任何内容**（AI 只读不写）。

### 步骤 4：按 Harness架构.md 创建子目录 CLAUDE.md 链

1. 读 `~/claude-template-distribute/blacklist.md`（本次执行只读一次）
2. 列出 `$PWD` 的一级子目录
3. 逐个判断：
   - 命中黑名单（node_modules/ .venv/ dist/ .git/ .claude/ __pycache__/ 等机器生成/配置目录）→ **跳过**（`.claude/` 强制跳过：建 CLAUDE.md 会被 Claude Code 自动加载，与根 CLAUDE.md 双份冲突）
   - 已有 CLAUDE.md → **跳过**
   - **其余一级子目录一律创建简短 CLAUDE.md**——包括生成物/测试/归档目录（内容=该目录结构总览+访问约定），不依赖临场判断
   - 手写源码/文档目录（src/ docs/ tests/ config/ scripts/ db/ examples/ 等）→ 内容再加组件、功能、技术栈、依赖关系
4. 每个子目录 CLAUDE.md 只放该目录的架构要点，不冗余、不写流水账
5. 跳过的子目录必须在步骤 5 汇报中逐条列出理由，不静默跳过

### 步骤 5：幂等自检 + 汇报

汇报格式：

```
✅ 创建：目录 N 个 / 文件 N 个
   - .claude/memory/projects/ …
   - CLAUDE.md（项目根 / 子目录）
⏭️ 跳过（已存在）：N 项
⚠️ 警告：<如有>
```

## 触发场景

- 新项目第一次进入，想初始化成 Claude Code 友好结构
- 用户敲 `/init-template`
- 项目缺 .claude/memory/ 骨架或 CLAUDE.md 链
