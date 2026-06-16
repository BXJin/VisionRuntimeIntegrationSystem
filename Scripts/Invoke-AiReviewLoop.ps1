param(
    [ValidateSet("ReviewOnly", "ApplyOnly", "Full")]
    [string]$Mode = "ReviewOnly",

    [string]$ImplementationSummary = "",

    [string]$BaseRef = "origin/main",

    [string]$ArtifactsDir = ".ai-review",

    [string]$ClaudeReviewPath = "",

    [switch]$SkipClaude,

    [switch]$SkipCodex
)

$ErrorActionPreference = "Stop"

function Resolve-RepoRoot {
    $root = git rev-parse --show-toplevel 2>$null
    if (-not $root) {
        throw "This script must run inside a git repository."
    }
    return $root.Trim()
}

function Assert-CommandExists {
    param([string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found on PATH."
    }
}

function Invoke-GitText {
    param([string[]]$Arguments)

    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $output = & git @Arguments 2>&1
        if ($LASTEXITCODE -ne 0) {
            return ""
        }
        return ($output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
}

function Test-GitRef {
    param([string]$Ref)

    & git rev-parse --verify $Ref *> $null
    return $LASTEXITCODE -eq 0
}

function Resolve-BaseRef {
    param([string]$RequestedBaseRef)

    if (Test-GitRef $RequestedBaseRef) {
        return $RequestedBaseRef
    }

    if (Test-GitRef "main") {
        return "main"
    }

    if (Test-GitRef "HEAD~1") {
        return "HEAD~1"
    }

    return ""
}

function New-ReviewContext {
    param(
        [string]$RepoRoot,
        [string]$SessionDir,
        [string]$ResolvedBaseRef,
        [string]$Summary
    )

    $status = Invoke-GitText -Arguments @("status", "--short", "--branch")
    $branch = Invoke-GitText -Arguments @("branch", "--show-current")
    $lastCommit = Invoke-GitText -Arguments @("log", "--oneline", "-1")
    $stagedStat = Invoke-GitText -Arguments @("diff", "--cached", "--stat")
    $worktreeStat = Invoke-GitText -Arguments @("diff", "--stat")
    $stagedDiff = Invoke-GitText -Arguments @("diff", "--cached")
    $worktreeDiff = Invoke-GitText -Arguments @("diff")

    if ($ResolvedBaseRef) {
        $branchStat = Invoke-GitText -Arguments @("diff", "--stat", "$ResolvedBaseRef...HEAD")
        $branchDiff = Invoke-GitText -Arguments @("diff", "$ResolvedBaseRef...HEAD")
    } else {
        $branchStat = "No base ref was available. This is probably the first commit."
        $branchDiff = ""
    }

    $diffPath = Join-Path $SessionDir "review-diff.patch"
    $contextPath = Join-Path $SessionDir "implementation-context.md"

    @"
# Review diff

## Branch diff against $ResolvedBaseRef

````diff
$branchDiff
````

## Staged diff

````diff
$stagedDiff
````

## Working tree diff

````diff
$worktreeDiff
````
"@ | Set-Content -Path $diffPath -Encoding UTF8

    if ([string]::IsNullOrWhiteSpace($Summary)) {
        $Summary = "No explicit implementation summary was provided. Infer intent from git diff, changed files, and nearby documentation."
    }

    @"
# Implementation context for Claude review

## Developer implementation summary

$Summary

## Repository

- Root: `$RepoRoot`
- Branch: `$branch`
- Base ref: `$ResolvedBaseRef`
- Last commit: `$lastCommit`

## Git status

````text
$status
````

## Branch diff stat

````text
$branchStat
````

## Staged diff stat

````text
$stagedStat
````

## Working tree diff stat

````text
$worktreeStat
````

## Full diff file

Read `$diffPath`.

## Review instruction

Review the implementation and diff as if you are reviewing a pull request. Focus on correctness, async/state risks, security, contract mismatches, missing tests, and maintainability risks. Do not request style-only changes.
"@ | Set-Content -Path $contextPath -Encoding UTF8

    return @{
        ContextPath = $contextPath
        DiffPath = $diffPath
    }
}

function Invoke-ClaudeReview {
    param(
        [string]$RepoRoot,
        [string]$SessionDir,
        [string]$ContextPath
    )

    $claudePromptPath = Join-Path $SessionDir "claude-review-prompt.md"
    $claudeOutputPath = Join-Path $SessionDir "claude-review.json"
    $reviewPrompt = Get-Content (Join-Path $RepoRoot ".github\claude\review.md") -Raw

    @"
$reviewPrompt

Additional local automation context:

- Read the implementation context at `$ContextPath`.
- Return JSON only.
"@ | Set-Content -Path $claudePromptPath -Encoding UTF8

    $prompt = Get-Content $claudePromptPath -Raw
    $schemaPath = Join-Path $RepoRoot ".github\claude\review.schema.json"
    $result = & claude -p $prompt --permission-mode dontAsk --json-schema $schemaPath
    if ($LASTEXITCODE -ne 0) {
        throw "Claude review failed with exit code $LASTEXITCODE."
    }

    ($result -join [Environment]::NewLine) | Set-Content -Path $claudeOutputPath -Encoding UTF8
    return $claudeOutputPath
}

function Invoke-CodexApply {
    param(
        [string]$RepoRoot,
        [string]$SessionDir,
        [string]$ClaudeReviewPath,
        [string]$ContextPath
    )

    $codexPromptPath = Join-Path $SessionDir "codex-apply-prompt.md"
    $codexOutputPath = Join-Path $SessionDir "codex-review-result.json"
    $applyPrompt = Get-Content (Join-Path $RepoRoot ".github\codex\apply-review.md") -Raw

    @"
$applyPrompt

Local automation context:

- Claude review JSON: `$ClaudeReviewPath`
- Implementation context: `$ContextPath`
- Repository root: `$RepoRoot`

Evaluate Claude's findings against the current repository. Apply only technically correct and relevant fixes. If no changes are needed, do not edit files.
"@ | Set-Content -Path $codexPromptPath -Encoding UTF8

    Get-Content $codexPromptPath -Raw | & codex exec -C $RepoRoot -s workspace-write --output-schema (Join-Path $RepoRoot ".github\codex\apply-review.schema.json") -o $codexOutputPath -
    if ($LASTEXITCODE -ne 0) {
        throw "Codex apply failed with exit code $LASTEXITCODE."
    }

    return $codexOutputPath
}

function Resolve-ClaudeReviewPath {
    param(
        [string]$RepoRoot,
        [string]$ArtifactsDir,
        [string]$RequestedPath
    )

    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        $resolved = Resolve-Path $RequestedPath -ErrorAction Stop
        return $resolved.Path
    }

    $artifactRoot = Join-Path $RepoRoot $ArtifactsDir
    if (-not (Test-Path $artifactRoot)) {
        return ""
    }

    $latest = Get-ChildItem -Path $artifactRoot -Filter "claude-review.json" -Recurse |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if ($latest) {
        return $latest.FullName
    }

    return ""
}

$repoRoot = Resolve-RepoRoot
Set-Location $repoRoot

Assert-CommandExists "git"
Assert-CommandExists "claude"
Assert-CommandExists "codex"

$resolvedBaseRef = Resolve-BaseRef $BaseRef
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$sessionDir = Join-Path $repoRoot (Join-Path $ArtifactsDir $timestamp)
New-Item -ItemType Directory -Force -Path $sessionDir | Out-Null

$context = New-ReviewContext -RepoRoot $repoRoot -SessionDir $sessionDir -ResolvedBaseRef $resolvedBaseRef -Summary $ImplementationSummary

$claudeReviewPath = Join-Path $sessionDir "claude-review.json"
if ($Mode -in @("ReviewOnly", "Full") -and -not $SkipClaude) {
    $claudeReviewPath = Invoke-ClaudeReview -RepoRoot $repoRoot -SessionDir $sessionDir -ContextPath $context.ContextPath
} elseif ($Mode -eq "ApplyOnly") {
    $resolvedClaudeReviewPath = Resolve-ClaudeReviewPath -RepoRoot $repoRoot -ArtifactsDir $ArtifactsDir -RequestedPath $ClaudeReviewPath
    if (-not $resolvedClaudeReviewPath) {
        throw "ApplyOnly mode requires an existing Claude review. Run ReviewOnly first or pass -ClaudeReviewPath."
    }
    $claudeReviewPath = $resolvedClaudeReviewPath
} elseif (-not (Test-Path $claudeReviewPath)) {
    @"
{
  "summary": "Claude review was skipped.",
  "must_fix": [],
  "optional": [],
  "verdict": "approve"
}
"@ | Set-Content -Path $claudeReviewPath -Encoding UTF8
}

$codexResultPath = ""
if ($Mode -in @("ApplyOnly", "Full") -and -not $SkipCodex) {
    $codexResultPath = Invoke-CodexApply -RepoRoot $repoRoot -SessionDir $sessionDir -ClaudeReviewPath $claudeReviewPath -ContextPath $context.ContextPath
}

Write-Host "AI review session created:"
Write-Host "  Context: $($context.ContextPath)"
Write-Host "  Diff:    $($context.DiffPath)"
Write-Host "  Claude:  $claudeReviewPath"
if ($codexResultPath) {
    Write-Host "  Codex:   $codexResultPath"
}
