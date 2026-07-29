<!-- CODEGRAPH_START -->

<mark>该文件未经同意不得修改</mark>

<!-- CODEGRAPH_END -->

## 记忆系统架构

当第一次用/init，在当前项目目录下创建/projects、/archive、/references

1. 全局记忆索引文件(全局)，~/.claude/memory/MEMORY.md 

2. 项目总结目录(项目)，当前项目目录/.claude/memory/projects

3. 归档文件(项目)，当前项目目录/.claude/memory/archive

4. 外部引用(项目），当前项目目录/.claude/memory/references

5. 个人画像和偏好（项目）   
   当前项目目录/.claude/memory/about-me  
   当前项目目录/.claude/memory/preferences   
   
   - about-me/ 下（3 个）：profile.md, tech-stack.md, family.md
   
   - preferences/ 下（8 个）：Feedback.md, code-style.md, command-style.md, engineering-process.md, principle.md, report-style.md, role.md, selection-report.md
   
   - 共 11 个 0 字节文件，**该目录下所有文件，AI只读不写**

## Harness架构

参考目录(全局)：~/.claude/Harness架构.md，仅/init时执行其中的内容，后续会话不读，遵循幂等操作。

## 约束和规范

- 全局下的memory/目录下(包括子目录)所有文件，你仅有读取权限(例外：Feedback.md由AI维护)

- 项目级projects/、archive/、references/ ，AI可读写。

- 但项目级和全局冲突时，项目级优先级高于全局级

- 如果系统提示含 "compacted" 字样，或通过语义描述感受到是"/compact"之后的会话，请你阅读摘要的同时阅读 `当前项目目录/.claude/memory/projects/` 目录下当日或最近一次项目总结，同时读取，`当前项目目录/.claude/memory/preferences/Feedback.md`如果存在

- 新开会话提示词中包含"接着上次"/"继续做"等接续话语，读取当日或最近一次项目总结

- /init执行严格遵循幂等，已存在则跳过（不覆盖），仅在缺失时创建；重复运行结果一致
