# Phase 3 — Test Coverage & QA

## Goal
Add automated validation for the Windows example and re-run repository checks to ensure the new Windows path and release selection integrate cleanly with existing test infrastructure.

## Scope
- Tests directory (Go Terratest files) for plan-only validation of the Windows example.
- Any supporting helper functions required to share setup logic with existing tests.
- No production Terraform changes beyond what Phases 1 and 2 delivered.

## Tasks
- [x] Implement `TestWindowsExamplePlan` (or similar) in `tests/` that runs `terraform.InitAndPlan` against `examples/windows` using the existing Terratest patterns, validating the default Windows release.
- [x] Optionally extend the test (or add a table-driven case) to plan with at least one alternate release (e.g., `2019`) to ensure the SSM mapping works.
- [x] Reuse helper utilities (e.g., SSH key scaffolding, AWS region selection) where possible to avoid duplication.
- [x] Update test README or comments if additional environment variables/permissions are needed for Windows plan validation.
- [x] Run Go test command focused on the new test and then the broader suite if time permits.

## Edge Cases to Address
- Ensure the test operates in plan-only mode so no EC2 instances are provisioned; fail fast if plan errors due to SSM parameter access or unsupported release values.
- Handle Windows AMI lookup latency or throttling gracefully (e.g., with retry logic already provided by Terratest).
- Confirm the test respects existing AWS credential handling (profile, region overrides).

## Acceptance Criteria
- New test passes locally (within project constraints) and is integrated into `go test ./tests` flow, covering the default Windows release and noting how to exercise alternates.
- Existing tests (Linux scenarios) continue to pass without modification.
- Documentation/test README mentions Windows coverage or prerequisites if materially different.

## Tests (Must be implemented in this phase)
- `go test -v -timeout 60m ./tests -run TestWindowsExamplePlan`.
- Optionally, `go test -v -timeout 60m ./tests` if runtime permits.
- Re-run Terraform format/validate commands to ensure consistent state after test additions.

## Verification Steps
- From repo root: execute the Go test commands above.
- Verify Terraform example directories remain formatted by running `terraform fmt -check` (repo root) after test changes.
