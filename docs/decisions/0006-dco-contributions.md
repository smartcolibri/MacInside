# 0006 - Contributions under the DCO

- Status: Accepted
- Date: 2026-10-11

## Context

MacInside is MIT-licensed and public. MIT already means inbound = outbound, but the maintainer wants an explicit statement of origin on each contribution without the weight of a CLA.

## Decision

Contributions require the [Developer Certificate of Origin](https://developercertificate.org/): every commit carries a `Signed-off-by` line (`git commit -s`). A CI job named `dco` enforces it on pull requests. No CLA.

## Consequences

- Contributors must sign off each commit; unsigned PRs fail CI.
- Agents contributing to the repo must sign off too (see AGENTS.md).
- Documented in CONTRIBUTING.md.
