# AI Review Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a safe PR-based Claude review and Codex review-application automation loop.

**Architecture:** GitHub Actions orchestrates the loop. Claude runs automatically as a PR reviewer and Codex runs only by manual dispatch to validate and optionally apply Claude feedback.

**Tech Stack:** GitHub Actions, `anthropics/claude-code-action@v1`, `openai/codex-action@v1`, Markdown prompts, JSON schemas.

---

### Task 1: Design And Usage Documentation

**Files:**
- Create: `Docs/superpowers/specs/2026-06-16-ai-review-loop-design.md`
- Create: `Docs/12-ai-review-automation.md`

- [ ] **Step 1: Write the design document**

Create `Docs/superpowers/specs/2026-06-16-ai-review-loop-design.md` with the architecture, permissions, rollout, and safety constraints.

- [ ] **Step 2: Write the operator guide**

Create `Docs/12-ai-review-automation.md` with required secrets, PR workflow, manual Codex apply workflow, and known limitations.

- [ ] **Step 3: Verify docs are discoverable**

Run:

```powershell
rg -n "AI Review Loop|ANTHROPIC_API_KEY|OPENAI_API_KEY|workflow_dispatch" Docs
```

Expected: matching lines in the design and operator guide.

### Task 2: Claude Review Prompt

**Files:**
- Create: `.github/claude/review.md`
- Create: `.github/claude/review.schema.json`

- [ ] **Step 1: Add Claude review prompt**

Create `.github/claude/review.md` so Claude reviews only PR changes and returns structured findings.

- [ ] **Step 2: Add Claude review schema**

Create `.github/claude/review.schema.json` with `summary`, `must_fix`, `optional`, and `verdict`.

- [ ] **Step 3: Verify schema parses**

Run:

```powershell
Get-Content .github\claude\review.schema.json -Raw | ConvertFrom-Json | Out-Null
```

Expected: command exits successfully.

### Task 3: Codex Apply Prompt

**Files:**
- Create: `.github/codex/apply-review.md`
- Create: `.github/codex/apply-review.schema.json`

- [ ] **Step 1: Add Codex apply prompt**

Create `.github/codex/apply-review.md` so Codex validates Claude feedback against actual code before applying changes.

- [ ] **Step 2: Add Codex report schema**

Create `.github/codex/apply-review.schema.json` with accepted, rejected, deferred, changed files, verification, and final verdict fields.

- [ ] **Step 3: Verify schema parses**

Run:

```powershell
Get-Content .github\codex\apply-review.schema.json -Raw | ConvertFrom-Json | Out-Null
```

Expected: command exits successfully.

### Task 4: GitHub Actions Workflow

**Files:**
- Create: `.github/workflows/ai-review-loop.yml`

- [ ] **Step 1: Add workflow**

Create `.github/workflows/ai-review-loop.yml` with:

- `pull_request` trigger for Claude review.
- `workflow_dispatch` trigger for manual Codex apply.
- restricted permissions per job.
- no automatic Codex push on PR events.

- [ ] **Step 2: Verify workflow contains required controls**

Run:

```powershell
rg -n "pull_request|workflow_dispatch|anthropics/claude-code-action@v1|openai/codex-action@v1|safety-strategy|fork" .github\workflows\ai-review-loop.yml
```

Expected: all required workflow controls appear.

### Task 5: Repository Setup

**Files:**
- Modify git metadata only.

- [ ] **Step 1: Initialize git if missing**

Run:

```powershell
git rev-parse --is-inside-work-tree
```

If it fails, run:

```powershell
git init
```

- [ ] **Step 2: Add remote if missing**

Run:

```powershell
git remote -v
```

If no `origin` exists, run:

```powershell
git remote add origin https://github.com/BXJin/VisionRuntimeIntegrationSystem.git
```

- [ ] **Step 3: Inspect final status**

Run:

```powershell
git status --short --branch
```

Expected: new automation files appear as untracked or staged changes.

