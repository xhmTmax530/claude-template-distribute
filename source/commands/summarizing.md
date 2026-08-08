---
description: 总结当前项目会话上下文，生成每日项目总结文档（含工作进度、待解问题、下阶段计划），自动归档 >1 天的旧总结
---

# /summarizing 命令

## 角色

项目总结专家——把当前会话上下文压缩成结构化文档，方便下次对话快速衔接。

## 强制子 agent 规则（v2.3 重构）

**本命令 = 把活完全外包给 1 个独立 subagent 全权执行**。主 agent 不进 references/、不读项目总结历史、不预扫 .claude/memory/——**只接 prompt、派 agent、收结果、输出确认**。

### 为什么必须派子 agent（用户的核心理由）

**主 agent 上下文紧张**——`/summarizing` 触发时本会话 token 可能已经见底。让主 agent 再去扫目录、读 references、调脚本会**雪上加霜**。

子 agent 是**独立 context window**，跑完整套 10 步不消耗主 agent 的预算。

### 主 agent / 子 agent 分工

| 主 agent 只做（最小集） | 子 agent 全做（完整跑） |
|----------------------|----------------------|
| 接 `/summarizing` 命令 | Step 1：环境检查 |
| 派 1 个 subagent，prompt 必须包含：本命令全文（步骤 1-10）+ 触发上下文（本次会话做了啥） | Step 1.5：健康检查 |
| 等子 agent 返回落盘路径 + 归档数 + 自动创建目录清单 | Step 2-3：读模板 + 列 references |
| **1 句话输出最终确认**（不复读子 agent 报告，避免 token 浪费） | Step 4：8 维度总结 |
| | Step 5：写 `projects/YYYYMMDD.md` |
| | Step 6：归档脚本 |
| | Step 7：准备输出 |
| | Step 8：references 检查 + 落盘 |
| | Step 9：重要参考区块 |
| | Step 10：Feedback.md 维护 |

### 子 agent prompt 模板

```
你是子 agent，被主 agent 派来执行 /summarizing 命令（v2.3 全权委托版本）。

## 你要做的事
完整执行下面这份自定义命令（步骤 1-10），把结果返回给主 agent。

## 本次会话上下文
<主 agent 把"本次会话做了什么"粘到这里>
- 用户想总结的诉求：
- 本会话关键改动：
- 涉及的外部大资料（如有）：
- 涉及的文件路径：

## 自定义命令（完整 copy）
<把 ~/.claude/commands/summarizing.md 全文粘到这里，shell 视图 cat $HOME/.claude/commands/summarizing.md>

## 返回格式（必须给主 agent）
{
  "written_file": "<绝对路径>",
  "archived_count": <数字>,
  "auto_created_dirs": ["projects/", "archive/projects/", ...],
  "references_landed": ["<文件名>", ...],
  "feedback_appended": true/false,
  "warnings": ["<任何黄色警告原文>"]
}
```

### 模型选择（v2.3）

子 agent 用什么模型？**默认 opus**——本命令涉及深度会话理解 + 多步推理 + 完整 8 维度。

如果用户想省钱，可以在派 agent 时指定 sonnet（适合会议纪要类短总结）。

### 跳过子 agent = 总结失败

主 agent 直接跑 /summarizing = 在已紧张的上下文里再吞 N 个文件 → token 爆炸 → 总结质量塌方。

**强制约束**：本规则是用户硬性要求，不是优化建议。违反 = 总结不可信。



## 必读参考

执行此命令前，**必须先读**：
`~/.claude/memory/_frontmatter-template.md`

（了解项目总结文件的字段约定）

## 执行步骤

### 步骤 1：环境检查

```bash
PROJECTS_DIR="$PWD/.claude/memory/projects"
ARCHIVE_DIR="$PWD/.claude/memory/archive/projects"
REFERENCES_DIR="$PWD/.claude/memory/references"
```

- 如果 `$PROJECTS_DIR` 不存在 → 自动创建 `$PROJECTS_DIR` `$ARCHIVE_DIR` `$REFERENCES_DIR`
- 创建后输出："已自动创建项目级 memory 目录：projects/ archive/projects/ references/"

