terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
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

  vpc_id    = aws_vpc.vpc.id
  ec2_subnet_id = aws_subnet.public_subnets[var.availability_zones[0]].id

  ec2_instance_type = var.instance_type
  ec2_ami_id        = data.aws_ami.ubuntu.id
  ec2_ssh_key_name  = aws_key_pair.generated_key.key_name
  ec2_volume_size   = 8
}