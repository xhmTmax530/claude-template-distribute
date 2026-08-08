#!/usr/bin/env python3
# archive_to_lancedb.py — 把归档的总结文件写入 LanceDB（可选增强，失败静默跳过）
#
# 大白话：archive.sh 的"加分项"。装了 lancedb 就把总结全文存进 ~/.lancedb/summaries/，
#   之后用 lancedb 的 FTS 就能搜历史总结。没装 / 写失败都不报错——归档该咋走咋走。
#
# 用法：
#   python3 archive_to_lancedb.py <项目名> <总结文件路径>
#
# 表结构：text（总结全文）/ project（项目名）/ date（YYYYMMDD，取自文件名前 8 位）
# 不需要向量：保持零依赖，检索靠 lancedb 原生 FTS（tantivy）

import os
import sys


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(1)
    project, file_path = sys.argv[1], sys.argv[2]

    try:
        import lancedb

        with open(file_path, "r", encoding="utf-8") as fh:
            text = fh.read()

        db_path = os.path.join(os.path.expanduser("~"), ".lancedb", "summaries")
        db = lancedb.connect(db_path)
        date_str = os.path.basename(file_path)[:8]
        row = {"text": text, "project": project, "date": date_str}

        if project in db.table_names():
            db.open_table(project).add([row])
        else:
            db.create_table(project, data=[row])
    except Exception:
        # 写入失败静默跳过：LanceDB 是可选增强，不阻塞归档
        sys.exit(1)


if __name__ == "__main__":
    main()
