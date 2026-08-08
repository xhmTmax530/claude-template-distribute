# claude-template-distribute

> 一键分发 Claude Code 记忆系统模板到全新环境的工具包（含三级 CLAUDE.md 渐进式披露架构）

---

## 📖 这是什么

这是一个**开箱即用的模板分发包**，包含：
- **记忆系统**（~/.claude/memory/）：全局/项目级记忆 + 归档 + 引用 + 11 个 0 字节占位文件
- **Harness 渐进式披露架构**：全局 → 项目根 → 一级子目录 三级 CLAUDE.md
- **命令 + Skills**：/summarizing 项目总结 + archive.sh 归档脚本
- **一键安装脚本**：setup-claude-template.sh（带 banner 提示、系统目录警告、幂等审计）

**适用场景**：把整套 Claude Code 记忆系统装到同事机器上 + 在新项目中自动建立 CLAUDE.md 层级

---

## 🚀 快速开始

### 标准用法（解压一次，到处可跑）

```bash
# 1. 把整个工具包放在家目录的标准位置
tar xzf claude-template-distribute.tar.gz -C ~/

# 2. 在任何项目根目录跑（前置：目标机器已经跑过一次 `claude`，~/.claude/ 已创建）
bash ~/claude-template-distribute/setup-claude-template.sh
```

### 演练模式（推荐第一次跑时用）

```bash
bash ~/claude-template-distribute/setup-claude-template.sh --dry-run
```

`--dry-run` 模式下脚本会**显示**所有将做的事情但**不真改**——验证完再实跑。

### 强制模式（CI/批量部署场景）

```bash
bash ~/claude-template-distribute/setup-claude-template.sh --force
```

`--force` 跳过所有交互确认，直接执行（仅用于自动化场景）。

---

## 🧠 三级 CLAUDE.md 渐进式披露架构

你同事装完模板后，在项目目录输入 `/init`，会**自动**生成三级 CLAUDE.md：

```
全局 CLAUDE.md（系统级）              ~/.claude/CLAUDE.md
    ↓ 指针
项目根 CLAUDE.md（项目级）            ~/work/myapp/CLAUDE.md
    ↓ 指针（每个一级子目录一段）
一级子目录 CLAUDE.md（模块级）        ~/work/myapp/src/CLAUDE.md
                                     ~/work/myapp/docs/CLAUDE.md
                                     ~/work/myapp/tests/CLAUDE.md
                                     ...
```

### 三级各放什么

| 级别 | 路径 | 内容 | 何时读取 |
|------|------|------|----------|
| **全局级** | `~/.claude/CLAUDE.md` | 系统级规则（记忆系统架构 + Harness 指针 + 约束规范） | 每次会话启动 |
| **项目级** | `<项目根>/CLAUDE.md` | 项目目录结构总览 + 全局信息（README 入口 + 技术栈 + 入口点 + 架构模式）+ 子目录指针 | 每次会话启动（按需） |
| **模块级** | `<项目根>/<子目录>/CLAUDE.md` | 该子目录详细架构（组件/功能/模块/技术栈/框架/依赖关系） | 按需（AI 推理触发） |

### 三级的核心价值

**大白话**：进任何项目，AI 只看项目根 CLAUDE.md 就知道"这是个什么项目"，要找细节再按指针跳到 `src/CLAUDE.md`、`docs/CLAUDE.md`。**不需要一次性把所有 CLAUDE.md 都加载**，省 token。

**底层原理**：
- 每次会话只加载**全局级** + **项目级**（项目根）——这俩是"必备上下文"
- 一级子目录的 CLAUDE.md 是**按需加载**——AI 推理判断"操作涉及 src 目录"时主动 Read
- Harness架构.md 本身只在**首次 /init** 才读——后续 /init 不重复加载（token 节省）

### /init 完整触发链路

```
用户输入 /init（在 ~/work/myapp/ 目录下）
       ↓
AI 加载全局 CLAUDE.md（每次会话自动）
       ↓
AI 看到全局 CLAUDE.md Harness 章节指针 → 主动 Read ~/.claude/Harness架构.md（首次 /init 一次性）
       ↓
AI 拿到规则：
   1. 创建项目根 CLAUDE.md（目录结构 + 全局信息 + 子目录指针）
   2. 扫描一级子目录，每个非黑名单子目录创建 CLAUDE.md（详细内容）
   3. 黑名单目录（node_modules、.git 等）跳过
       ↓
AI 执行：
   - ~/work/myapp/CLAUDE.md 不存在 → 创建（写：项目骨架 + 技术栈 + 入口 + 指针）
   - ~/work/myapp/src/CLAUDE.md 不存在 → 创建（写：src 详细架构）
   - ~/work/myapp/docs/CLAUDE.md 不存在 → 创建
   - ~/work/myapp/node_modules/ → 黑名单命中 → 跳过
       ↓
下次会话：AI 只加载全局 + 项目根，按需加载子目录
```

