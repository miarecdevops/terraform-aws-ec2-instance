terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.44"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}

locals {
  windows_user_data = <<-EOT
    <powershell>
    # Bootstrap Windows-specific configuration here.
    # Example: Install Chocolatey or download installer assets before RDP login.
    </powershell>
  EOT
}

module "windows_instance" {
  source = "../../"

  environment = var.environment
  role        = var.role

  vpc_id        = null
  ec2_subnet_id = null

  ec2_assign_eip    = true
  ec2_instance_type = var.instance_type
  ec2_volume_size   = var.volume_size
  ec2_ssh_key_name  = aws_key_pair.windows_generated_key.key_name

  ec2_ami_os         = "windows"
  ec2_ami_os_release = var.ec2_ami_os_release

  sg_rules = {
    RDP = {
      type      = "ingress"
      from_port = 3389
      to_port   = 3389
      protocol  = "tcp"
      cidr      = var.rdp_source_cidr
    }
    egress = {
      type      = "egress"
      from_port = 0
      to_port   = 0
      protocol  = "-1"
      cidr      = "0.0.0.0/0"
    }
  }

  user_data = local.windows_user_data

  tags = merge(
    var.tags,
    {
      Role     = var.role
      OS       = "windows"
      Release  = var.ec2_ami_os_release
      Function = "windows-example"
    },
  )
}
