variable "environment" {
  description = "Environment name used as prefix for resources created by the module."
  type        = string
  default     = "ec2-instance-windows-example"
}

variable "role" {
  description = "Role label for this example instance."
  type        = string
  default     = "windows-example"
}

variable "aws_profile" {
  description = "AWS credentials profile name."
  type        = string
  default     = "default"
}

variable "aws_region" {
  description = "Target AWS region."
  type        = string
  default     = "us-west-2"
}

variable "instance_type" {
  description = "EC2 instance type for the Windows host."
  type        = string
  default     = "m6i.large"
}

variable "volume_size" {
  description = "Root volume size in GB."
  type        = number
  default     = 80
}

variable "ec2_ami_os_release" {
  description = "Windows Server release to deploy (supported: 2019, 2022, 2025)."
  type        = string
  default     = "2022"
}

variable "rdp_source_cidr" {
  description = "CIDR block permitted to access RDP (TCP/3389)."
  type        = string
  default     = "0.0.0.0/0"
}

variable "tags" {
  description = "Additional tags to apply to the instance and supporting resources."
  type        = map(string)
  default = {
    Project = "miarec-windows-demo"
  }
}
