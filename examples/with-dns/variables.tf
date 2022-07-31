variable "environment" {
  description = "Name of environment (all tags will be prefixed with such name)"
  type        = string
  default     = "example-ec2-instance-module-with-dns"
}

variable "role" {
  description = "Role for this instance, will be used in naming resources"
  type        = string
  default     = "example"
}

variable "aws_profile" {
  description = "AWS credentials profile name"
  default     = "default"
  type        = string
}

variable "aws_region" {
  default     = "us-west-2"
  description = "The AWS region"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}