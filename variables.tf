# Global Variables
variable "environment" {
  type        = string
  description = "Name of environment (all tags will start with this name)."
}

variable "role" {
  type        = string
  description = "Role for this module, will be used in naming resources."
}

variable "tags" {
  description = "Tags to set on all resources."
  type        = map(string)
}

variable "index" {
  type        = number
  description = "count index"
}

variable "subnet_ids" {
  description = "map of Subnet IDs to attach to EC2"
  type = any
}

variable "availabilty_zones" {
  description = "list of availability zones"
  type = list
}

# Security Group Variables
variable "vpc_id" {
  type        = string
  description = "ID of VPC resources will be attached"
}

variable "sg_rules" {
  type        = map(map(string))
}

# IAM Variables
variable "iam_policy" {
  description =  "IAM policys that will be attahed to IAM Role"
  type = map(map(string))
}

# EC2 instance Variables
variable "ec2_image_id" {
  type        = string
  description = "AMI ID. Caution! It is unique for each region"
}

variable "ec2_ssh_key_name" {
  type        = string
  description = "SSH Key Pair Name. Such key must exist in EC2 console"
}

variable "ec2_instance_type" {
  type        = string
  description = "ec2 instance type"
}

variable "ec2_volume_size" {
  type        = number
  description = "Disk size in GB"
}

variable "user_data" {
  type        = any
  description = "script to be loaded on ec2 creation"
  default = null
}

# Route53 Variables
variable "route53_a_record" {
  type        = string
  description = "Host portion of FQDN"
}

variable "route53_ttl" {
  type        = number
  description = "ttl of the DNS record, in seconds"
  default     = null
}

variable "route53_zone_id_public" {
  type        = string
  description = "Route53 Zone id to build A record in"
  default     = null
}

variable "route53_domain_public" {
  type        = string
  description = "Domain portion of FQDN"
  default     = null
}

variable "route53_zone_id_private" {
  type        = string
  description = "Route53 Zone id to build A record in for private resolution"
  default     = null
}

variable "route53_domain_private" {
  type        = string
  description = "Domain portion of FQDN for private resolution"
  default     = null
}

