---
type: Operations Guide
title: GitHub Actions Pinning and Dependabot
description: How every GitHub Actions uses reference in the repository's workflows is pinned to a full commit SHA with a version comment, how Dependabot keeps those pins current on a weekly schedule with a 7-day cooldown, and why the earlier @main convention was removed. Use when changing a uses line, bumping a reusable workflow, or handling a Dependabot pull request.
tags: [github-actions, supply-chain, ci, delivery, operations]
timestamp: 2026-10-22T05:29:06Z
openwiki:
  roles: [delivery, operations]
  change_kinds: [dependency-pinning, ci-workflow]
  source_paths: [.github/dependabot.yml, .github/workflows/claude-review.yml, .github/workflows/openwiki-update.yml, .github/workflows/security-scan.yml]
  symbols: [uses reference, package-ecosystem github-actions, cooldown default-days]
  test_paths: []
  invariants:
    - Every uses reference in .github/workflows is a full 40-character commit SHA followed by a same-line version comment.
    - No uses reference points at @main, and no zizmor unpinned-uses suppression remains.
    - Dependabot checks github-actions weekly and waits 7 days before proposing an update.
  validation_commands: ["grep -rn 'uses:' .github/workflows", "grep -rn '@main' .github/workflows"]
---

# GitHub Actions Pinning and Dependabot

Every external `uses:` reference in this repository's workflows is pinned to a full commit SHA with a `# vX.Y.Z` comment on the same line. A Dependabot configuration keeps those pins current. The policy comes from the organization standard `psd-dev-standards` `standards/06` section 4 (Pinning), which the commit message and the `.github/dependabot.yml` header both cite. The change was made in commit `17c715e` ("ci: pin every GitHub Actions uses: ref to a commit SHA").

## When to consult this page

Consult this page when you change any `uses:` line, when a reusable workflow needs a new version, or when a Dependabot pull request touches `.github/workflows/`. Do not return a reference to `@main` as a shortcut. The three callers are described in [Claude review workflow](claude-review-workflow.md), [Security scan workflow](security-scan-workflow.md), and [Wiki maintenance](wiki-maintenance.md).

## Current pins

All three `uses:` references point at the same organization-owned reusable workflows in `PSD401/.github`, pinned to release `v1.0.0`. Each caller carries its own pin.

| Caller | Pinned reference | Pin |
|---|---|---|
| `.github/workflows/claude-review.yml` | `reusable-claude-review.yml` | `1aa5f5351a78b15f5c71668037f5d35b9613ae41 # v1.0.0` |
| `.github/workflows/openwiki-update.yml` | `reusable-openwiki.yml` | `1aa5f5351a78b15f5c71668037f5d35b9613ae41 # v1.0.0` |
| `.github/workflows/security-scan.yml` | `reusable-security-scan.yml` | `1aa5f5351a78b15f5c71668037f5d35b9613ae41 # v1.0.0` |

The commit message says the pinned SHA is the same code that `@main` ran on 2026-10-21, so the commit did not change what runs. The reusable workflow files are not in this repository, so their contents at that SHA cannot be verified here. The commit also describes resolving tag refs of other actions to commit SHAs; no such `uses:` line remains in the tree at HEAD.

## Dependabot configuration

`.github/dependabot.yml` has one update entry:

- `package-ecosystem: github-actions` with `directory: /`, so Dependabot scans the workflow files at the repository root.
- `schedule.interval: weekly`.
- `cooldown.default-days: 7`, so a newly released version is proposed only after it has been published for a week.

Dependabot proposes the version bump that moves each SHA pin. Those bumps are the only route for central updates to reach this repository, which replaces the automatic propagation that `@main` provided.

## Why the pins replaced `@main`

The commit message gives the reasoning. A reference to `@main` runs whatever is on that branch at the moment a workflow starts. Any merge into the organization's reusable workflows therefore ran immediately in this repository, with the permissions and secrets that this repository grants its callers. A pinned SHA makes each change to the reusable code an explicit, reviewable pull request. The earlier `zizmor: ignore[unpinned-uses]` comments existed only to silence the scanner's finding about `@main`, so they were removed with the references.

The commit message also records an external dependency: the organization security-scan reusable workflow will fail any unpinned `uses:` reference once its next release lands, and the org setting `sha_pinning_required` is being turned on. Both are stated in the commit message, not verified in this repository.

## Invariants for future changes

- Keep each external `uses:` reference as a 40-character SHA with a same-line version comment. The comment is what a reader uses to see which release is pinned.
- Do not reintroduce `@main`, a tag without a SHA, or `zizmor` suppressions for `unpinned-uses`.
- When you bump a pin by hand, update the SHA and its version comment together, and check that all three callers still agree on the reusable workflow version.
- Keep the github-actions Dependabot entry. Without it, the pins stop receiving updates.
- Dependabot pull requests bypass the Claude review because `claude-review.yml` skips actor `dependabot[bot]`. The security scan has no actor guard, so it runs on those pull requests.

## Focused validation

There are no tests or local build for workflow files. Use these read-only checks:

- `grep -rn 'uses:' .github/workflows` lists every external reference; each line must show a 40-character SHA and a version comment.
- `grep -rn '@main' .github/workflows` should print nothing.

The Dependabot configuration is validated by the hosting platform. After a change, check the Dependabot section of the repository's Actions or security settings for parse errors. A full workflow run is the only proof that a pinned reference resolves, and it belongs to the owning caller's page.

## Evidence limits

The contents of the reusable workflows at `1aa5f53` are not in this repository. The organization standard and the `sha_pinning_required` rollout are cited only from commit messages. The quickstart [backlog](../quickstart.md#backlog) tracks the reusable workflow internals as evidence-blocked.

## Related pages

- [Claude review workflow](claude-review-workflow.md) pins its reusable review workflow and grants `id-token: write`.
- [Security scan workflow](security-scan-workflow.md) pins its reusable scan workflow and grants read-only permission.
- [Wiki maintenance](wiki-maintenance.md) pins its reusable OpenWiki workflow and limits its secrets to two named values.
- [Architecture overview](../architecture/overview.md) lists the workflow files and Dependabot config as repository components.
- [Design history](../architecture/design-history.md) records the workflow additions that this policy now governs.
