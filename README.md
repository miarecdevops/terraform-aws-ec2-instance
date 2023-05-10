# terraform module `ec2-instance`
Terraform module that creates the following in AWS
 - EC2 Instance
 - Route53 A record
 - Security Group/Security Group Rule
 - IAM policy

## Module Variables

See [`variables.tf`](./variables.tf) for full list of variables

### Variables

> Required Variables
- `ec2_ssh_key_name` SSH Key Pair Name. Such key must exist in EC2 console
- `sg_rules` map of rules that will be applied to instance security group
- `iam_policy` map of IAM roles that will be applied to instance

- `ec2_instance_type` ec2 instance type
- `ec2_volume_size` Disk size in GB
- `environment` Name of environment (all tags will start with this name)
- `role` Role for this module, will be used in naming resources
- `tags` Tags to set on all resources

> Optional Variables

- `ec2_metadata` (Optional) If set to TRUE, instance metadata will be available via IMDSv1, default = true
- `user_data` (Optional) optional script to be ran on instance upon creation
- `vpc_id` (Optional) vpc_id where instance will be deployed, if null, instance will be deployed in default VP
- `ec2_subnet_id` (Optional) a Subnet ID where Instance will be deployed, this has to be contained in the same VPC defined in vpc_id. If not provided, the first subnet will be selected in the VPC
- `ec2_assign_eip` (Optional) When true, a Static Pubilic (ElP) will be assigned to the Ec2 instance

- `route53_a_record`(Optional) Host portion of FQDN. If specified, the route_53_zone or  route53_zone_id parameters are required as well"
- `route53_zone` (Optional) Route53 Zone name to build A record in
- `route53_ttl` (Optional) ttl of the DNS record, in seconds, public and private
>  Multiple instance Variables
- `index` (Optional) Index of instance being created when multiple instances are deployed
- `subnet_list` (Optional) List of Subnet IDs with key Availability Zones, this is used when Multiple instances are deployen in multiple AZs
- `availabilty_zones`(Optional) list of availability zones used to choose subnet when multiple instances are deployed

> AMI Lookup

This module has the ability to lookup the latest AMI based a few criteria, this is useful for quick deployment

- `ec2_ami_os` OS that will be used for EC2, currently CentOS7 and Ubuntu are supported, default = `centos`
    - `centos` = CentOS 7
    - `ubuntu` = Ubuntu
- `ec2_ami_os_release` (Optional) Release of Ubuntu,   default = `20.04`
- `ec2_ami_virtualization` (Optional) AMI Virtualization type, default = `hvm`
- `ec2_ami_archtecture` (Optional) AMI archetecture type, default = `x86_64`
- `ec2_ami_image-type` (Optional) AMI image type, default = `machine`

> Specific AMI use

As an alternative an AMI ID can be passed to the module in the event that a specific Image is needed
- `ec2_ami_id` AMI ID. supply an AMI ID to use a specific Image. Caution! It is unique for each region

## Sample Module Calls

> Single Private Only Instance, existing VPC, No DNS Config, access to S3 bucket, lookup latest Ubuntu 22.04 AMI

```hcl
module "private" {
    source = "github.com/miarecdevops/terraform-aws-ec2-instance.git"

    # Networking Variables
    vpc_id                = module.network.vpc_id
    ec2_subnet_id         = module.network.private_subnet_ids[var.availability_zones[0]]

    # required variables for module
    ec2_ssh_key_name      = var.ec2_ssh_key_name == null ? module.ssh[0].ec2_ssh_key_name : var.ec2_ssh_key_name
    sg_rules              = var.private_sg_rules
    iam_policies          =   {
                                s3_access = {
                                  action   = "s3:*"
                                  effect   = "Allow"
                                  resource = "*"
                              }

    ec2_ami_os            = "ubuntu"
    ec2_ami_os_release    = "22.04"
    ec2_instance_type     = var.private_ec2_instance_type
    ec2_volume_size       = var.private_ec2_volume_size

    # tagging / naming variables
    environment  = var.environment
    role         = "private_instance"

    tags = {
        Role        = "private_instance"
    }
}
```

> Multiple Public instances, existing VPC, with DNS, using a specific AMI

```hcl
module "public" {
    source = "github.com/miarecdevops/terraform-aws-ec2-instance.git"
    count = 4

    # Networking Variables
    vpc_id                = module.network.vpc_id
    index = count.index
    subnet_list = module.network.public_subnet_ids
    availability_zones = var.availability_zones
    ec2_assign_eip  = true

    # required variables for module
    ec2_ssh_key_name      = var.ec2_ssh_key_name == null ? module.ssh[0].ec2_ssh_key_name : var.ec2_ssh_key_name
    sg_rules              = var.public_sg_rules
    iam_policies          = var.public_iam_policies

    ec2_ami_id            = "ami-070237a0a64c58642"
    ec2_instance_type     = var.public_ec2_instance_type
    ec2_volume_size       = var.public_ec2_volume_size

    # DNS variables
    route53_zone          = aws_route53_zone.subdomain.name
    route53_a_record      = "${var.public_route53_a_record}${count.index}"
    route53_ttl           = var.public_route53_ttl
    route53_zone_private  = false

    # tagging / naming variables
    environment  = var.environment
    role         = "public_instance"

    tags = {
        Role        = "public_instance"
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
- `az` Availablity zone instance is deployed in