### 步骤 1.5：summarizing 落盘健康检查（v1.8 新增）

> **为什么需要**：同事机器上没跑过 setup-claude-template.sh 时，summarizing 自己落盘所需的路径可能缺失（projects/archive/Feedback.md）。直接 Write 会因为父目录不存在而失败。本步骤**主动检测 + 优雅降级**，让 `/summarizing` 永远能落盘成功。

#### 检查清单（精简版——只管 summarizing 自己要的 3 个路径）

| 路径 | 用途 | 缺失行为 |
|------|------|----------|
| `$PWD/.claude/memory/projects/` | 步骤 5 写总结 | `mkdir -p` |
| `$PWD/.claude/memory/archive/projects/` | 步骤 6 归档脚本 | `mkdir -p` |
| `$PWD/.claude/memory/preferences/Feedback.md` | 步骤 10 写踩坑 | `mkdir -p preferences/` 后留待步骤 10 自决 |

#### 缺失时的提示（黄色警告，不退出）

```
⚠️  检测到项目级 summarizing 落盘路径未初始化
    - 已自动创建 .claude/memory/projects/ 和 archive/projects/
    - 建议：跑 setup-claude-template.sh 获得完整模板
            （含 MEMORY.md / about-me / preferences 占位 / Harness架构 等）
```

#### 本步骤**不创建**的（边界，避免越权）

- 项目级 `MEMORY.md`——用户索引，AI 不该擅自写空壳
- 项目级 `about-me/` 3 个文件——**用户隐私，AI 不能写**
- 项目级 `preferences/` 7 个偏好占位——**用户偏好，AI 不能写**
- 项目级 `CLAUDE.md`——三级指针链，由 `/init` 触发，不归 `/summarizing` 管

> **完整脚手架检查**：跑 `bash ~/claude-template-distribute/check-project-hierarchy.sh` 一次性体检 21 项硬性要求。

### 步骤 2：读模板字段约定

读 `~/.claude/memory/_frontmatter-template.md`，确认 frontmatter 4 字段（name/description/created/tags）。

### 步骤 3：列 references/ 文件清单（不读内容）

```bash
ls "$REFERENCES_DIR" 2>/dev/null
```

记住这些文件名（用于步骤 5 的"参考来源"区块），**不 Read 文件内容**。

### 步骤 4：总结 8 维度

1. **工作进度**：4 列表格（任务 | 状态 | 优先级 | 备注）
   - **状态**：✅ 已完成 / 🚧 进行中 / ⏸ 未开始 / ❌ 阻塞
   - **优先级**：🔴 P0 立刻做 / 🟡 P1 本周 / 🟢 P2 本月 / ⚪ P3 有空再说
   - **备注**：被 X 阻塞写"waiting on X"；依赖 Y 写"depends on Y"；其他自由文本
2. **现状描述**：关键状态 ≤5 条
3. **待解决问题**：阻塞项 + 跟进人/计划
4. **核心问题**：最重要的 1-2 个
5. **重难点**：技术难点 + 决策难点
6. **下阶段工作计划**：≤5 条任务（每条带优先级）
7. **下次对话如何开始**：开局话术模板（下次进入时 AI 该怎么接）
8. **涉及文件清单**：本次会话 touch 过的文件路径

### 步骤 5：写入项目总结文件

- **路径**：`$PROJECTS_DIR/YYYYMMDD.md`（当天日期）
- **先读后写**：先读取 projects/ 下最近一份总结（非当日），在它之上改写本次总结；当日文件存在则直接覆写——**禁止同一天生成多份总结文档，当日仅一份**
- **判断当天文件是否存在**：
  - 存在 → **覆写**（一天一档，仅保留最新）
  - 不存在 → 新建
- **frontmatter** 按模板字段填
- **正文** 包含 8 维度内容
- **末尾追加**"参考来源"区块（如有 references 文件）：
  ```markdown
  ## 参考来源

  - `references/xxx.md` — 简短说明（按需读）
  ```

