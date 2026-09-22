# terraform-aws-ec2-instance

Terraform module that creates an EC2 instance and the resources around it:

- The instance, from an AMI looked up by OS release or from an explicit AMI ID.
- A security group with configurable rules, unless you pass your own security groups.
- Optionally, an IAM role and instance profile with inline policies.
- Optionally, an Elastic IP for the instance and another one for a secondary private IP.
- Optionally, a Route53 A record in a public or private hosted zone.

## Requirements

| Name | Version |
| --- | --- |
| Terraform | >= 1.9 |
| AWS provider | >= 5.0 |

The module doesn't declare a provider. Configure the AWS provider in the calling project.

## Usage

Private instance in an existing VPC, latest Ubuntu 22.04 AMI, with access to S3:

```hcl
module "private" {
  source = "github.com/miarecdevops/terraform-aws-ec2-instance.git"

  stack = "myapp.prod.example.com"
  role  = "worker"

  vpc_id        = module.network.vpc_id
  ec2_subnet_id = module.network.private_subnet_ids[0]

  ec2_ami_os         = "ubuntu"
  ec2_ami_os_release = "22.04"
  ec2_instance_type  = "t3.small"
  ec2_volume_size    = 20
  ec2_ssh_key_name   = "prod-key"

  iam_policies = {
    s3_access = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Action   = "s3:*"
        Effect   = "Allow"
        Resource = "*"
      }]
    })
  }

  tags = {
    Project = "example"
  }
}
```

Public instances with Elastic IPs and DNS records, from a specific AMI:

```hcl
module "public" {
  source = "github.com/miarecdevops/terraform-aws-ec2-instance.git"
  count  = 2

  stack = "myapp.prod.example.com"
  role  = "web${count.index}"

  vpc_id         = module.network.vpc_id
  ec2_subnet_id  = module.network.public_subnet_ids[0]
  ec2_assign_eip = true

  ec2_ami_id        = "ami-070237a0a64c58642"
  ec2_instance_type = "t3.small"
  ec2_volume_size   = 20
  ec2_ssh_key_name  = "prod-key"

  route53_zone     = "example.com"
  route53_a_record = "web${count.index}"
}
```

The `examples` directory holds complete root modules for a default VPC, a custom VPC, IAM policies, and Route53.

## Inputs

See [`variables.tf`](./variables.tf) for the full list with types and defaults.

### Required

| Name | Description |
| --- | --- |
| `stack` | Name of the stack the instance belongs to, for example `myapp.prod.example.com`. Prefixes the name of every resource. |
| `role` | Role of the instance. Used in resource names and the `Role` tag. |
| `ec2_instance_type` | EC2 instance type. |
| `ec2_volume_size` | Root volume size in GB. |
| `ec2_ssh_key_name` | Name of an existing EC2 key pair in the region. |

### AMI

| Name | Description | Default |
| --- | --- | --- |
| `ec2_ami_id` | Explicit AMI ID. Skips the lookup. AMI IDs are unique per region. | `null` |
| `ec2_ami_os` | OS family for the lookup: `ubuntu`, `rocky`, or `centos`. | `ubuntu` |
| `ec2_ami_os_release` | OS release for the lookup, for example `20.04`, `22.04`, or `24.04` for Ubuntu. | `20.04` |
| `ec2_ami_virtualization` | Virtualization type filter. | `hvm` |
| `ec2_ami_archtecture` | Architecture filter. | `x86_64` |
| `ec2_ami_image-type` | Image type filter. | `machine` |

The lookup picks the most recent image from the official owner account that matches the filters. The instance ignores later AMI changes, so it isn't replaced when a newer image is published.

### Network

