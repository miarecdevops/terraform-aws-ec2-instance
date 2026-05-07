# Phase 2 — Windows Example & Documentation

## Goal
Provide a Windows-focused example configuration and documentation updates that explain how to opt into Windows AMI provisioning, select supported releases, and reference the AWS SSM parameter source.

## Scope
- New example directory `examples/windows` (fixture scope: documentation/demo only).
- README.md updates describing the Windows option, expected security group adjustments (e.g., RDP), supported release values, and SSM parameter behavior.
- `variables.tf` and any ancillary docs that enumerate supported OS values.

## Tasks
- [x] Create `examples/windows/main.tf` that consumes the module with `ec2_ami_os = "windows"`, includes minimal required variables, demonstrates an RDP ingress rule, and stub user data comments for Windows setup.
- [x] Include supporting files (variables/outputs) only if necessary for a self-contained example; keep scope limited to showing module usage.
- [x] Update README.md to list `windows` as an allowed `ec2_ami_os` value, enumerate supported `ec2_ami_os_release` options for Windows (2019/2022/2025), and describe that the AMI ID is sourced via AWS’ public SSM parameter.
- [x] Ensure variable documentation references Windows option and release usage consistently (cross-check with Phase 1 changes).
- [x] Run Terraform formatting and validation commands within `examples/windows` to confirm the example is runnable.

## Edge Cases to Address
- Example should document IAM permissions required to read AWS SSM public parameters if using restricted credentials.
- Clarify that callers must configure security groups for RDP and handle Windows password retrieval (link to AWS docs if helpful).
- Avoid enabling extra resources (e.g., EIPs) unless necessary; keep example minimal.

## Acceptance Criteria
- `examples/windows` executes `terraform init -backend=false` and `terraform validate` without errors.
- Documentation clearly communicates how to provision Windows instances, choose releases, and what prerequisites (ports, permissions) exist.
- `variables.tf` and README.md remain consistent on supported OS values and release enumerations.

## Tests (Must be implemented in this phase)
- From `examples/windows`: `terraform fmt -check` and `terraform validate`.
- Optional: `terraform plan` (manual) to confirm AMI resolution; document if run.

## Verification Steps
- `cd examples/windows` then run `terraform fmt -check` and `terraform validate`.
- `cd -` to return to repo root and ensure no formatting drift in other files.
