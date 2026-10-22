---
type: Operations Guide
title: Security Scan Workflow
description: How the org security scan runs for claude-auto-approve through a thin GitHub Actions caller of an organization-owned reusable workflow, its triggers, read-only permissions, and its full commit SHA pin. Use when the scan does not run or when changing its triggers or permissions.
tags: [security, github-actions, ci, delivery, operations]
timestamp: 2026-10-22T05:29:06Z
openwiki:
  roles: [delivery, operations]
  change_kinds: [ci-workflow, security-scan]
  source_paths: [.github/workflows/security-scan.yml]
  symbols: [security-scan job, reusable-security-scan.yml]
  test_paths: []
  invariants:
    - The scan job requests only contents: read; it does not inherit secrets.
    - The reusable scan is pinned to commit 1aa5f5351a78b15f5c71668037f5d35b9613ae41 (v1.0.0), so a new version reaches this repository only through a reviewed pin change.
    - The scan runs on pull requests, pushes to main, a weekly cron, and manual dispatch.
  validation_commands: []
---

# Security Scan Workflow

`.github/workflows/security-scan.yml` is the repository's security scan. Like the [OpenWiki caller](wiki-maintenance.md), it is a thin caller: the scan logic lives in `PSD401/.github/.github/workflows/reusable-security-scan.yml`, an organization-owned workflow that is not vendored in this repository. The `uses:` line pins it to commit `1aa5f5351a78b15f5c71668037f5d35b9613ae41` (v1.0.0). This repository's file only decides when the scan runs and what permissions it gets. The pinning policy is in [GitHub Actions pinning and Dependabot](action-pinning-and-dependabot.md).

## When to consult this page

Consult this page when the security scan does not start, when its permissions fail, or when changing its triggers. Scan findings and rule behavior are in the reusable workflow, which this repository cannot inspect. Do not add scanner logic to this file; change the reusable workflow instead.

## Trigger model

The workflow runs on four triggers:

- `pull_request`, so every pull request is scanned before merge.
- `push` to `main`.
- `schedule` with cron `0 9 * * 1`, every Monday at 09:00 UTC. This is one hour after the OpenWiki refresh cron (`0 8 * * 1`) in [Wiki maintenance](wiki-maintenance.md).
- `workflow_dispatch` for manual runs.

Unlike the OpenWiki caller, the scan has no `paths-ignore` or `paths` filter, and no `concurrency` group. Every matching event starts a run.

## Permissions

The workflow sets `permissions: contents: read` at the top level and again on the `security-scan` job. The job does not request write scopes and passes no `secrets` block, so the reusable scan receives only the default token scope. This is the opposite of the [OpenWiki caller](wiki-maintenance.md), which needs `contents: write` and `pull-requests: write` and passes two named secrets.

## Deliberate choices

- The reusable workflow is pinned to a full commit SHA with a `# v1.0.0` comment. An earlier `@main` reference and its `zizmor: ignore[unpinned-uses]` suppressions were removed in commit `17c715e`. The reason is recorded in [GitHub Actions pinning and Dependabot](action-pinning-and-dependabot.md).

## Invariants for future changes

- Keep the job at `contents: read`. Granting write access here is not needed for a read-only scan.
- Keep the SHA pin and its version comment together. Do not return to `@main`; central updates now arrive as Dependabot pin bumps.
- Keep the weekly schedule and `workflow_dispatch` so a scan can be rerun without a code change.

## Focused validation

There are no tests for this workflow and no local build. The narrowest check is a YAML review of `.github/workflows/security-scan.yml`, plus a manual `workflow_dispatch` run on the hosting platform after a change. The scan result itself is produced by the reusable workflow, so validate that outcome in the platform's Actions run, not by reading this file.

## Evidence limits

The reusable workflow's steps, scanner set, and failure behavior are not in this repository. This page describes only the caller. Those details are tracked as an evidence-blocked item in the [quickstart backlog](../quickstart.md#backlog).

## Related pages

- [Wiki maintenance](wiki-maintenance.md) describes the sibling OpenWiki caller.
- [GitHub Actions pinning and Dependabot](action-pinning-and-dependabot.md) owns the SHA pin policy and the weekly Dependabot update that moves it.
- [Claude review workflow](claude-review-workflow.md) is the sibling review caller that also grants `id-token: write`.
- [Architecture overview](../architecture/overview.md) lists this workflow among the repository's components.
- [Design history](../architecture/design-history.md) records when the scan was added.
