---
name: _frontmatter-template
description: 记忆文件 frontmatter 规范模板——创建/修改记忆文件时参考；定义必填字段和选填字段
metadata:
  type: reference
  created: 2026-07-18
  tags: [template, schema, frontmatter]
---

# 记忆文件 frontmatter 模板

> **本模板用途**：仅作为 `/summarizing` 命令生成的项目总结文件（位于 `<项目根>/.claude/memory/projects/YYYYMMDD.md`）的字段约定。
>
> 其他记忆文件（about-me、preferences、references）由用户半手动维护，无需 frontmatter。

---

## 完整模板

```yaml
---
name: <kebab-case-slug>           # 必填：文件名去后缀，kebab-case
description: <一句话+触发条件>      # 必填：≤200 字，必带触发条件
created: YYYY-MM-DD               # 必填：绝对日期（首次创建日）
tags: [tag1, tag2]                # 选填：参考用
---
```

---

## 字段详解

### 必填字段（3 个）

#### `name`

- 格式：**kebab-case**（小写字母 + 连字符）
- 长度：建议 ≤ 50 字符
- 唯一性：在 MEMORY.md 索引中必须**唯一**
- 示例：`profile`、`selection-report`、`code-style`

#### `description`

- 作用：**AI 用此判断"何时 Read 这个文件"**
- 长度：≤ 200 字
- **必带触发条件**，例：
  - ✅ "回答任何代码问题时必读"
  - ✅ "AI 推荐安装软件前必读（设备基线）"
  - ❌ "代码风格说明"（不告诉 AI 何时读）

#### `created`

- 格式：绝对日期 `YYYY-MM-DD`
- 含义：文件**首次创建**日期（不是修改日）
- 不修改：改名/补内容不改 created

### 选填字段（1 个）

#### `tags`

- 格式：YAML 数组 `["tag1", "tag2"]`
- 用途：参考分类
- 命名约定：kebab-case
- 示例：`["template", "schema", "frontmatter"]`

---

## 示例

### 示例：project 类（项目总结文件）

```yaml
---
name: 2026-07-18
description: claude-rag 项目 2026-07-18 当日总结——含工作进度、待解问题、下阶段计划
metadata:
  type: project
  created: 2026-07-18
  tags: [summary, claude-rag]
---
```
