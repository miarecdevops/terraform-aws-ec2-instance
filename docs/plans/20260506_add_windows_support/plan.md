# Plan — Windows Server 2022 Support

## Summary
Expanding `terraform-aws-ec2-instance` to support Windows Server instances unblocks MiaRec’s QA and DevOps teams from relying on ad-hoc Terraform or manual AWS console builds. This effort introduces a Windows-aware AMI lookup so consumers can request Windows Server (2019/2022/2025) images through the existing abstraction without touching downstream modules.

The work is organized into three phases. Phase 1 updates the Terraform logic to source version-specific Windows AMIs through AWS’ public SSM parameters while keeping all Linux behavior unchanged. Phase 2 adds a Windows example plus documentation so adopters understand usage, release selection, prerequisites, and the origin of each AMI. Phase 3 extends automated validation via Terratest to ensure the Windows path remains healthy alongside existing Linux coverage.

## 0. References

### 0.1 Specification (Always Read)
- [spec.md](spec.md) — Detailed specification with acceptance criteria. **Read before any implementation.**

### 0.2 Phase Plans (Read Relevant Phase)
- [plan_phase_1.md](plan_phase_1.md) — Phase 1: Windows AMI Resolution
- [plan_phase_2.md](plan_phase_2.md) — Phase 2: Windows Example & Documentation
- [plan_phase_3.md](plan_phase_3.md) — Phase 3: Test Coverage & QA

### 0.3 Research (Read to Understand Codebase)
- [research.md](research.md) — (To be produced) Document codebase exploration, component mapping, existing patterns.

### 0.4 Source Document (Read if Requested)
- [idea.md](idea.md) — Original problem analysis and solution hypothesis. Source from which spec.md was produced.

## 1. Software Design Document (SDD)

### 1.1 Goals & Constraints
- Allow callers to set `ec2_ami_os = "windows"` and receive the Windows Server Full-Base AMI matching the requested `ec2_ami_os_release` (default `2022`) without altering metadata or disk encryption behavior.
- Maintain backward compatibility for Linux consumers and callers supplying explicit `ec2_ami_id` values.
- Avoid expanding scope beyond Windows Full-Base; no new Terraform variables unless strictly necessary.

### 1.2 Proposed Architecture (High-level)
- Introduce `data "aws_ssm_parameter" "windows_ami"` referencing a release-specific path such as `/aws/service/ami-windows-latest/Windows_Server-${var.ec2_ami_os_release}-English-Full-Base`; nothing new is stored in SSM—the data source simply reads AWS’ managed value.
- Define locals that map supported Windows releases (`2019`, `2022`, `2025`) to their SSM parameter names and derive `local.resolved_ami_id` combining `var.ec2_ami_id`, the Windows SSM value, or the existing Linux `aws_ami` data source using `coalesce` and a conditional on `var.ec2_ami_os`.
- Update `aws_instance` to use `local.resolved_ami_id` for the AMI argument while leaving all other attributes intact.
- Add `examples/windows` to illustrate module usage, and update README/variables descriptions to mention Windows support and SSM sourcing.
- Extend Terratest with a plan-only test that targets the Windows example.

### 1.3 Data Model & Types (Signatures, not full code)
- `local.windows_ssm_parameter_names : map(string)` — maps supported release strings (`2019`, `2022`, `2025`) to AWS SSM parameter names.
- `local.windows_ami_id : string` — value from `data.aws_ssm_parameter.windows_ami.value` using the mapped parameter name for the requested release.
- `local.linux_ami_id : string` — unchanged output of existing `data.aws_ami.ami`.
- `local.resolved_ami_id : string` — `coalesce(var.ec2_ami_id, var.ec2_ami_os == "windows" ? local.windows_ami_id : local.linux_ami_id)`.
- Module inputs/outputs remain unchanged; `ec2_ami_os` description enumerates `centos`, `ubuntu`, `rocky`, `windows`.