### 步骤 6：调用归档脚本

```bash
bash ~/.claude/skills/summarizing/archive.sh "$PROJECTS_DIR"
```

捕获输出末尾的"归档完成: N 个文件"。

### 步骤 7：输出确认

向用户报告：

- 已写入：`<绝对路径>`
- 归档：N 个文件
- 自动创建目录（如适用）

### 步骤 8：references/ 指针化 + 大文件落盘（v2.1 强化）

> **v2.1 修订**：v1.5 仅一句"AI 自决"导致漏率高（AI 不知道哪些该存）。v2.1 给**5 条硬触发清单** + **推荐命名规范**，让 AI 不靠"灵感"决定，按规则机械执行。

#### 8.1 触发清单——本会话出现任一情况，必须 cp 到 `references/`

1. **用户给了大段材料**：PDF / 教程 / 长邮件 / 会议纪要 / 聊天记录截屏转文本 / 用户粘贴的官方文档
2. **AI 自己读了 1+ 个长网页**（>30 行有效内容）：技术文章、Stack Overflow 答案、GitHub README
3. **用户引用了某个外部资源**：URL（GitHub/Gist/博客/论文/视频脚本）
4. **用户给了研究报告/对比分析/选型表**（任何结构化大文本）
5. **AI 自己写了 >50 行的研究报告**（如 selection-report 维度 4 的技术栈调研）

**没有触发** → 跳过整个 Step 8（不写空区块，省 token）

#### 8.2 命名规范

```
YYYY-MM-DD-<类型>-<主题>.md
```

- **类型**：`article`（网页/博客）/ `paper`（论文）/ `guide`（官方教程）/ `report`（研究报告）/ `chat`（聊天记录）/ `pdf`（PDF 转文本）/ `code`（代码片段）
- **主题**：kebab-case 简短描述（如 `rag-progressive-disclosure`、`graphrag-multi-hop`）

**示例**：
- `2026-07-26-article-rag-progressive-disclosure.md`
- `2026-07-26-paper-graphrag-multi-hop-reasoning.md`
- `2026-07-26-pdf-claude-code-harness-engineering.md`

#### 8.3 文件内部结构（落地文件 frontmatter）

每个落盘文件必须有 frontmatter（便于后续索引）：

```markdown
---
name: <kebab-case>
description: 一句话——是什么 + 触发场景（什么时候该读这个）
metadata:
  type: reference
  created: YYYY-MM-DD
  source: <URL 或 "用户提供" 或 "AI 联网获取">
  tags: [topic1, topic2]
---

# <主题> — <日期>

> 出处：<URL/来源描述>
> 触发读取：本项目遇到 X 类型问题时

---

## 完整内容
...（原文 / 用户原文 / AI 摘录）
```

#### 8.4 内容原则（避免污染）

