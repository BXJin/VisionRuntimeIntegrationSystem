# AI review automation

## Purpose

This repository uses a local semi-automatic AI review loop:

```text
Codex implements changes
-> local script captures git diff and implementation context
-> Claude Code reviews the local diff or receives a handoff in an existing session
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
2. For context-preserving review, generate a handoff:

```powershell
.\Scripts\Invoke-AiReviewLoop.ps1 -Mode HandoffOnly -PairName vision-gateway -ImplementationSummary "What Codex changed and why"
```

3. Paste `.ai-review/vision-gateway/<timestamp>/handoff.md` into the matching Claude session.
4. Paste Claude's feedback back into the matching Codex session.
5. For a new Claude CLI review session instead, run:

```powershell
.\Scripts\Invoke-AiReviewLoop.ps1 -Mode ReviewOnly -ImplementationSummary "What Codex changed and why"
```

6. Read `.ai-review/<pair-name>/<timestamp>/claude-review.json`.
7. If the review looks worth applying in a new Codex exec session, run:

```powershell
.\Scripts\Invoke-AiReviewLoop.ps1 -Mode Full -ImplementationSummary "What Codex changed and why"
```

   Or apply a previous Claude review:

```powershell
.\Scripts\Invoke-AiReviewLoop.ps1 -Mode ApplyOnly -ClaudeReviewPath .ai-review\<timestamp>\claude-review.json
```

8. Review Codex's accepted, rejected, and deferred decisions.
9. Commit only after normal tests and human review are acceptable.

## Multiple active Codex-Claude pairs

Multiple handoffs can exist at the same time. Use `-PairName` to keep lanes separated:

```powershell
.\Scripts\Invoke-AiReviewLoop.ps1 -Mode HandoffOnly -PairName python-gateway -ImplementationSummary "..."
.\Scripts\Invoke-AiReviewLoop.ps1 -Mode HandoffOnly -PairName cpp-client -ImplementationSummary "..."
.\Scripts\Invoke-AiReviewLoop.ps1 -Mode HandoffOnly -PairName docs-review -ImplementationSummary "..."
```

Artifacts are stored as:

```text
.ai-review/<pair-name>/<yyyyMMdd-HHmmss>/
  handoff.md
  implementation-context.md
  review-diff.patch
  claude-review.json
```

If several handoffs are active, refer to the pair name and timestamp when asking Codex to apply or interpret feedback.

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
- For important context-sensitive work, prefer `HandoffOnly` and an existing Claude session.

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