### 1.4 Module / File-level Design
- `main.tf`: add SSM data source, new locals for AMI resolution, wire to `aws_instance`.
- `variables.tf`: update `ec2_ami_os` documentation to include Windows.
- `README.md`: add Windows option, prerequisites (RDP SG, SSM read permission), and AMI sourcing description.
- `examples/windows/main.tf`: new example demonstrating Windows usage (fixture scope: documentation only).
- `tests/*`: new Go test `TestWindowsExamplePlan` (function scope) invoking plan on the Windows example.

### 1.5 Interfaces & Contracts
- `ec2_ami_os` accepted values: `{centos, ubuntu, rocky, windows}` with default `ubuntu`; when `windows`, the existing `ec2_ami_os_release` variable accepts enumerated Windows releases (`2019`, `2022`, `2025`).
- Custom AMI override via `ec2_ami_id` continues to bypass lookup logic.
- Windows example exports only what is required for demonstration; no production code depends on it.
- Terratest respects existing helper contracts for Terraform init/plan execution using temporary directories and shared AWS region helpers.

### 1.6 Key Algorithms (Pseudo-code)
```
locals {
  windows_ssm_parameter_names = {
    "2019" = "/aws/service/ami-windows-latest/Windows_Server-2019-English-Full-Base"
    "2022" = "/aws/service/ami-windows-latest/Windows_Server-2022-English-Full-Base"
    "2025" = "/aws/service/ami-windows-latest/Windows_Server-2025-English-Full-Base"
  }
}

data "aws_ssm_parameter" "windows_ami" {
  name = lookup(local.windows_ssm_parameter_names, var.ec2_ami_os_release, local.windows_ssm_parameter_names["2022"])
}

locals {
  linux_ami_id   = data.aws_ami.ami.id
  windows_ami_id = data.aws_ssm_parameter.windows_ami.value
  resolved_ami_id = coalesce(
    var.ec2_ami_id,
    var.ec2_ami_os == "windows" ? local.windows_ami_id : local.linux_ami_id
  )
}

resource "aws_instance" "instance" {
  ami = local.resolved_ami_id
  # existing configuration remains unchanged
}
```

### 1.7 Testing Architecture
- Core Terraform checks: `terraform fmt -check`, `terraform validate` executed in module root and example directory.
- Terratest: new plan-only Windows test plus existing Linux-focused tests to prevent regressions; run with `go test -v -timeout 60m ./tests -run TestWindowsExamplePlan` and optionally full suite. Consider parameterizing the test to cover at least one non-default Windows release.
- Manual verification: developers may run `terraform plan` against examples to inspect AMI IDs.

### 1.8 Edge Cases
- SSM parameter access failure (missing IAM permissions or regional unavailability) should surface as plan errors; document troubleshooting notes.
- Invalid `ec2_ami_os` values continue to raise Terraform lookup errors (no silent fallback to Linux).
- Unsupported `ec2_ami_os_release` values when `ec2_ami_os = "windows"` should emit clear errors before attempting SSM lookup.
- Callers providing `ec2_ami_id` expect no interaction with the new data source; ensure logic honors override.

### 1.9 Observability & Ops (if relevant)
- No additional observability hooks required; documentation should mention how to confirm the AMI ID in plan output.

## 2. Phase Breakdown (Approval checkpoint)

### Phase 1. Windows AMI Resolution (pending)
- **Goal:** Wire SSM-based AMI lookup into the module while keeping other behavior unchanged.
- **Acceptance Criteria:** `ec2_ami_os = "windows"` resolves via SSM for default (`2022`) and enumerated releases (`2019`, `2025`); Linux and custom AMI flows remain unaffected; Terraform validation passes.
- **Tests:** `terraform fmt -check` and `terraform validate` at module root; optional sanity plan for Linux example.
- **Phase Plan:** [plan_phase_1.md](plan_phase_1.md)

