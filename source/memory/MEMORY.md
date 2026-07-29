# 记忆框架规范

> 渐进式读取

---

## 关于我（about-me目录）

路径：~/.claude/memory/about-me

- [profile](about-me/profile.md)—   **必读**
- [tech-stack](tech-stack.md) — **必读**
- [family](about-me/family.md)  — **仅在用户主动提及家庭时读，默认不读**

## 角色与原则（preferences目录）

路径：~/.claude/memory/preferences

### 必读类（所有对话）

- [role](preferences/role.md) 
- [principle](preferences/principle.md) 
- [report-style](preferences/report-style.md) 

### 触发类（按场景读）

- [selection-report](preferences/selection-report.md) — 选型决策报告模板 — **推荐任何技术栈/框架/方案时必读**

- [code-style](preferences/code-style.md) — 双轨讲解+逐行解释+避坑+5 段式输出 — **回答任何代码/技术栈问题时必读**

- [command-style](preferences/command-style.md) — Linux 命令逐行解释 — **回答任何操作系统命令时必读**

### 项目级目录

<项目根>/.claude/memory/projects

- markdown格式记录和追加项目总结以天为单位 , /summarizing 命令触发上下文总结，并保存于此目录命名如如20260718.md

- 按需读取，默认读取当天创建的文档，追溯超过3天包括3天，文档可能移至`当前项目目录/.claude/memory/archive/projects`

<项目根>/.claude/memory/references

- 大模型自己获得的知识来源，我提供的，大模型研究资料，大型文档都可以自发存放于此，命名格式大模型决定

- 触发方式：按需读取

项目级个人画像及偏好目录：`当前项目目录/.claude/memory/about-me`、`/preferences`必读高于全局