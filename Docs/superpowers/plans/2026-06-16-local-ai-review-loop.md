# Local AI Review Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a local Claude review and Codex review-application loop that uses the developer's existing CLI sessions.

**Architecture:** A PowerShell script captures git status, branch diff, staged diff, working tree diff, and the developer's implementation summary into `.ai-review/<timestamp>/`. Claude reviews that local context. Codex can then read Claude's JSON and apply only technically valid findings.

**Tech Stack:** PowerShell, git, Claude Code CLI, Codex CLI, Markdown prompts, JSON schemas.

---

### Task 1: Local Script

**Files:**
- Create: `Scripts/Invoke-AiReviewLoop.ps1`

- [x] **Step 1: Add script parameters**

The script supports:

```powershell
-Mode ReviewOnly|ApplyOnly|Full
-ImplementationSummary "<summary>"
-BaseRef origin/main
-ArtifactsDir .ai-review
-ClaudeReviewPath .ai-review\<timestamp>\claude-review.json
-SkipClaude
-SkipCodex
```

- [x] **Step 2: Capture repository context**

The script writes:

```text
.ai-review/<timestamp>/implementation-context.md
.ai-review/<timestamp>/review-diff.patch
```

- [x] **Step 3: Run Claude local review**

The script calls:

```powershell
claude -p <prompt> --permission-mode dontAsk --json-schema .github/claude/review.schema.json
```

- [x] **Step 4: Run Codex local apply**

The script calls:

```powershell
codex exec -C <repo> -s workspace-write --output-schema .github/codex/apply-review.schema.json -o <result> -
```

### Task 2: Prompts And Schemas

**Files:**
- Create: `.github/claude/review.md`
- Create: `.github/claude/review.schema.json`
- Create: `.github/codex/apply-review.md`
- Create: `.github/codex/apply-review.schema.json`

- [x] **Step 1: Keep Claude as reviewer**

Claude is constrained to real PR-style review findings.

- [x] **Step 2: Keep Codex as verifier**

Codex is constrained to validate Claude findings against actual code before applying changes.

### Task 3: Documentation

**Files:**
- Create: `Docs/12-ai-review-automation.md`
- Create: `Docs/superpowers/specs/2026-06-16-ai-review-loop-design.md`
- Create: `Docs/superpowers/plans/2026-06-16-local-ai-review-loop.md`

- [x] **Step 1: Document local usage**

The docs describe `ReviewOnly` and `Full` modes.

- [x] **Step 2: Document tradeoffs**

The docs state that local automation avoids GitHub API secrets but is not server-side CI automation.

### Task 4: Verification

**Files:**
- Generated only: `.ai-review/<timestamp>/...`

- [x] **Step 1: Dry-run without AI calls**

Run:

```powershell
.\Scripts\Invoke-AiReviewLoop.ps1 -Mode ReviewOnly -ImplementationSummary "Dry run for local AI review loop script." -SkipClaude -SkipCodex
```

Expected: context, diff, and Claude placeholder JSON paths are printed.
