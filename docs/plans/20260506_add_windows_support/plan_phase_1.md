# Phase 1 — Windows AMI Resolution

## Goal
Enable the module to resolve the Windows Server Full-Base AMI that matches `ec2_ami_os_release` (default `2022`, plus `2019` and `2025`) when callers set `ec2_ami_os = "windows"`, without altering existing metadata or disk encryption behavior.

## Scope
- Terraform module core (`main.tf` locals/data sources, `aws_instance` resource configuration).
- Variable and map documentation within `variables.tf` as needed to mention the Windows option.
- No changes to metadata options, block devices, or downstream consumers beyond AMI selection.

## Tasks
- [x] Add `data "aws_ssm_parameter" "windows_ami"` in `main.tf` that reads from the release-specific parameter (e.g., `/aws/service/ami-windows-latest/Windows_Server-2022-English-Full-Base`) derived from a lookup map.
- [x] Define a local map that keys supported Windows releases (`2019`, `2022`, `2025`) to their SSM parameter names and validate lookup behavior.
- [x] Introduce a local (e.g., `local.resolved_ami_id`) that selects between `var.ec2_ami_id`, the SSM-resolved Windows AMI, or the existing Linux `aws_ami` lookup, and update `aws_instance.ami` to use it.
- [x] Ensure existing Linux locals/maps remain intact; do not modify metadata or root block sections.
- [x] Update `variables.tf` description of `ec2_ami_os` to list `windows` as an allowed value and clarify that `ec2_ami_os_release` controls Windows version selection.
- [x] Run module-level formatting and validation commands to confirm Terraform is still syntactically valid.

## Edge Cases to Address
- Missing/unauthorized SSM parameter access should present a clear Terraform error (documented in commit/notes).
- Invalid `ec2_ami_os` values still trigger Terraform lookup errors; no silent fallback.
- Unsupported `ec2_ami_os_release` strings for Windows emit clear errors (e.g., via `lookup` default handling).
- Caller supplied `ec2_ami_id` continues to bypass lookup logic entirely.

## Acceptance Criteria
- Setting `ec2_ami_os = "windows"` without `ec2_ami_id` results in the SSM Windows AMI ID feeding `aws_instance.ami` for default release `2022`.
- Setting `ec2_ami_os = "windows"` with `ec2_ami_os_release = "2019"` or `"2025"` resolves the corresponding Windows Server Full-Base AMI.
- Existing Linux paths produce identical plans aside from the internal local usage for AMI resolution.
- Module validates successfully via Terraform CLI commands.

## Tests (Must be implemented in this phase)
- `terraform fmt -check` (module root).
- `terraform validate` (module root).
- Optional sanity `terraform plan` against an existing Linux example to confirm no regressions (document output if run).

## Verification Steps
- From repository root: `terraform fmt -check` and `terraform validate`.
- Capture Windows example plan output manually if needed for later documentation, but no automated example yet.