- **完整原文优先**：用户给的内容**原样保存**，原样不截断不"优化措辞"
- **AI 不要做精简摘要放进 references/**——精简必有信息损失，原文比摘要可靠
- **总结文档里需要引用资料时**：写**结构化要点 + 关键数字 + 错误码 + 决策权衡 + 指针**——这些是为了让下次 AI 能 1 眼回溯上下文，不是为了省 token 砍自己
- **每个文件 ≤ 500 行**：超长文档拆成多文件（`-part1.md` 等）

### 步骤 9：重要参考（v2.1 指针/实体分层）

今日总结文末追加——**按"指针"和"实体"分层**：

```markdown
## 重要参考

### 指针（references/ 内的完整内容，按需 Read）

- `references/2026-07-26-article-rag-progressive-disclosure.md` — RAG 渐进式披露原理（出处：xxx 公众号）
- `references/2026-07-26-paper-graphrag-multi-hop.md` — GraphRAG 多跳推理综述（出处：arxiv.org/...）

### 实体引用（本总结直接引用的本地文件）

- `/path/to/local-doc.md` — 描述
- （没有就写"无"）

### 外部 URL（未保存的链接，按需联网读）

- <https://github.com/xxx/yyy> — 描述
```

**关键原则**：
- **指针在总结文档里只占 1 行**（不复制内容到总结，避免膨胀）
- **references/ 内的文件**才算"指针资产"——下次 Read 一次就够
- **未保存的 URL**留个轻量指针（"按需联网读"），别复制全文



### 步骤 10：项目级 Feedback.md 维护（v1.8 重构）

> **v1.8 修订点**：v1.7 只在"有踩坑"时才动 Feedback.md，导致跨多次 /summarizing 后 文件可能根本没建。v1.8 拆成 2 个动作：**先确保文件存在**（缺失建占位），**再考虑追加**。

#### 10.1 确保 Feedback.md 存在（兜底建占位）

- **路径**：`$PWD/.claude/memory/preferences/Feedback.md`
- **存在判定**：`test -f "$PWD/.claude/memory/preferences/Feedback.md"`
- **缺失处理**：写一个**占位骨架**（frontmatter + H1 标题 + "等待踩坑"提示，**不写任何具体踩坑条目**）：
   ```markdown
   ---
   name: feedback
   description: <项目根>/.claude/memory/preferences/Feedback.md —— 本项目的踩坑记录；触发场景：本次会话有 bug/污染/设计陷阱时由 AI 追加；遵循"先现象→根因→避坑"三段式
   metadata:
     type: project
     created: YYYY-MM-DD
     tags: [feedback, pitfall]
   ---

   # Feedback.md — 项目级踩坑记录

   > 本文件由 AI 维护（项目级特例，例外于 CLAUDE.md "memory/ AI 只读"规则）
   > 写入规则见 `/summarizing` 命令 v1.8 步骤 10

   ---

   ## 踩坑记录

   <!-- 占位：等待 /summarizing 步骤 10.2 追加内容 -->
   ```
- **已存在处理**：跳过（保留用户历史内容，**不覆写**）

#### 10.2 追加本次会话的踩坑（如果有）

- **本次会话是否有踩坑**：AI 自决（按 CLAUDE.md "禁止凭空编造"，**没踩坑就跳过这一步**）
- **追加格式**：每条用 H3 标题 `### YYYY-MM-DD 标题`，正文 3 行：
  1. **现象**：什么操作 → 出现什么错误结果
  2. **根因**：哪行代码/哪个设计点
  3. **避坑**：下次怎么避免
- **追加规则**：
  - 用 `cat >>` 追加到文件末尾（不覆写前文）
  - 多个踩坑用 `---` 分隔
  - 同一天再次跑 summarizing → 当天多个 H3 标题并列（**不**整体覆盖）

> **为什么是项目级而非全局**：踩坑是项目特定的（每个项目的脚本、设计、约定不同），不应污染全局 memory/。项目级 Feedback.md 跟随项目走，多人协作时同步更精准。
>
> **为什么 AI 可写本文件**：CLAUDE.md 措辞已加例外"Feedback.md 由 AI 维护"——因为踩坑是 AI 自己的经验，由 AI 写最准确。

## 风格要求

- 8 维度每节用 H2 标题分隔
- 表格用 markdown 表格语法
- 避免冗余寒暄
- 洞察性总结放在最末
- **渐进式披露**（v2.2 修正，仅外部大资料场景）：当本会话引用了外部资料（PDF / 长网页 / 论文 / 大 markdown / 用户原文等 > 屏内容）时，**完整原文放 `references/`**（原样不摘要不截断）；总结文档里引用该资料的部分写**结构化要点 + 关键细节 + 指针**（不是一句话摘要——一句话会丢上下文）。总结本身的 8 维度、决策权衡、关键数字一律完整写，不省 token。**核心目的：让下次开会话的 AI 能快速进入状态，不要为省 token 把上下文砍光**
- **什么时候不拆**（v2.2 明确）：普通项目总结、纯内部讨论、不含外部大资料 → 全部直接写总结文档，不要强行拆指针

## 触发场景

- 用户说"总结一下今天的工作"
- 用户输入 `/summarizing`
- 一天结束准备保存进度
