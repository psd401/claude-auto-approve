---
type: Operations Guide
title: OpenWiki Wiki Maintenance Workflow
description: How the openwiki/ knowledge base is refreshed by the GitHub Actions caller workflow, what triggers it, how concurrency and path filters prevent loops, and which parts live outside this repository.
tags: [openwiki, github-actions, ci, documentation, delivery]
timestamp: 2026-10-08T22:53:10Z
openwiki:
  roles: [delivery, operations, repository]
  change_kinds: [ci-workflow, documentation-refresh]
  source_paths: [.github/workflows/openwiki-update.yml]
  symbols: [openwiki job, concurrency group openwiki]
  test_paths: []
  invariants:
    - Pushes that only touch openwiki/** do not trigger a refresh.
    - Only the newest queued refresh survives; earlier runs are cancelled.
    - The reusable workflow is referenced by branch and is not vendored in this repository.
  validation_commands: []
---

# OpenWiki Wiki Maintenance Workflow

The `openwiki/` directory is generated documentation. It is refreshed by a GitHub Actions workflow that wraps an organization-owned reusable workflow. This repository holds only the thin caller; the generation logic is not in this repository.

## When to consult this page

Consult this page when the wiki is stale, when a refresh does not run, or when changing the workflow triggers. Do not hand-edit generated pages as a routine fix; the shared agent instructions in `AGENTS.md` (untracked in the working tree) ask for source or README changes that let the refresh regenerate the pages.

## Trigger model

`.github/workflows/openwiki-update.yml` runs on three triggers:

- `push` to `main`, with `paths-ignore: openwiki/**`. The ignore is what stops the auto-merged documentation pull request from retriggering the job; the commit that added the workflow records this as its reason.
- `schedule` every Monday at 08:00 UTC (`0 8 * * 1`).
- `workflow_dispatch` for manual runs.

The job calls `PSD401/.github/.github/workflows/reusable-openwiki.yml@main` with `base_branch: main`, and passes `secrets: inherit`.

## Concurrency

The workflow uses the concurrency group `openwiki` with `cancel-in-progress: true`. When several merges land in a row, only the latest run continues, because the output of an earlier run is superseded anyway.

## Permissions

The job requests `contents: write` and `pull-requests: write`. The comment in the workflow notes that the calling repository must grant these, because the organization default token is read-only.

## Deliberate choices

- The reusable workflow is pinned to `@main`, not to a tag or SHA. The workflow comment states this is intentional so central changes propagate to every repository, and two `zizmor: ignore[unpinned-uses]` comments suppress the scanner's finding for that reference. The [security scan workflow](security-scan-workflow.md) uses the same pinning convention and suppression.
- The caller contains no build steps. Changing how the wiki is generated, which model is used, or how pull requests are opened must happen in the reusable workflow, not here.

## What is not verifiable from this repository

The reusable workflow's steps, model choice, and pull-request handling are outside this repository. The commit that added the caller describes a first build from scratch that opens a docs-only pull request limited to `openwiki/`, but that behavior is stated only in the commit message. Treat it as historical context, not a verified contract of this repository.

## Invariants for future changes

- Keep `paths-ignore: openwiki/**` on the push trigger. Removing it would make each refresh trigger another refresh.
- Keep the concurrency group, so overlapping refresh runs are cancelled instead of queued.
- Do not add a `paths` filter that excludes source files, because the wiki must refresh when the hook or its tests change.

## Focused validation

There are no unit tests for the workflow. The narrowest check is a YAML review of `.github/workflows/openwiki-update.yml` and a manual `workflow_dispatch` run in the hosting platform after a change. Local validation is not defined for this repository.

## Related pages

- [Quickstart](../quickstart.md) explains how to use this wiki.
- [Design history](../architecture/design-history.md) records when the OpenWiki caller was added.
- [Claude review workflow](claude-review-workflow.md) is the third thin caller that uses the same `@main` pinning convention.
