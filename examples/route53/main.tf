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

  depends_on = [
    # Add explicit dependency on the private zone, forcing 
    # Terraform to wait till zone is successfully created 
    # before the module is run.
    # Otherwise, it may run the module before the Route53 zone is ready.
    aws_route53_zone.private
  ]

  environment = var.environment
  role = var.role

  vpc_id    = data.aws_vpc.default.id
  ec2_subnet_id = sort(data.aws_subnet_ids.default.ids)[0]

  ec2_instance_type = var.instance_type
  ec2_ami_id        = data.aws_ami.ubuntu.id
  ec2_ssh_key_name  = aws_key_pair.generated_key.key_name
  ec2_volume_size   = 8

  route53_a_record = "this-server"
  route53_zone = local.route53_zone
  route53_zone_private = true
}