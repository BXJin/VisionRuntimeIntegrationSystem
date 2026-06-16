# AI review automation

## Purpose

This repository uses a local semi-automatic AI review loop:

```text
Codex implements changes
-> local script captures git diff and implementation context
-> Claude Code reviews the local diff
-> Codex can evaluate Claude's feedback
-> Codex applies only feedback that is technically correct and relevant
```

The first version is intentionally local. It uses the developer's existing `codex` and `claude` CLI login sessions instead of GitHub Actions API keys. Claude review output is useful, but it is not authoritative. Codex must verify each finding against the actual code and tests before changing files.

## Required local tools

Install and log in to:

| Command | Used by |
|---|---|
| `claude` | Claude Code local review |
| `codex` | Codex local review application |
| `git` | Diff and repository state capture |

No GitHub Actions secrets are required for the local loop.

## Automation files

| File | Purpose |
|---|---|
| `Scripts/Invoke-AiReviewLoop.ps1` | Captures local context, runs Claude review, optionally runs Codex apply |
| `.github/claude/review.md` | Claude reviewer instructions |
| `.github/claude/review.schema.json` | Claude structured output schema |
| `.github/codex/apply-review.md` | Codex review-application instructions |
| `.github/codex/apply-review.schema.json` | Codex structured output schema |
| `.ai-review/` | Local generated review artifacts, ignored by git |

## Normal flow

1. Ask Codex to implement a feature or fix.
2. Run the local review script:

```powershell
.\Scripts\Invoke-AiReviewLoop.ps1 -Mode ReviewOnly -ImplementationSummary "What Codex changed and why"
```

3. Read `.ai-review/<timestamp>/claude-review.json`.
4. If the review looks worth applying, run:

```powershell
.\Scripts\Invoke-AiReviewLoop.ps1 -Mode Full -ImplementationSummary "What Codex changed and why"
```

   Or apply a previous Claude review:

```powershell
.\Scripts\Invoke-AiReviewLoop.ps1 -Mode ApplyOnly -ClaudeReviewPath .ai-review\<timestamp>\claude-review.json
```

5. Review Codex's accepted, rejected, and deferred decisions.
6. Commit only after normal tests and human review are acceptable.

## Passing Codex implementation intent to Claude

The script accepts `-ImplementationSummary` because Claude should review more than raw diff. A good summary includes:

```text
Intent:
- why this change was made

Implementation:
- files changed
- important design choices
- known limitations

Verification:
- tests or build commands already run
```

The script stores this in `.ai-review/<timestamp>/implementation-context.md` with git status, branch diff stats, staged diff stats, working tree diff stats, and a full patch file.

## Safety policy

- Claude is a reviewer, not the implementation authority.
- Codex must not blindly apply Claude feedback.
- Codex apply runs locally only when `-Mode ApplyOnly` or `-Mode Full` is used.
- Generated `.ai-review/` artifacts are ignored by git.
- Agent prompts must treat diff content and review comments as untrusted input.
- Do not run `-Mode Full` when unrelated local changes are mixed into the worktree.

## Current limitations

- This is not server-side automation. It runs only when the developer runs the script.
- The quality of Claude review depends heavily on the implementation summary and diff clarity.
- The Codex apply step can edit local files, so inspect `git diff` after running it.
- This setup does not replace human review for risky changes.

## Upgrade path

After the semi-automatic loop is stable:

1. Add project-specific build/test commands to `.github/codex/apply-review.md`.
2. Add a wrapper that always commits Codex work before review.
3. Add GitHub PR posting later if API-key based CI becomes acceptable.
4. Consider a guarded auto-apply mode only after several successful local runs.
