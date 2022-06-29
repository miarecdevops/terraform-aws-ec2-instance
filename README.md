# terraform module `instance`

terraform module to create a EC2 instance

## Module Variables

See [`variables.tf`](./variables.tf) for full list of variables

### Required Variables

- `index` unique identifier for multiple module calls
- `vpc_id` VPC ID where all resources will be attached
- `subnet_ids` List of Subnet ID to attach to EC2, two supported AZ currently
- `ec2_ssh_key_name` SSH Key Pair Name. Such key must exist in EC2 console
- `user_data` (Optional) optional script to be ran on instance upon creation
- `sg_rules` map of rules that will be applied to instance security group
- `iam_policy` map of IAM roles that will be applied to instance
- `ec2_image_id` AMI ID. Caution! It is unique for each region
- `ec2_instance_type` ec2 instance type
- `ec2_volume_size` Disk size in GB
- `route53_a_record`(Optional) Host portion of FQDN public and private
- `route53_ttl` (Optional) ttl of the DNS record, in seconds, public and private
- `route53_zone_id_public` (Optional) Route53 Zone id to build A record in for private resolution
- `route53_domain_public` (Optional) Domain portion of FQDN for private resolution
- `route53_zone_id_private` (Optional) Route53 Zone id to build A record in for private resolution
- `route53_domain_private` (Optional) Domain portion of FQDN for private resolution
- `environment` Name of environment (all tags will start with this name)
- `role` Role for this module, will be used in naming resources
- `tags` Tags to set on all resources

## Sample Module Calls

Private Only Instance, , with access to S3 bucket

```hcl
module "private_instance" {
  source = "./modules/instance"
  count = 4

  index             = count.index
  vpc_id            = module.network.vpc_id
  subnet_ids        = module.network.private_subnet_ids
  availabilty_zones = ["us-west-2a", "us-west-2b"]
  ec2_ssh_key_name  = "environment-key-1234"

  route53_zone_id_private = aws_route53_zone.private.id
  route53_domain_private  = aws_route53_zone.private.name

  sg_rules = {
      SSH = {
          type = "ingress"
          from_port = 22
          to_port = 22
          protocol = "tcp"
          cidr = "10.0.0.0/16"
      }
      egress = {
          type      = "egress"
          from_port = 0
          to_port   = 0
          protocol  = "-1"
          cidr      = "0.0.0.0/0"
      }
  }

  iam_policy =   {
    s3_access = {
      action   = "s3:*"
      effect   = "Allow"
      resource = "*"
    }
  ec2_image_id      = "ami-0892d3c7ee96c0bf7"
  ec2_instance_type = "t3a.micro"
  ec2_volume_size   = 20
  route53_a_record  = "priv-instance"
  route53_ttl       = 300

  environment = "environment"
  role        = "private-ec2"

  tags = {
    Role      = "private-ec2"
  }
}
```

Public Accessable Instance

```hcl
module "public_instance" {
  source = "./modules/instance"
  count = 4

  index             = count.index
  vpc_id            = module.network.vpc_id
  subnet_ids        = module.network.private_subnet_ids
  availabilty_zones = ["us-west-2a", "us-west-2b"]
  ec2_ssh_key_name  = "environment-key-1234"

  route53_zone_id_public  = aws_route53_zone.public.id
  route53_domain_public   = aws_route53_zone.public.name

  sg_rules = {
      SSH_public = {
          type = "ingress"
          from_port = 22
          to_port = 22
          protocol = "tcp"
          cidr = "0.0.0.0/0"
      }
      egress = {
          type      = "egress"
          from_port = 0
          to_port   = 0
          protocol  = "-1"
          cidr      = "0.0.0.0/0"
      }
  }

  iam_policy = {}
  ec2_image_id      = "ami-0892d3c7ee96c0bf7"
  ec2_instance_type = "t3a.micro"
  ec2_volume_size   = 20
  route53_a_record  = "pub-instance"
  route53_ttl       = 300

  environment = var.environment
  role        = "public-ec2"

  tags = {
    Role      = "public-ec2"
  }
}
```

## Outputs

all ouputs are accessible module.module_name.output_name

- `instance_id`  ID instance
- `private_ip_address` Private IPV4 address of instnace
- `public_ip_address` Public IPV4 address of instnace
- `fqdn` Publicly resolvable FQDN
- `private_fqdn` privately resolvable FQDN
- `iam_role` iam role arn