| Name | Description | Default |
| --- | --- | --- |
| `vpc_id` | VPC for the security group. `null` uses the default VPC. | `null` |
| `ec2_subnet_id` | Subnet for the instance. Must be in `vpc_id`. | `null` |
| `ec2_assign_eip` | Attach an Elastic IP to the instance. | `false` |
| `ec2_secondary_private_ip` | Secondary private IP to assign to the instance. | `null` |
| `ec2_assign_secondary_eip` | Attach an Elastic IP to the secondary private IP. | `false` |
| `vpc_security_group_ids` | Security groups to attach. When set, the module creates no security group and ignores `sg_rules`. | `[]` |
| `sg_rules` | Rules for the security group the module creates. A map of rule name to `type`, `from_port`, `to_port`, `protocol`, and `cidr`. | SSH from anywhere, all egress |

### IAM, metadata, and user data

| Name | Description | Default |
| --- | --- | --- |
| `iam_policies` | Inline policies for the instance role, as policy name to JSON document. When empty, no role or instance profile is created. | `{}` |
| `ec2_metadata` | Enable the instance metadata endpoint and instance tags in metadata. The endpoint requires IMDSv2; software that reads metadata must use session tokens. | `true` |
| `user_data` | Script to run on first boot. | `null` |
| `tags` | Tags for every resource. The module adds `Name` and `Role` on the instance. | `{}` |

### Deprecated

| Name | Description | Default |
| --- | --- | --- |
| `environment` | Use `stack` instead. Kept so existing callers keep working. Used as the resource name prefix only when `stack` is `null`. | `null` |

### Route53

| Name | Description | Default |
| --- | --- | --- |
| `route53_a_record` | Host part of the record. Use `@` for the zone apex. `null` creates no record. | `null` |
| `route53_zone` | Name of the hosted zone. Required when `route53_a_record` is set. | `null` |
| `route53_zone_private` | Whether the zone is private. A private zone gets the private IP, a public zone gets the public IP. | `false` |
| `route53_ttl` | TTL of the record in seconds. | `300` |

## Outputs

| Name | Description |
| --- | --- |
| `instance_id` | ID of the instance. |
| `instance_tags` | Tags on the instance. |
| `private_ip` | Private IPv4 address. |
| `public_ip` | Public IPv4 address. The Elastic IP when `ec2_assign_eip` is set. |
| `secondary_private_ip` | Secondary private IPv4 address, or `null`. |
| `secondary_public_ip` | Elastic IP of the secondary private address, or `null`. |
| `fqdn` | Fully qualified name of the Route53 record, or `null`. |
| `iam_role` | ARN of the instance role, or `null`. |
| `security_group_ids` | Security groups attached to the instance. |
| `az` | Availability zone of the instance. |

## Development

Terraform and the AWS CLI are expected to be installed on the machine. Other tools are managed by [mise](https://mise.jdx.dev/).

```bash
mise install
```

| Task | Description |
| --- | --- |
| `mise run fmt` | Format all Terraform and Go files. |
| `mise run lint` | Check formatting, run tflint and checkov on Terraform, and golangci-lint on Go. Checkov skips are listed with reasons in `.checkov.yml`. |
| `mise run validate` | Run `terraform validate` in every root module. |
| `mise run test` | Start floci in Docker and run the Terratest suite. |
| `mise run test:aws` | Deploy every example to a random US region of a real AWS account and check SSH access. Costs money. |
| `mise run floci:start` | Start the floci container for this checkout. |
| `mise run floci-url` | Print the URL of the floci container for this checkout. |
| `mise run floci:stop` | Stop and remove the floci container for this checkout. |

Tests live in the `tests` directory and run against [floci](https://github.com/floci-io/floci), a free and open-source AWS emulator. They apply the module through `tests/fixtures/instance` and read the resources back through the EC2, IAM, and Route53 APIs. See [`tests/README.md`](./tests/README.md) for what each test covers and for the known differences between floci and AWS.

The floci image is pinned to a release tag in `mise.toml`.

Each checkout gets its own floci container, named after the repository plus a hash of the checkout path, on a host port chosen by Docker. Several worktrees can run tests at the same time without interfering. Run `mise run floci-url` to find the URL, for example to list instances with the AWS CLI:

```bash
aws --endpoint-url "$(mise run -q floci-url)" ec2 describe-instances
```

GitHub Actions runs lint, validate, and the floci tests on every push and pull request.
