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
#   / summary（一句话概要，取自 frontmatter 的 description）/ files（涉及文件清单，逗号分隔）
# 旧表兼容：老表没有 summary/files 列时尝试 add_columns 补上；补不上（旧版 lancedb 不支持）
#   就按原 3 字段写入，打印一行黄字警告，不阻塞归档。
# 不需要向量：保持零依赖，检索靠 lancedb 原生 FTS（tantivy）

import hashlib
import os
import re
import sys

# 表名白名单：lancedb 只允许字母数字/下划线/连字符/点（中文目录名做项目名时会被拒）
TABLE_NAME_RE = re.compile(r"[^A-Za-z0-9_.-]")


def sanitize_table_name(name: str) -> str:
    """清洗表名：非白名单字符转下划线；清洗后与原名不同则补 6 位短哈希保证唯一（同名清洗会碰撞）。"""
    cleaned = TABLE_NAME_RE.sub("_", name)
    if cleaned != name:
        cleaned = f"{cleaned}_{hashlib.md5(name.encode('utf-8')).hexdigest()[:6]}"
    return cleaned


def extract_summary(text: str) -> str:
    """从总结文档 frontmatter 里抠 description 一行当概要；没有就返回空串。"""
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("description:"):
            return s[len("description:"):].strip().strip('"').strip("'")
    return ""


def extract_files(text: str) -> str:
    """从正文"涉及文件清单"小节后面抓文件路径行（/、./、~/ 开头，或字母开头且含 .），最多 10 条逗号拼起来。"""
    lines = text.splitlines()
    start = -1
    for i, line in enumerate(lines):
        if "涉及文件" in line:
            start = i + 1
            break
    if start < 0:
        return ""
    picked = []
    for line in lines[start:start + 30]:
        s = line.strip()
        # 先去掉常见的列表项标记（- / * / 1. 等），路径本身才是要留的
        for marker in ("- ", "* ", "+ "):
            if s.startswith(marker):
                s = s[len(marker):].strip()
                break
        if len(s) >= 2 and s[0].isdigit() and s[1] == ".":
            s = s[2:].strip()
        if not s:
            continue
        if s.startswith(("/", "./", "~/")) or (s[0].isalpha() and "." in s):
            picked.append(s)
            if len(picked) >= 10:
                break
    return ",".join(picked)


def ensure_new_columns(table) -> bool:
    """老表没有 summary/files 列就试着补上；补不上（旧版 lancedb 不支持）返回 False，让调用方降级。"""
    try:
        if {"summary", "files"} <= set(table.schema.names):
            return True
        table.add_columns({"summary": {"type": "string"}, "files": {"type": "string"}})
        return True
    except Exception:
        return False


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(1)
    project_raw, file_path = sys.argv[1], sys.argv[2]
    project = sanitize_table_name(project_raw)

    try:
        import lancedb

        with open(file_path, "r", encoding="utf-8") as fh:
            text = fh.read()

        db_path = os.path.join(os.path.expanduser("~"), ".lancedb", "summaries")
        db = lancedb.connect(db_path)
        date_str = os.path.basename(file_path)[:8]
        summary = extract_summary(text)
        files = extract_files(text)

        if project in db.list_tables().tables:
            table = db.open_table(project)
            row = {"text": text, "project": project_raw, "date": date_str}
            if ensure_new_columns(table):
                row["summary"], row["files"] = summary, files
            else:
                # 旧表补列失败：静默降级，按原 3 字段写入，不阻塞归档
                print("\033[33m[archive_to_lancedb] 旧表补列失败，跳过 summary/files 字段（不影响归档）\033[0m")
            table.add([row])
        else:
            db.create_table(project, data=[{
                "text": text, "project": project_raw, "date": date_str,
                "summary": summary, "files": files,
            }])
    except Exception as e:
        # 写入失败不阻塞归档，但打黄字警告——完全静默会让"写失败"与"没装 lancedb"无法区分
        print(f"\033[33m[archive_to_lancedb] 写入失败（{project_raw} → 表 {project}）: {e}\033[0m", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