---

## 🛠️ 脚本做了什么（setup-claude-template.sh v1.6）

脚本有 **11 个 Step**（加 v1.6 新增的 banner 和幂等审计）：

| Step | 内容 | 幂等策略 |
|------|------|----------|
| 0 | **前置 banner** + 系统目录警告（v1.6 新增） | 纯提示，不改文件 |
| 1 | 环境检测（claude 命令、~/.claude/ 可写、源目录、关键文件） | 只读校验 |
| 2 | 备份现有 memory/、summarizing.md、skills/summarizing/（加 .bak-YYYYMMDD 后缀） | 已存在则备份后缀 |
| 3 | 复制目录结构（memory/{about-me,preferences}、skills/summarizing） | mkdir -p 幂等 |
| 4 | 复制 memory 文件（preferences/*.md、MEMORY.md、_frontmatter-template.md） | ⚠️ 覆盖式 |
| 5 | about-me/ 骨架保护（profile.md、tech-stack.md、family.md） | ✅ 已存在且非空 → 跳过 |
| 6 | 复制 commands/summarizing.md + skills/summarizing/ | ⚠️ 覆盖式 |
| 6.4 | LanceDB 可选安装询问（v2.5 新增） | 🎯 交互式（可选增强，失败不中断） |
| 6.5 | 安装 blacklist.md 到 ~/claude-template-distribute/ | ⚠️ 覆盖式（黑名单必须最新） |
| 6.6 | 安装 Harness架构.md 到 ~/.claude/（v1.5 新增） | ✅ 已存在 → 跳过（保护用户手改） |
| 7 | CLAUDE.md 4 选项处理（v1.7 重构） | 🎯 交互式（含标记机制 + 失败降级） |

✅ = 严格幂等（存在则跳过）  ⚠️ = 覆盖式（运行结果一致但内容更新）  🎯 = 交互式（按场景动态）

完整幂等审计表在脚本头部注释里。

---

## 🎯 CLAUDE.md 4 选项处理（v1.7 新设计）

脚本 Step 7 处理 `~/.claude/CLAUDE.md` 时，根据**是否存在 / 是否可写 / 是否含标记**，动态展示 4 个选项：

### 选项矩阵

| 场景 | 选项 1 跳过 | 选项 2 覆盖 | 选项 3 追加+标记 | 选项 4 项目级 |
|------|:----------:|:----------:|:---------------:|:------------:|
| **全局不存在（全新环境）** | ✅ | ✅ 创建全局 | — | ✅ |
| **全局已存在 + 可写** | ✅ | ✅ | ✅ | ✅ |
| **全局已存在 + 只读** | ✅ | ⚠️ 不可用 | ⚠️ 不可用 | ✅ |
| **全局已存在 + 含标记** | 🚫 全部跳过 | 🚫 | 🚫 | 🚫 |

### 各选项含义

| 选项 | 行为 | 风险 |
|------|------|------|
| **1) 跳过** | 不动 CLAUDE.md，脚本继续跑其他 Step | 🟢 无风险 |
| **2) 覆盖** | cp 替换整个 `~/.claude/CLAUDE.md` | 🔴 高（用户已有内容丢失，**已备份**） |
| **3) 追加 + 标记** | 末尾追加分发包 CLAUDE.md 内容 + 打 `<!-- CLAUDE_TEMPLATE_INSTALLED -->` 标记 | 🟡 中（重复运行脚本看到标记→全部 CLAUDE.md 操作无效） |
| **4) 项目级** | cp 到 `$PWD/CLAUDE.md`，不动全局 | 🟢 无风险（推荐） |

### 标记机制（防重复）

```
首次脚本运行 → 选项 3 追加 → 写入标记 <!-- CLAUDE_TEMPLATE_INSTALLED -->
       ↓
再次运行脚本 → 检测到标记 → 全部 CLAUDE.md 操作无效
       ↓
包括追加、覆盖、项目级创建都跳过（脚本其他 Step 仍正常跑）
```

**解除标记**：手动删除 `~/.claude/CLAUDE.md` 中的 `<!-- CLAUDE_TEMPLATE_INSTALLED -->` 即可让脚本恢复操作。

### 失败降级（全局 CLAUDE.md 只读）

如果 `~/.claude/CLAUDE.md` 存在但不可写（同事机器权限问题）：

```
⚠️  2) 覆盖 [不可用：文件不可写]
⚠️  3) 追加 [不可用：文件不可写]
📋 仅选项 1 和 4 可用
```

脚本不强行写入，主动降级到"不动全局 + 项目级创建"两条路。

### 默认值（非交互模式）

| 触发 | 默认选项 |
|------|---------|
| `--force` | 4（最安全） |
| 管道输入（非交互） | 4（最安全） |
| 全新环境 | 2（创建全局） |

---

## 📦 分发包内容

```
~/claude-template-distribute/
├── CLAUDE.md                       # 全局级 CLAUDE.md 模板（cp 自你本机 ~/.claude/CLAUDE.md）
├── Harness架构.md                  # 三级指针链规则（/init 读一次）
├── blacklist.md                    # Harness 黑名单（node_modules、.git 等）
├── setup-claude-template.sh        # 一键安装脚本（v1.6）
├── LanceDB安装部署手册.md           # LanceDB 手动部署指南（纯手动可部署，照着敲命令即可）
├── README.md                       # 本文档
└── source/                         # 模板源目录（脚本从这里复制）
    ├── memory/
    │   ├── MEMORY.md                # 全局记忆索引
    │   ├── _frontmatter-template.md # frontmatter 规范模板
    │   ├── about-me/                # 3 个 0 字节占位（AI 只读不写）
    │   │   ├── profile.md
    │   │   ├── tech-stack.md
    │   │   └── family.md
    │   └── preferences/             # 8 个 0 字节占位（AI 只读不写）
    │       ├── Feedback.md
    │       ├── code-style.md
    │       ├── command-style.md
    │       ├── engineering-process.md
    │       ├── principle.md
    │       ├── report-style.md
    │       ├── role.md
    │       └── selection-report.md
    ├── commands/
    │   ├── summarizing.md           # /summarizing 命令定义
    │   └── rebuild-claude.md        # /rebuild-claude 命令定义（重建 CLAUDE.md 索引）
    └── skills/
        └── summarizing/
            ├── SKILL.md             # summarizing skill 定义
            ├── archive.sh           # 归档脚本（>1 天总结移到 archive/）
            └── archive_to_lancedb.py # LanceDB 写入脚本（可选增强，归档前调用）
```

---

## 🔄 CLAUDE.md 同步工作流

你本机改了全局 CLAUDE.md 后，必须**手动 cp 同步到分发包**，否则脚本下次分发出去的还是旧版本：

```bash
# 1. 改完 ~/.claude/CLAUDE.md
vim ~/.claude/CLAUDE.md

# 2. cp 同步到分发包
cp ~/.claude/CLAUDE.md ~/claude-template-distribute/CLAUDE.md
cp ~/.claude/Harness架构.md ~/claude-template-distribute/Harness架构.md
cp ~/.claude/commands/summarizing.md ~/claude-template-distribute/source/commands/summarizing.md

# 3. 验证
diff ~/.claude/CLAUDE.md ~/claude-template-distribute/CLAUDE.md
diff ~/.claude/Harness架构.md ~/claude-template-distribute/Harness架构.md
```

**为什么不自动同步**：分发包是"模板仓库"，~/.claude/ 是"工作副本"——脚本只装不更新。保护你的手改，但牺牲自动同步。手动 cp 是有意设计（README + 脚本头部 banner 都会提示）。

---

## 👥 同事环境完整工作流

### 场景 A：标准安装（推荐）

```bash
# 1. 同事解压到标准位置
tar xzf claude-template-distribute.tar.gz -C ~/

# 2. 跑过一次 claude（创建 ~/.claude/）
claude

# 3. 退出后跑安装脚本
bash ~/claude-template-distribute/setup-claude-template.sh

# 4. 重新启动 claude（加载新记忆系统）
claude

# 5. 编辑 about-me/ 填个人信息
vim ~/.claude/memory/about-me/profile.md

# 6. 在项目根跑 /init 建立三级 CLAUDE.md
cd ~/work/myapp/
claude
> /init
```

### 场景 B：只复制脚本（不推荐——会失败）

如果同事只 `cp setup-claude-template.sh` 到自己项目目录执行：

```
⚠️  脚本开头 banner 已经警告："source/ 必须跟脚本同目录"
       ↓
如果同事忽略警告继续跑
       ↓
SOURCE_DIR 4 优先级查找失败：
   - 脚本身边没 source/ → 跳过
   - 家目录没 claude-template-distribute/ → 跳过
   - env 没设 → 跳过
       ↓
脚本报错退出，提示 3 种修法：
   1. 在标准位置解压: tar xzf claude-template-distribute.tar.gz -C ~/
   2. 设置环境变量: export CLAUDE_TEMPLATE_HOME=~/your-tool-dir
   3. 整包复制（含 source/）
```

### 场景 C：脚本放到系统目录（/usr、/etc 等）

```
⚠️  系统目录检测触发：黄色警告但不退出
   "检测到脚本位于系统目录，不建议存放用户脚本"
       ↓
脚本继续执行——宽松模式，你有最终决定权
```

---

## 🎯 /init 触发效果（同事视角）

你同事在 `~/work/myapp/` 输入 `/init` 后，会自动创建：

**项目根 CLAUDE.md**（`~/work/myapp/CLAUDE.md`）：
```markdown
# ~/work/myapp/ 项目根

## 项目概览
本项目是 [从 README 摘要]

## 目录结构
- src/      → 源代码（详见 src/CLAUDE.md）
- docs/     → 文档（详见 docs/CLAUDE.md）
- tests/    → 测试（详见 tests/CLAUDE.md）
- scripts/  → 工具脚本（详见 scripts/CLAUDE.md）
- node_modules/ → 依赖（黑名单，跳过）

## 技术栈
- 框架：React 18
- 语言：TypeScript 5
- 构建：Vite

## 入口点
- 主入口：src/main.tsx
- 配置文件：vite.config.ts

## 全局约定
- 提交前跑 npm run lint
- 测试覆盖率要求 >80%
```

**一级子目录 CLAUDE.md**（如 `src/CLAUDE.md`）：
```markdown
# src/ 源代码目录

## 模块清单
- components/ → React 组件
- hooks/      → 自定义 Hooks
- utils/      → 工具函数
- types/      → TypeScript 类型定义

## 技术栈
- React 18（函数组件 + Hooks）
- TypeScript 5（strict mode）
- React Router 6

## 依赖关系
- components/ → 依赖 hooks/、types/
- hooks/      → 依赖 utils/、types/
- utils/      → 无依赖（纯函数库）
```

---

## 🔧 关键设计点

### 1. 三级指针链（核心创新）

- **全局 CLAUDE.md**：每次会话自动加载（系统级）
- **项目根 CLAUDE.md**：每次会话加载（项目级必备上下文）
- **子目录 CLAUDE.md**：AI 推理按需加载（模块级）

**节省 token 效果**：
- 旧设计：所有 CLAUDE.md 都加载 = 假设 10 个子目录 × 200 行 = 2000 行 token
- 新设计：只加载 2 级 = 假设 2 × 200 行 = 400 行 token
- **节省 80%**

### 2. 脚本 4 优先级查找

脚本找 source/ 目录按 4 个优先级（从高到低）：

1. 脚本身边 `source/`（整包复制场景）
2. `~/claude-template-distribute/source/`（标准安装位置）
3. `$CLAUDE_TEMPLATE_HOME/source/`（环境变量覆盖）
4. 全部失败 → 报错退出 + 3 种修法

**多层防御**：99% 使用场景都被覆盖。"只复制脚本"这种异常场景会被优雅降级到"报错 + 3 种修法"。

### 3. 系统目录警告（宽松模式）

检测 SCRIPT_DIR 是否在 `/usr`、`/etc`、`/var`、`/opt`、`/bin`、`/sbin`、`/lib` 这些系统目录里。如果是：
- ⚠️ **黄色警告**（不退出）
- 提示推荐位置：`~/tools/`、`~/projects/`、`~/.local/share/`
- **用户有最终决定权**（你确认要宽松模式）

### 4. CLAUDE.md 智能追加（避免重复）

通过 `grep -qi "PERSONAL_MEMORY_START"` 标记检测：
- 已含标记 → 跳过追加（保护用户已自定义内容）
- 不含标记 → 末尾追加分发包 CLAUDE.md
- 大小写忽略（兼容 6 种变体）

### 5. about-me/ 骨架保护

`profile.md`、`tech-stack.md`、`family.md` 三个文件：
- 已存在且非空 → **跳过**（保护用户真实信息）
- 不存在或为空 → 复制骨架（占位内容）
- **这是 CLAUDE.md 第 5 条"AI 只读不写"的具体实施**——AI 不会主动写这些文件

### 6. preferences/ 0 字节占位

8 个偏好文件（Feedback.md、code-style.md、command-style.md 等）：
- **0 字节空文件**——AI 只读，不会写入
- 用户需要时手动填内容

### 7. check-project-hierarchy.sh — 项目体检脚本（v1.7 配套）

独立的体检脚本，扫描当前项目根目录：

**用法**：
```bash
# 检查当前目录
bash ~/claude-template-distribute/check-project-hierarchy.sh

# 检查指定项目
bash ~/claude-template-distribute/check-project-hierarchy.sh ~/work/myapp
```

**输出两节**：

| 节 | 检查内容 | 缺失行为 |
|----|---------|---------|
| **【硬性要求】** | 7 个目录 + 13 个固定文件（含 MEMORY.md、_frontmatter-template.md、about-me 3 个、preferences 7 个） | 退出码 1 + 列出缺失项提醒当事人 |
| **【CLAUDE.md 事实陈述】** | 一级子目录 CLAUDE.md 存在状态 + 黑名单标注 | 仅陈述，由当事人判断 |

**退出码**：
- `0` — 硬性要求全部满足
- `1` — 硬性要求有缺失（CI 可拦截）
- `2` — 路径不存在或不是目录

**Feedback.md 标记为选填**——summarizing 跑后才有，缺失不提醒。

### 8. LanceDB 长期记忆集成（v2.5 新增，可选增强）

/summarizing 归档时，若目标环境已安装 lancedb，过期总结会在移入 archive/ 前自动写入 `~/.lancedb/summaries/`：

- **零侵入可选增强**：未安装 lancedb → 完全按原归档方式运行，不报错、零依赖；安装后自动启用
- **按项目隔离**：每个项目一张表，表名 = 项目名，行结构 `text`（总结全文）/ `project` / `date`（YYYYMMDD）
- **零向量零依赖**：不做 embedding，检索靠 LanceDB 原生 FTS（tantivy），仓库保持零额外 Python 依赖
- **备份 = 拷贝目录**：`~/.lancedb/summaries/` 整个目录拷贝即完成备份，无中心数据库
- **安装方式**：setup 脚本 Step 6.4 交互式询问（失败不中断），或按 `LanceDB安装部署手册.md` 手动部署

---

## 📚 Token 节省量化

| 场景 | 旧设计 token | 新设计 token | 节省 |
|------|-------------|-------------|------|
| 10 个子目录的项目 | 2000 行 | 400 行 | 80% |
| 5 个子目录的项目 | 1000 行 | 200 行 | 80% |
| 1 个子目录的项目 | 200 行 | 50 行 | 75% |

**节省原理**：
- 旧设计：所有 CLAUDE.md 都加载 = 一次性吃满
- 新设计：只加载 2 级（全局 + 项目根）= 子目录按需加载
- AI 推理触发 Read 时才加载子目录 CLAUDE.md

---

## 🐛 故障排查

### Q1: 跑脚本报"找不到 source/ 目录"

```
❌ 找不到 source/ 目录（4 优先级全部失败）
```

**修法**：
1. 确认脚本身边有 `source/` 目录（`ls -la ~/claude-template-distribute/source/`）
2. 确认 `~/claude-template-distribute/source/` 存在
3. 或设置环境变量：`export CLAUDE_TEMPLATE_HOME=~/your-tool-dir`

### Q2: 跑脚本报"目标目录不可写"

```
❌ 目标目录不可写: /root/.claude
```

**修法**：用非 root 用户跑，或 `chmod u+w ~/.claude`

### Q3: /init 没有创建 CLAUDE.md

**原因**：
- 全局 CLAUDE.md 没装好（脚本没跑成功）
- Harness架构.md 没分发到 ~/.claude/
- 黑名单把所有子目录都命中了

**排查**：
```bash
ls -la ~/.claude/CLAUDE.md          # 应存在
ls -la ~/.claude/Harness架构.md     # 应存在
cat ~/claude-template-distribute/blacklist.md  # 看黑名单
```

### Q4: CLAUDE.md 被重复追加

**原因**：标记检测失败（`PERSONAL_MEMORY_START` 字符串缺失）

**修法**：手动在 CLAUDE.md 头部加 `<!-- PERSONAL_MEMORY_START -->` 标记

### Q5: 改了全局 CLAUDE.md，同事机器没生效

**原因**：你改了本机，没 cp 到分发包

**修法**：
```bash
cp ~/.claude/CLAUDE.md ~/claude-template-distribute/CLAUDE.md
# 同事重新跑脚本即可（但注意：CLAUDE.md 是智能追加，已存在的部分不会更新）
```

---

## ⚠️ 已知限制

1. **CLAUDE.md 智能追加不会更新已有内容**：已含标记的 CLAUDE.md 不会覆盖，只追加。这是有意设计——保护用户手改
2. **Harness架构.md 不会自动更新**：已存在 → 跳过覆盖。需要手动 cp
3. **系统目录警告不强制**：宽松模式，你确认的——同事把脚本放到 /usr/local/bin 也会跑下去
4. **/init 第一次跑才读 Harness架构.md**：后续 /init 不重复读——节省 token 但用户不知道 Harness 规则更新了