### Phase 2. Windows Example & Documentation (pending)
- **Goal:** Provide Windows example usage and update documentation to explain the new option, release selection, and prerequisites.
- **Acceptance Criteria:** `examples/windows` validates successfully; README/variables mention Windows option, supported releases, and SSM sourcing.
- **Tests:** `terraform fmt -check` and `terraform validate` executed within `examples/windows`.
- **Phase Plan:** [plan_phase_2.md](plan_phase_2.md)

- **Goal:** Add automated plan-only Terratest coverage for the Windows example and rerun repository checks.
- **Acceptance Criteria:** New Go test passes locally (covering the default Windows release and at least one alternate release if practical); existing tests remain green; repo lint/validate commands succeed.
- **Tests:** `go test -v -timeout 60m ./tests -run TestWindowsExamplePlan` (and optional full suite) plus global Terraform checks.
- **Phase Plan:** [plan_phase_3.md](plan_phase_3.md)

## 3. Living Sections (Mandatory)

> **Instructions for maintainers:**
>
> This plan is a living document. As you make key design decisions, update the plan to record both the decision and the thinking behind it. Record all decisions in the `Decision Log` section.
>
> Maintain the `Progress` section in this plan and in the corresponding phase document. Mark tasks as `[ ]` not started, `[~]` in progress, or `[x]` done.
>
> When you discover optimizer behavior, performance tradeoffs, unexpected bugs, or inverse/unapply semantics that shaped your approach, capture those observations in the `Surprises & Discoveries` section with short evidence snippets (test output is ideal).
>
> If you change course mid-implementation, document why in the `Decision Log` and reflect the implications in `Progress`. Plans are guides for the next contributor as much as checklists for you.
>
> At completion of a major task or the full plan, write an `Outcomes & Retrospective` entry summarizing what was achieved, what remains, and lessons learned.
>
> **This document must describe not just the what but the why for almost everything.**

### 3.1 Progress
- [x] Phase 1: Windows AMI Resolution — completed 2026-05-07T08:25:39-06:00
- [x] Phase 2: Windows Example & Documentation — completed 2026-05-07T08:34:56-06:00
- [x] Phase 3: Test Coverage & QA — completed 2026-05-07T08:38:52-06:00

### 3.2 Decision Log
- **Decision:** Treat the default `ec2_ami_os_release` value (`20.04`) as a sentinel that maps Windows callers to the 2022 SSM parameter while continuing to error on unsupported release strings.
  - Date: 2026-05-07
  - Rationale: Preserves backwards compatibility for existing module callers that only toggle `ec2_ami_os` while enabling future Windows release selection and clear validation failures for other values.

### 3.3 Surprises & Discoveries
- **Observation:** Baseline `terraform fmt -check` fails on existing Terraform files prior to any changes; will avoid wholesale reformatting and target touched sections only.
  - Evidence: `terraform fmt -check` → reported `main.tf`, `outputs.tf`, `variables.tf` on 2026-05-07T08:21:11-06:00.
- **Observation:** Running `terraform validate` in examples requires a preceding `terraform init -backend=false`; removing `.terraform/` between runs necessitates reinitialisation.
  - Evidence: `terraform validate` in `examples/windows` failed until `terraform init -backend=false` executed (2026-05-07T08:31:02-06:00).
- **Observation:** Terratest must skip when AWS credentials are unavailable; Windows plan test now detects missing creds via `aws.GetAccountIdE` and calls `t.Skip`.
  - Evidence: `TestWindowsExamplePlan` adds credential check before running `terraform init/plan`.

### 3.4 Outcomes & Retrospective
(To be filled after completion)

## Edge Cases
- AWS SSM public parameter might be unavailable or restricted in certain regions; ensure plans surface clear errors and document remediation.
- Credentialed environments lacking SSM permission will fail during plan; document IAM requirement in README and troubleshooting.
- Invalid `ec2_ami_os` inputs should continue to trigger Terraform errors, preventing silent fallbacks.
- Unsupported `ec2_ami_os_release` values for Windows should raise immediate errors with guidance on supported options.
- Callers providing `ec2_ami_id` (Linux or Windows) must bypass lookup logic entirely to avoid unexpected AMI swaps.
