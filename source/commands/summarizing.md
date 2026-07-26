---
description: Summarize current session into daily project memory file (8 dims incl. priority + status), auto-archive entries older than 3 days, maintain project Feedback.md
---

# /summarizing command

## Role
Compress current session into structured doc for next-session handoff.

## Required reading (before step 2)
`~/.claude/memory/_frontmatter-template.md` — frontmatter schema (name/description/created/tags).

## Steps

### Step 1: Env check
```bash
PROJECTS_DIR="$PWD/.claude/memory/projects"
ARCHIVE_DIR="$PWD/.claude/memory/archive/projects"
REFERENCES_DIR="$PWD/.claude/memory/references"
```
If `$PROJECTS_DIR` missing → `mkdir -p` all three; log "Auto-created: projects/ archive/projects/ references/".

### Step 1.5: Summarizing landing-path health check (v1.8)

Why: colleagues without setup-claude-template.sh may have missing paths. Detect + graceful degrade so `/summarizing` always lands.

#### Check (3 paths only — summarize's own landing needs)
| Path | Purpose | If missing |
|------|---------|-----------|
| `$PWD/.claude/memory/projects/` | step 5 write | `mkdir -p` |
| `$PWD/.claude/memory/archive/projects/` | step 6 archive | `mkdir -p` |
| `$PWD/.claude/memory/preferences/Feedback.md` | step 10 write | `mkdir -p preferences/`, file left to step 10 |

#### Warn (yellow, no exit)
```
⚠️ Summarizing landing paths uninitialized
   - Auto-created: projects/ + archive/projects/
   - Suggest: run setup-claude-template.sh for full template (MEMORY.md/about-me/preferences/Harness架构)
```

#### DO NOT create (boundary, avoid overreach)
- Project `MEMORY.md` — user index, AI must not write empty
- Project `about-me/` × 3 — **user privacy**, AI cannot write
- Project `preferences/` × 7 — **user preferences**, AI cannot write
- Project `CLAUDE.md` — three-tier chain, owned by `/init`, not `/summarizing`

Full scaffold check → `bash ~/claude-template-distribute/check-project-hierarchy.sh` (21 hard requirements).

### Step 2: Read frontmatter template
Read `~/.claude/memory/_frontmatter-template.md`, confirm 4 fields (name/description/created/tags).

### Step 3: List references/ filenames only
```bash
ls "$REFERENCES_DIR" 2>/dev/null
```
Remember filenames for step 5 "Reference sources" block. **Do NOT Read content.**

### Step 4: Summarize 8 dimensions

1. **Progress** — table: task | status | priority | note
2. **Current state** — ≤5 key points
3. **Pending issues** — blockers + owner/plan
4. **Core problem** — 1-2 most critical
5. **Hard points** — tech + decision
6. **Next stage plan** — ≤5 tasks
7. **Next session opener** — opening script template
8. **Files touched** — paths modified/read this session

**Status enum**: ✅ Done / 🚧 In progress / ⏸ Not started / ❌ Blocked
**Priority enum**: 🔴 P0 immediate / 🟡 P1 this-week / 🟢 P2 this-month / ⚪ P3 someday

**Note column** rules (avoid extra columns, save tokens):
- Blocked → "waiting on X"
- Dependency → "depends on Y"
- Otherwise → free text (1 short clause)

### Step 5: Write project summary file
- Path: `$PROJECTS_DIR/YYYYMMDD.md`
- If today's file exists → **overwrite** (one-file-per-day, latest wins)
- Frontmatter per template
- Body: 8 dims above
- Append "Reference sources" block if references/ has files:
  ```markdown
  ## Reference sources

  - `references/xxx.md` — short note (read on demand)
  ```

### Step 6: Run archive script
```bash
bash ~/.claude/skills/summarizing/archive.sh "$PROJECTS_DIR"
```
Capture trailing "Archived: N files".

### Step 7: Output confirmation
Report to user:
- Written: `<absolute path>`
- Archived: N files
- Auto-created dirs (if any)

### Step 8: Backup (v1.5)
AI self-decides important large files, copy to `$REFERENCES_DIR`, name `YYYY-MM-DD-<topic>.md`.

### Step 9: References (v1.5)
Append at end of today's summary:
```markdown
## Important references

- `<absolute path>` — description
```

### Step 10: Project Feedback.md maintenance (v1.8)

> **v1.8 fix**: v1.7 only wrote file when there were pitfalls → file might never exist after many runs. v1.8 split into 2 actions: **ensure file exists** (placeholder if missing), **then append** if there are pitfalls.

#### 10.1 Ensure Feedback.md exists (fallback placeholder)
- Path: `$PWD/.claude/memory/preferences/Feedback.md`
- Existence check: `test -f "$PWD/.claude/memory/preferences/Feedback.md"`
- If missing → write **placeholder skeleton** (frontmatter + H1 + waiting hint, NO actual pitfalls):
  ```markdown
  ---
  name: feedback
  description: <project root>/.claude/memory/preferences/Feedback.md — project pitfalls log; trigger: this session has bugs/pollution/design traps, AI appends; format: phenomenon → root cause → avoidance
  metadata:
    type: project
    created: YYYY-MM-DD
    tags: [feedback, pitfall]
  ---

  # Feedback.md — Project pitfalls log

  > AI-maintained (project-level exception to CLAUDE.md "memory/ AI read-only" rule)
  > Write rules: see `/summarizing` v1.8 step 10

  ---

  ## Pitfalls

  <!-- Placeholder: awaiting /summarizing step 10.2 append -->
  ```
- If exists → skip (preserve history, **no overwrite**)

#### 10.2 Append this session's pitfalls (if any)
- Has pitfalls this session? → AI self-decides (per CLAUDE.md "no fabrication", **skip if none**)
- Format: H3 title `### YYYY-MM-DD title`, body 3 lines:
  1. **Phenomenon**: what op → what wrong result
  2. **Root cause**: which line/design
  3. **Avoidance**: how to prevent next time
- Append rules:
  - `cat >>` to file end (no overwrite)
  - Multiple pitfalls separated by `---`
  - Same-day re-run → multiple H3 titles side-by-side (**no** whole-day overwrite)

> **Why project-level not global**: pitfalls are project-specific (each project's scripts/designs/conventions differ), should not pollute global memory/. Project-level Feedback.md travels with project, syncs more precisely for multi-person collaboration.
>
> **Why AI can write this file**: CLAUDE.md carve-out "Feedback.md AI-maintained" — pitfalls are AI's own experience, AI writes most accurately.

## Style requirements
- 8 dims separated by H2 headers
- Markdown tables for progress/status
- No verbose greetings
- Insights summary at end

## Trigger scenarios
- User says "summarize today's work"
- User types `/summarizing`
- End-of-day progress save