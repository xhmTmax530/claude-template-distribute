# LanceDB 安装部署手册

> 本手册服务对象：**大模型 + 人**。照着每一步敲命令就能装好，不需要额外理解。

## 一、LanceDB 是什么（一句话）

LanceDB 是嵌入式向量数据库。装好后，`/summarizing` 归档总结时，archive.sh 会自动把总结全文存入 `~/.lancedb/summaries/`，之后可以用它的全文检索（FTS）搜历史总结。

**可选增强**：没装不影响归档移动（静默跳过）；装了的收益是"能搜历史总结"。

## 二、环境要求

| 项 | 要求 |
|----|------|
| Python | >= 3.10（`python3 --version` 确认） |
| pip | 随 Python 自带（`python3 -m pip --version` 确认） |
| 老 CPU（2015 年之前的机器） | 原生 lancedb 装不上时，用 `lancedb-compat` 替代（纯 CPU 兼容版，检索功能一致，性能略低） |

```bash
python3 --version          # 应显示 3.10+
python3 -m pip --version   # 应显示 pip 版本号
```

## 三、安装命令

```bash
python3 -m pip install lancedb tantivy pandas
```

各包作用：

- `lancedb`：数据库本体
- `tantivy`：全文检索引擎（FTS 检索靠它）
- `pandas`：表数据底层依赖

**可选（向量语义检索，本模板默认不用）**：嵌入走阿里云千问 text-embedding-v4 API：

```bash
python3 -m pip install openai
echo 'export DASHSCOPE_API_KEY=sk-你的key' >> ~/.bashrc   # 百炼控制台创建：https://bailian.console.aliyun.com
source ~/.bashrc
```

费用：单价 0.0005 元/千 token，个人年用量约 70-100 万 token，**年费不足 1 元**；新用户 90 天免费 100 万 token。离线备选：`python3 -m pip install sentence-transformers` 切回本地 bge（BAAI/bge-small-zh-v1.5）。

老 CPU 替代方案：

```bash
python3 -m pip install lancedb-compat
```

验证安装：

```bash
python3 -c "import lancedb; print(lancedb.__version__)"
```

能打印出版本号即安装成功。

## 四、目录结构（自动创建，了解即可）

写入路径 `~/.lancedb/summaries/` **不需要手动建**——archive.sh 第一次调用 archive_to_lancedb.py 时会自动 `connect` 并创建：

```
~/.lancedb/
└── summaries/          # 总结库根目录（lancedb 数据库目录）
    └── <项目名>/       # 每个项目一张表，表名 = 项目目录名
        └── ...         # lancedb 内部数据文件（_versions/ 等，勿手改）
```

每行记录 5 个字段：

| 字段 | 内容 |
|------|------|
| text | 总结文件全文 |
| project | 项目名 |
| date | 归档日期 YYYYMMDD（取自文件名前 8 位） |
| summary | 一句话概要（取自总结 frontmatter 的 description） |
| files | 涉及文件清单（逗号分隔，最多 10 条） |

Claude 会在涉及历史回溯语义时主动查询记忆库，也可手动查询。

手动验证写入（装好并归档过一次后）：

```bash
python3 -c "import lancedb, os; db = lancedb.connect(os.path.expanduser('~/.lancedb/summaries')); print(db.table_names())"
```

应打印出你的项目名。

## 五、手动接入（跳过安装提示时）

跑 setup-claude-template.sh 时如果选了"跳过 LanceDB 安装"，事后想补装，两条路任选：

1. **重跑 setup 脚本**：`bash ~/claude-template-distribute/setup-claude-template.sh`，Step 6.4 选 y
2. **手动装**：按第三节装好即可，**无需任何配置**——archive.sh 每次运行都会探测 `import lancedb`，检测到就自动开始写入

`archive_to_lancedb.py` 刻意保持**零依赖设计**：只存总结全文 + BM25 关键词索引（FTS），不做向量嵌入、**不依赖 API Key**——离线 / 无网 / 未配置千问 key 都不影响归档与检索；想升级语义检索可参照主部署手册（千问 text-embedding-v4）。

## 六、检索历史总结（可选）

```bash
python3 - <<'EOF'
import lancedb
import os

db = lancedb.connect(os.path.expanduser("~/.lancedb/summaries"))
tbl = db.open_table("你的项目名")
print(tbl.create_fts_index("text").search("关键词").to_pandas()[["project", "date", "text"]])
EOF
```

## 七、备份与维护

- **备份**：整个库就是一个目录，复制即备份：

```bash
cp -r ~/.lancedb ~/.lancedb.bak-$(date +%Y%m%d)
```

- **定期清理旧版本**：lancedb 每次写入产生新版本，长期运行后 `~/.lancedb/summaries/` 内旧版本文件会累积，定期执行（建议每月一次或磁盘吃紧时）：

```bash
python3 - <<'EOF'
import lancedb
import os

db = lancedb.connect(os.path.expanduser("~/.lancedb/summaries"))
for name in db.table_names():
    db.open_table(name).cleanup_old_versions()
EOF
```

（每个表清理旧版本文件，只留最新状态）

## 八、故障排查

| 症状 | 处理 |
|------|------|
| `import lancedb` 报错 | 重跑第三节安装命令 |
| 老 CPU 装不上原生版 | `python3 -m pip install lancedb-compat` |
| 归档输出没有 "LanceDB 写入" 行 | 正常——LanceDB 未安装时静默跳过，归档照常移动 |
| 嵌入报错：DASHSCOPE_API_KEY 未配置 | 本模板 FTS 检索不依赖嵌入，可忽略；要用向量检索需按第三节配置 key |
| 千问 embedding 调用失败 / 限流 | 检查网络与 key 有效性；429 限流稍后重试；可临时切本地 bge 离线备选 |
| 不想联网 | 不影响——归档与 FTS 检索全程本地；嵌入是可选项 |
