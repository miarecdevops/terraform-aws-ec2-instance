variable "stack" {
  description = "Name of the stack. Prefixes the name of every resource."
  type        = string
  default     = "ec2-instance-module-with-dns"
}

variable "role" {
  description = "Role for this instance, will be used in naming resources"
  type        = string
  default     = "example"
}

variable "aws_profile" {
  description = "AWS credentials profile name. When null, the provider uses the default credential chain (environment variables, shared config, or an instance role)."
  default     = null
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