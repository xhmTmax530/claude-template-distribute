- 三级指针链：全局 CLAUDE.md（系统级）→ 项目根 CLAUDE.md（项目级）→ 一级子目录 CLAUDE.md（模块级）。三级渐进式披露，按需加载。

- 项目根 CLAUDE.md（/init 时自动创建）：内容 = 项目目录结构总览 + 全局信息（README 入口 + 技术栈 + 入口点 + 架构模式）。具体内容用指针指向各一级子目录 CLAUDE.md。已存在则跳过。

- 分布式子目录 CLAUDE.md（/init 时自动创建）：内容 = 每个一级子目录的详细架构（组件、功能、模块、技术栈、框架、依赖关系）。已存在则跳过。子目录级别：如 `src/CLAUDE.md`、`docs/CLAUDE.md`、`tests/CLAUDE.md` 等。

- 不在这些目录中创建 CLAUDE.md，黑名单列表 `~/claude-template-distribute/blacklist.md`，仅 /init 触发读，后续会话不重复加载。