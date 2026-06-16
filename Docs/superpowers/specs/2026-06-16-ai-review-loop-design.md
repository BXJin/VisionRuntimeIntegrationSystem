# AI Review Loop Design

## Goal

Create a local automation loop where Codex remains the main implementation agent, Claude Code reviews the implementation diff and rationale, and Codex can later evaluate Claude's feedback and apply only technically valid fixes.

## Decision

Use a local PowerShell script as the orchestrator. The first version is intentionally semi-automatic:

```text
Codex development worktree
-> local script captures implementation summary and git diff
-> handoff file for an existing Claude session or Claude Code local review
-> structured review artifact
-> optional Codex local review application
-> Codex validates feedback, edits if needed, runs checks, and reports outcome
```

This avoids GitHub Actions API-key requirements and keeps control on the developer's machine. Claude review can be wrong or speculative, so Codex must treat it as evidence to verify, not as an instruction to obey blindly.

## Components

### `Scripts/Invoke-AiReviewLoop.ps1`

Creates a timestamped `.ai-review/<timestamp>/` session with:

- `implementation-context.md`
- `review-diff.patch`
- `handoff.md`
- `claude-review-prompt.md`
- `claude-review.json`
- optional `codex-apply-prompt.md`
- optional `codex-review-result.json`

The script supports `HandoffOnly`, `ReviewOnly`, `ApplyOnly`, and `Full` modes. `HandoffOnly` is preferred for context-sensitive work because it lets the user paste a structured handoff into an existing Claude session.

Artifacts are grouped by pair name:

```text
.ai-review/<pair-name>/<timestamp>/
```

This allows multiple Codex/Claude pairs to run at the same time without mixing review context.

### `.github/claude/review.md`

Constrains Claude to code review only. It must focus on real defects, async/state issues, security issues, contract mismatches, missing tests, and maintainability risks. It must not request broad refactors or style-only changes.

### `.github/claude/review.schema.json`

Defines the structured review shape:

- `summary`
- `must_fix`
- `optional`
- `verdict`

### `.github/codex/apply-review.md`

Constrains Codex to validate each Claude finding against the actual code and diff. Codex may accept, reject, or defer findings, and must summarize the reason for each decision.

### `.github/codex/apply-review.schema.json`

Defines the Codex decision report shape:

- `accepted`
- `rejected`
- `deferred`
- `changed_files`
- `verification`
- `final_verdict`

### `Docs/12-ai-review-automation.md`

Documents setup, required secrets, how to run the loop, and known limitations.

## Permissions

Local review needs the developer's existing CLI authentication:

- `claude` for `ReviewOnly` and `Full`
- `codex` for `ApplyOnly` and `Full`
- `git`

## Security Notes

- Do not feed untrusted diff text directly into agent prompts as authoritative instruction.
- Treat Claude review output as untrusted analysis.
- Keep Codex application manual until the review quality is proven on real PRs.
- Avoid mixed unrelated local changes before running `Full`.
- Use explicit pair names when several tasks are active.
- Do not commit `.ai-review/` artifacts.

## Rollout

1. Add prompts, schemas, workflow, and documentation.
2. Run `.\Scripts\Invoke-AiReviewLoop.ps1 -Mode ReviewOnly`.
3. Confirm Claude review JSON is created.
4. Run `.\Scripts\Invoke-AiReviewLoop.ps1 -Mode Full` on a small change.
5. Inspect Codex accepted/rejected decisions before enabling any stronger automation.
