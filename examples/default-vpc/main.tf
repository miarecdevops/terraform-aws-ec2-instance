terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.24"
    }
  }
}

provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}

module "instance" {
  source = "../../"

  environment = var.environment
  role = var.role

  vpc_id    = null
  ec2_subnet_id = null

  ec2_instance_type = var.instance_type
  ec2_ami_id        = data.aws_ami.ubuntu.id
  ec2_ssh_key_name  = aws_key_pair.generated_key.key_name
  ec2_volume_size   = 8
}