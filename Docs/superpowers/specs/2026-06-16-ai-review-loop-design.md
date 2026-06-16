# AI Review Loop Design

## Goal

Create a PR-based automation loop where Codex remains the main implementation agent, Claude Code performs automated pull request review, and Codex can later evaluate Claude's feedback and apply only technically valid fixes.

## Decision

Use GitHub Actions as the orchestrator. The first version is intentionally semi-automatic:

```text
Codex development branch
-> pull request
-> Claude Code review job
-> structured review artifact and PR summary
-> manual workflow_dispatch for Codex review application
-> Codex validates feedback, edits if needed, runs checks, and reports outcome
```

This avoids giving two agents an unrestricted automatic edit loop. Claude review can be wrong or speculative, so Codex must treat it as evidence to verify, not as an instruction to obey blindly.

## Components

### `.github/workflows/ai-review-loop.yml`

Defines two jobs:

- `claude_review`: runs on pull request open, synchronize, reopen, and ready-for-review events.
- `codex_apply_review`: runs only through `workflow_dispatch` with a pull request number.

The Claude job uses `anthropics/claude-code-action@v1` with a repository prompt and JSON schema. It uploads structured output as an artifact and comments a summary on the PR. The first-pass workflow skips fork pull requests.

The Codex job checks out the PR branch, downloads the latest non-expired Claude review artifact for the PR, runs `openai/codex-action@v1` with a review-application prompt, and uploads Codex's final report.

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

Claude review needs:

- `contents: read`
- `pull-requests: write`
- `issues: write`

Codex apply needs:

- `contents: write`
- `pull-requests: write`
- `issues: write`
- `actions: read`

The Codex apply job must not run for fork pull requests. It is manually triggered and limited to users with repository write access by `openai/codex-action`.

## Required Secrets

- `ANTHROPIC_API_KEY`
- `OPENAI_API_KEY`

## Security Notes

- Do not feed untrusted PR body text directly into agent prompts as authoritative instruction.
- Treat Claude review output as untrusted analysis.
- Keep Codex application manual until the review quality is proven on real PRs.
- Avoid `danger-full-access` and avoid automatic push loops on pull request events.
- Do not enable full Claude logs unless debugging a non-sensitive repository.

## Rollout

1. Add prompts, schemas, workflow, and documentation.
2. Push the repository to GitHub.
3. Add required secrets.
4. Open a small test PR.
5. Confirm Claude review artifact/comment is created.
6. Manually run Codex apply for that PR.
7. Inspect Codex accepted/rejected decisions before enabling any stronger automation.
