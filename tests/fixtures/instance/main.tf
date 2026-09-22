# Root module used by Terratest. It calls the module under test with the AWS
# provider pointed at floci. Every optional feature of the module is exposed
# as a variable so one fixture serves all tests.

terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

variable "floci_endpoint" {
  type        = string
  description = "URL of the floci edge endpoint."
}

variable "stack" {
  type        = string
  description = "Stack name. Prefixes the name of every resource."
}

variable "role" {
  type        = string
  description = "Role of the instance. Used in resource names."
  default     = "test"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type."
  default     = "t3.micro"
}

variable "ami_os" {
  type        = string
  description = "OS family for the AMI lookup."
  default     = "ubuntu"
}

variable "ami_os_release" {
  type        = string
  description = "OS release for the AMI lookup."
  default     = "24.04"
}

variable "ami_id" {
  type        = string
  description = "Explicit AMI ID. Skips the lookup when set."
  default     = null
}

variable "assign_eip" {
  type        = bool
  description = "Attach an Elastic IP to the instance."
  default     = false
}

variable "secondary_private_ip_host" {
  type        = number
  description = "Host number inside the subnet CIDR to use as the secondary private IP. Null assigns no secondary IP."
  default     = null
}

variable "assign_secondary_eip" {
  type        = bool
  description = "Attach an Elastic IP to the secondary private IP."
  default     = false
}

variable "iam_policy_actions" {
  type        = map(string)
  description = "Inline IAM policies to attach to the instance role, as policy name to a single allowed action on all resources. Building the JSON here keeps quotes out of the -var value."
  default     = {}
}

variable "use_existing_security_group" {
  type        = bool
  description = "Create a security group in the fixture and pass it to the module instead of letting the module create one."
  default     = false
}

variable "sg_rules" {
  type        = map(map(string))
  description = "Security group rules for the module. Null keeps the module default."
  default     = null
}

variable "route53_zone" {
  type        = string
  description = "Name of a private hosted zone to create. Null skips Route53."
  default     = null
}

variable "route53_a_record" {
  type        = string
  description = "Host part of the A record to create in the zone."
  default     = null
}

provider "aws" {
  region     = "us-east-1"
  access_key = "test"
  secret_key = "test"

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    ec2     = var.floci_endpoint
    iam     = var.floci_endpoint
    route53 = var.floci_endpoint
    sts     = var.floci_endpoint
  }
}

# --------------------------------------------
# SSH key pair
# --------------------------------------------
resource "tls_private_key" "key" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "key" {
  key_name   = "${var.stack}-${var.role}-key"
  public_key = tls_private_key.key.public_key_openssh
}

# --------------------------------------------
# Default VPC
# --------------------------------------------
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_subnet" "selected" {
  id = sort(data.aws_subnets.default.ids)[0]
}

locals {
  secondary_private_ip = (
    var.secondary_private_ip_host == null ?
    null :
    cidrhost(data.aws_subnet.selected.cidr_block, var.secondary_private_ip_host)
  )
}

# --------------------------------------------
# Optional security group owned by the fixture
# --------------------------------------------
resource "aws_security_group" "existing" {
  count = var.use_existing_security_group ? 1 : 0

  name   = "${var.stack}-${var.role}-existing"
  vpc_id = data.aws_vpc.default.id
}

# --------------------------------------------
# Optional private hosted zone
# --------------------------------------------
resource "aws_route53_zone" "private" {
  count = var.route53_zone != null ? 1 : 0

  name          = var.route53_zone
  force_destroy = true

  vpc {
    vpc_id = data.aws_vpc.default.id
  }
}

module "instance" {
  source = "../../.."

  depends_on = [aws_route53_zone.private]

  stack = var.stack
  role  = var.role

  vpc_id        = data.aws_vpc.default.id
  ec2_subnet_id = data.aws_subnet.selected.id

  ec2_ami_os         = var.ami_os
  ec2_ami_os_release = var.ami_os_release
  ec2_ami_id         = var.ami_id

  ec2_instance_type = var.instance_type
  ec2_ssh_key_name  = aws_key_pair.key.key_name
  ec2_volume_size   = 8

  ec2_assign_eip           = var.assign_eip
  ec2_secondary_private_ip = local.secondary_private_ip
  ec2_assign_secondary_eip = var.assign_secondary_eip

  iam_policies = {
    for name, action in var.iam_policy_actions : name => jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Action   = action
        Effect   = "Allow"
        Resource = "*"
      }]
    })
  }

  vpc_security_group_ids = aws_security_group.existing[*].id
  sg_rules               = var.sg_rules

  route53_a_record     = var.route53_a_record
  route53_zone         = var.route53_zone
  route53_zone_private = true

  tags = {
    Stack = var.stack
  }
}

output "instance_id" {
  value = module.instance.instance_id
}

output "instance_tags" {
  value = module.instance.instance_tags
}

output "private_ip" {
  value = module.instance.private_ip
}

output "public_ip" {
  value = module.instance.public_ip
}

output "secondary_private_ip" {
  value = module.instance.secondary_private_ip
}

output "secondary_public_ip" {
  value = module.instance.secondary_public_ip
}

output "fqdn" {
  value = module.instance.fqdn
}

output "iam_role" {
  value = module.instance.iam_role
}

output "az" {
  value = module.instance.az
}

output "security_group_ids" {
  value = module.instance.security_group_ids
}

output "existing_security_group_id" {
  value = one(aws_security_group.existing[*].id)
}

output "subnet_id" {
  value = data.aws_subnet.selected.id
}

output "expected_secondary_private_ip" {
  value = local.secondary_private_ip
}

output "route53_zone_id" {
  value = one(aws_route53_zone.private[*].zone_id)
}