---

## 📜 版本历史

- **v2.5**（2026-08-08）：新增 LanceDB 长期记忆集成（可选增强，按项目隔离，归档前写入 ~/.lancedb/summaries/，未装 lancedb 按原方式运行）；归档阈值 3 天 → 1 天；/summarizing 先读最近总结在其上改写、禁止同日多份；新增 /rebuild-claude 命令 + LanceDB安装部署手册.md；setup 脚本新增 Step 6.4（交互式询问是否安装 LanceDB，失败不中断）；初始化要求.md 新增"会话前读取最近项目总结"提示词
- **v2.4.1**（2026-08-06）：渐进式读取修复——blacklist 补 .claude/ 强制跳过，命令步骤 4 改为除黑名单外一律创建子目录 CLAUDE.md
- **v2.4**（2026-08-02）：init-template 自定义命令 + setup 脚本全面修复
- **v2.3**（2026-07-29）：强制子 agent 规则（主 agent 最小集）
- **v2.2.1**（2026-07-29）：修正"一句话摘要"措辞 → 结构化要点 + 关键细节 + 指针
- **v2.2**（2026-07-29）：修正渐进式披露措辞，限定为"仅外部大资料场景"
- **v2.1**（2026-07-29）：references/ 指针化 + 渐进式披露
- **v2.0**（2026-07-26）：回滚英文版 + 维度 1 加优先级列
- **v1.9**（2026-07-26）：summarizing 优先级列 + 全英文化 + 格式紧凑化
- **v1.8**（2026-07-25）：summarizing 落盘健康检查 + Feedback.md 兜底建占位
- **v1.7**（2026-07-23）：Step 7 重构为 4 选项交互式（跳过 / 覆盖 / 追加+标记 / 项目级）；加失败降级 + 标记机制 + 完成提示运行检查脚本
- **v1.6**（2026-07-22）：脚本开头加 banner + 系统目录警告 + 幂等性审计表
- **v1.5**（2026-07-22）：加 Step 6.6 分发 Harness架构.md
- **v1.4**（2026-07-22）：source/ 4 优先级查找
- **v1.3**（2026-07-21）：blacklist.md 自动安装
- **v1.2**（2026-07-21）：about-me/ 骨架保护（2 步逻辑）
- **v1.1**（2026-07-21）：CLAUDE.md 智能追加
- **v1.0**（2026-07-20）：基础 7 Step 安装

---

## 🔗 相关文件

- `/home/xhm/claude-template-distribute/setup-claude-template.sh` — 主脚本（v1.6）
- `/home/xhm/claude-template-distribute/Harness架构.md` — 三级指针链规则
- `/home/xhm/claude-template-distribute/CLAUDE.md` — 全局 CLAUDE.md 模板
- `/home/xhm/claude-template-distribute/blacklist.md` — Harness 黑名单
- `/home/xhm/claude-template-distribute/source/` — 模板源目录
- `~/.claude/CLAUDE.md` — 你本机的全局 CLAUDE.md（同步源）
- `~/.claude/Harness架构.md` — 你本机的 Harness 副本