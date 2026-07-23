# 分布式 CLAUDE.MD 黑名单

> /init 时由 AI 读一次：以下目录跳过不建子 CLAUDE.MD。
> 触发规则参考 `~/.claude/CLAUDE.md` 第 3 条。

## 跳过黑名单

以下目录**不建子 CLAUDE.MD**（都是机器生成的，不是手写的）：

### 依赖/包目录
- node_modules/
- vendor/
- .pnpm-store/
- jspm_packages/

### 编译产物
- dist/
- build/
- out/
- output/
- target/
- bin/obj/
- .next/
- .nuxt/
- .svelte-kit/
- .parcel-cache/
- .cache/
- .turbo/

### 运行时缓存
- __pycache__/
- .pytest_cache/
- .mypy_cache/
- .ruff_cache/
- .tox/
- .nox/
- .coverage/
- htmlcov/
- .nyc_output/
- coverage/
- .tsbuildinfo

### 虚拟环境
- venv/
- .venv/
- env/
- .env/
- .python-version
- .ruby-version/
- .nvm/

### 版本控制
- .git/
- .svn/
- .hg/
- .bzr/

### IDE/编辑器配置
- .vscode/
- .idea/
- .DS_Store
- Thumbs.db
- *.swp
- *.swo

### 日志/临时/系统垃圾
- logs/
- log/
- tmp/
- temp/
- .tmp/
- *.log
- *.pid
- .Spotlight-V100/
- .Trashes/
- .fseventsd/

### 锁文件目录（可选跳过）
- .lock/
- locks/
- node_modules.lock/

## 触发规则

按 `~/.claude/CLAUDE.md` 第 3 条：
- **触发时机**：AI 准备在某个一级子目录建 CLAUDE.MD 之前，Read 一次该文件（如未读过）
- **重读时机**：用户显式说"重新读黑名单"时
- **不重读**：后续会话不主动重新加载（避免 token 浪费）

## 维护规则

- 新增机器生成目录时，往对应类别下加一行
- 不要列人手写的源码/文档/配置目录（如 src/、docs/、tests/、config/、scripts/、migrations/、db/、examples/）——这些**要建** CLAUDE.MD
- 类别冲突时优先列黑名单（白名单只通过注释说"要建"）
