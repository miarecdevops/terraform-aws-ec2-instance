# Global settings
variable "environment" {
  description = "Name of environment (all tags will start with this name)"
  type        = string
}

variable "role" {
  description = "Role for this module, will be used in naming resources"
  type        = string
}

variable "tags" {
  description = "Tags to set on all resources"
  type        = map(string)
  default     = {}
}

# AMI settings
variable "ec2_ami_id" {
  description = "(Optional) AMI ID. supply an AMI ID to use a specific Image.   Caution! It is unique for each region"
  type        = string
  default     = null
}

variable "ec2_ami_os" {
  description = "OS that will be used for EC2, `centos` = CentOS 7, `ubuntu` = Ubuntu 20.04"
  type        = string
  default     = "centos"
}

variable "ec2_ami_virtualization" {
  description = "(Optional) AMI Virtualization type, default = `hvm`"
  type        = string
  default     = "hvm"
}

variable "ec2_ami_archtecture" {
  description = "(Optional) AMI archetecture type, default = `x86_64`"
  type        = string
  default     = "x86_64"
}

variable "ec2_ami_image-type" {
  description = "(Optional) AMI image type, default = `machine`"
  type        = string
  default     = "machine"
}

# VPC / Network settings
variable "vpc_id" {
  description = "Optional, vpc_id where instance will be deployed, if null, instance will be deployed in default VPC"
  type        = string
  default     = null
}

variable "ec2_subnet_id" {
  description = "Optional, a Subnet ID where Instance will be deployed, this has to be contained in the same VPC defined in vpc_id. If not provided, the first subnet will be selected in the VPC"
  type        = string
  default     = null
}

variable "ec2_assign_eip" {
  description = "if true, Static Public IP address will be assigned to ec2 instance"
  type        = bool
  default     = false
}

# Multi Instance Vars
variable "subnet_list" {
  description = "Optional, List of Subnet ID with key Availability Zones, this is used when Multiple instances are deployen in multiple AZs"
  default     = null
}

variable "availability_zones" {
  description = "Optional, list of availability zones used to choose subnet when multiple instances are deployed"
  type        = list
  default     = null
}

variable "index" {
  description = "Optional, Index of instance being created when multiple instances are deployed "
  type        = number
  default     = null
}

# Security Group settings
variable "sg_rules" {
  description = "Securtity group rules applied to instance instance"
  type        = map(map(string))
  default     = {
    SSH = {
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
}

# IAM settings
variable "iam_policies" {
  description =  "Optional, IAM policies that will be attahed to IAM Role"
  type = map(object)
  default = { }
}

# EC2 instance settings
variable "ec2_ssh_key_name" {
  description = "SSH Key Pair Name. Such key must exist in EC2 console in the region"
  type        = string
}

variable "ec2_instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "ec2_volume_size" {
  description = "Disk size in GB"
  type        = number
}

variable "ec2_metadata" {
  type        = bool
  description = "Set to TRUE, instance metadata will be available via IMDSv1"
  default     = true
}

variable "user_data" {
  description = "Optional, user_data.sh script to be loaded on ec2 creation"
  type        = any
  default     = null
}

# Route53 settings
variable "route53_a_record" {
  description = "Optional, host portion of FQDN. If specified, the route_53_zone parameters are required as well"
  type        = string
  default     = null
}

variable "route53_zone" {
  type        = string
  description = "Optional, Route53 Zone Name to build A record in"
  default     = null
}

variable "route53_zone_private" {
  type        = bool
  description = "Set to TRUE if the Route53 is private (i.e. visible within VPC only)"
  default     = false
}

variable "route53_ttl" {
  type        = number
  description = "TTL of the DNS record, in seconds"
  default     = 300
}


