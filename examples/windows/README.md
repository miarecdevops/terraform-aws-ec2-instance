# Windows Server example

This example shows how to deploy a Windows Server instance using the `terraform-aws-ec2-instance` module. It uses the
module’s `ec2_ami_os = "windows"` path so Terraform reads the latest Windows Server Full-Base AMI for the requested
release (`2019`, `2022`, or `2025`) from AWS Systems Manager (SSM) Parameter Store.

## Prerequisites

- Terraform `>= 1.3.0`
- AWS credentials with permission to read the public SSM parameters under
  `/aws/service/ami-windows-latest/Windows_Server-*-English-Full-Base`
- Optional: an AWS profile configured via `aws configure` (the example defaults to `default`)

## Quick start

```bash
cd examples/windows
terraform init -backend=false
terraform validate
terraform plan
```

Use the outputs to locate the Elastic IP and connect over RDP:

```powershell
mstsc /v $(terraform output -raw instance_public_ip)
```

> **Note:** Windows EC2 instances generate an administrator password that can be retrieved with the generated key
> (`windows_priv_key.pem`). See the AWS console’s “Get Windows password” action.

## Customising

- **Windows release:** set `-var ec2_ami_os_release=2019` (or `2025`) to test other versions.
- **RDP access:** update `rdp_source_cidr` to limit who can reach TCP/3389.
- **User data:** edit the `local.windows_user_data` heredoc in `main.tf` to add bootstrap steps (e.g., install Chocolatey).

To clean up:

```bash
terraform destroy
```
