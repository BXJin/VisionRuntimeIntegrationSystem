# AI review automation

## Purpose

This repository uses a semi-automatic AI review loop:

```text
Codex implements changes
-> developer opens a pull request
-> Claude Code reviews the PR diff
-> Codex can be manually triggered to evaluate Claude's feedback
-> Codex applies only feedback that is technically correct and relevant
```

The first version is intentionally not fully automatic. Claude review output is useful, but it is not authoritative. Codex must verify each finding against the actual code and tests before changing files.

## Required GitHub secrets

Add these repository secrets before enabling the workflow:

| Secret | Used by |
|---|---|
| `ANTHROPIC_API_KEY` | Claude Code review job |
| `OPENAI_API_KEY` | Codex review-application job |

## Workflow files

| File | Purpose |
|---|---|
| `.github/workflows/ai-review-loop.yml` | Runs Claude PR review and manual Codex review application |
| `.github/claude/review.md` | Claude reviewer instructions |
| `.github/claude/review.schema.json` | Claude structured output schema |
| `.github/codex/apply-review.md` | Codex review-application instructions |
| `.github/codex/apply-review.schema.json` | Codex structured output schema |

## Normal flow

1. Ask Codex to implement a feature or fix.
2. Commit and push the feature branch.
3. Open a pull request.
4. The `claude_review` job runs automatically.
5. Read the Claude review summary and artifact.
6. If the review looks worth applying, run the workflow manually:

```text
Actions
-> AI Review Loop
-> Run workflow
-> pr_number: <pull request number>
```

7. Review Codex's accepted, rejected, and deferred decisions.
8. Merge only after normal tests and human review are acceptable.

## Safety policy

- Claude is a reviewer, not the implementation authority.
- Codex must not blindly apply Claude feedback.
- Codex apply runs through `workflow_dispatch`, not automatically on every PR update.
- Fork pull requests do not run the first-pass AI review/apply workflow.
- Agent prompts must treat PR content and review comments as untrusted input.
- Full agent logs should stay disabled unless debugging a non-sensitive repository.

## Current limitations

- The workflow cannot be fully verified until the repository is pushed to GitHub and secrets are configured.
- The manual Codex job requires a non-expired `claude-review-pr-<number>` artifact from a previous Claude review run.
- The Claude review artifact shape depends on `anthropics/claude-code-action@v1` structured output behavior.
- The Codex apply job is manual by design. Automatic push loops should be considered only after several successful PR runs.
- This setup does not replace human review for risky changes.

## Upgrade path

After the semi-automatic loop is stable:

1. Require Claude `verdict=request_changes` before allowing Codex apply.
2. Add project-specific build/test commands to `.github/codex/apply-review.md`.
3. Add branch protection so AI changes require passing checks.
4. Consider a guarded auto-apply mode for trusted internal branches only.
