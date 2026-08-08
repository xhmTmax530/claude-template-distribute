---
name: summarizing
description: /summarizing 命令的归档脚本——扫描项目级 projects/ 下超过 1 天的总结文件，移动到 archive/projects/；独立可手动调用
---

# Summarizing 归档 Skill

提供 archive.sh 脚本，独立于 /summarizing 命令运行。

## 用法

```bash
bash ~/.claude/skills/summarizing/archive.sh <projects_dir>
```

## 行为

- 扫描 `<projects_dir>/*.md`
- 文件名前 8 位是 YYYYMMDD 且 ≤ 1 天前的日期 → 移动到 `<projects_dir>/../archive/projects/`
- 移动而非删除
- 写日志到 `<projects_dir>/.archive.log`

## 触发场景

- 用户希望手动清理过期项目总结
- /summarizing 命令末尾自动调用
