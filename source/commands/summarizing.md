---
description: 总结当前项目会话上下文，生成每日项目总结文档（含工作进度、待解问题、下阶段计划），自动归档 >3 天的旧总结
---

# /summarizing 命令

## 角色

项目总结专家——把当前会话上下文压缩成结构化文档，方便下次对话快速衔接。

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

### 步骤 2：读模板字段约定

读 `~/.claude/memory/_frontmatter-template.md`，确认 frontmatter 4 字段（name/description/created/tags）。

### 步骤 3：列 references/ 文件清单（不读内容）

```bash
ls "$REFERENCES_DIR" 2>/dev/null
```

记住这些文件名（用于步骤 5 的"参考来源"区块），**不 Read 文件内容**。

### 步骤 4：总结 8 维度

1. **工作进度**：已完成 / 进行中 / 未开始（表格形式）
2. **现状描述**：关键状态 ≤5 条
3. **待解决问题**：阻塞项 + 跟进人/计划
4. **核心问题**：最重要的 1-2 个
5. **重难点**：技术难点 + 决策难点
6. **下阶段工作计划**：≤5 条任务
7. **下次对话如何开始**：开局话术模板（下次进入时 AI 该怎么接）
8. **涉及文件清单**：本次会话 touch 过的文件路径

### 步骤 5：写入项目总结文件

- **路径**：`$PROJECTS_DIR/YYYYMMDD.md`（当天日期）
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

### 步骤 8：备份（v1.5 新增）

AI 自决重要大文件，复制到 `$REFERENCES_DIR`，命名 `YYYY-MM-DD-<主题>.md`。

### 步骤 9：引用（v1.5 新增）

今日总结文末追加：

```markdown
## 重要参考

- `<绝对路径>` — 描述
```

### 步骤 10：踩坑写入项目级 Feedback.md（v1.7 新增）

如果本次会话有踩坑记录（bug、shell 脚本污染、设计陷阱等），按以下规则处理：

- **路径**：`$PWD/.claude/memory/preferences/Feedback.md`
- **判断项目级 Feedback.md 是否存在**：
  - 不存在 → 新建（用 frontmatter 模板）
  - 已存在 → **追加**（保留历史踩坑，不覆写）
- **frontmatter** 字段：name=feedback, description=本次踩坑简述, created=YYYY-MM-DD, type=project
- **正文** 每条踩坑用 H3 标题 `### YYYY-MM-DD 标题`，正文包含：
  - 现象（输入 → 输出）
  - 根因（哪一行代码/设计）
  - 解法（如何避免）
  - 适用场景

> **为什么是项目级而非全局**：踩坑是项目特定的（每个项目的脚本、设计、约定不同），不应污染全局 memory/。项目级 Feedback.md 跟随项目走，多人协作时同步更精准。

## 风格要求

- 8 维度每节用 H2 标题分隔
- 表格用 markdown 表格语法
- 避免冗余寒暄
- 洞察性总结放在最末

## 触发场景

- 用户说"总结一下今天的工作"
- 用户输入 `/summarizing`
- 一天结束准备保存进度
