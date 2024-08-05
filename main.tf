// --------------------------------------------
// AMI lookup
// --------------------------------------------

locals {
  ami_owner = {
    centos = "125523088429", # Community Platform Engineering (https://wiki.centos.org/Cloud/AWS)
    ubuntu = "099720109477", # Canonical
    rocky  = "792107900819"  # RockyLinux
  }

  ami_name = {
    centos = "CentOS Linux 7*"
    ubuntu = "ubuntu/images/hvm-ssd*/ubuntu-*-${var.ec2_ami_os_release}-amd64-server-*"
    rocky  = "Rocky-${var.ec2_ami_os_release}-*"
  }

}

data "aws_ami" "ami" {
  most_recent = true
  owners      = [lookup(local.ami_owner, var.ec2_ami_os, "099720109477")]

  filter {
    name   = "virtualization-type"
    values = [var.ec2_ami_virtualization]
  }

  filter {
    name   = "architecture"
    values = [var.ec2_ami_archtecture]
  }

  filter {
    name   = "image-type"
    values = [var.ec2_ami_image-type]
  }

  filter {
    name   = "name"
    values = [lookup(local.ami_name, var.ec2_ami_os, "ubuntu/images/hvm-ssd/ubuntu-*-${var.ec2_ami_os_release}-amd64-server-*")]
  }
}


// --------------------------------------------
// Network
// --------------------------------------------

data "aws_vpc" "default" {
  default = true
}

locals {
  vpc_id = var.vpc_id != null ? var.vpc_id : data.aws_vpc.default.id
  subnet_id_per_az = var.subnet_list == null ? null : (var.index % 2 == 0 ? var.subnet_list[var.availability_zones[0]] : var.subnet_list[var.availability_zones[1]])
}

# --------------------------------------------
# Create IAM Role
# --------------------------------------------
resource "aws_iam_role" "role" {
  count  = length(keys(var.iam_policies)) > 0 ? 1 : 0
  name = "${var.environment}-${var.role}-iam_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = merge(
    var.tags,
    {
     Name = "${var.environment}-${var.role}-iam_policy"
    },
  )
}

# Create IAM Role Policies and attach to IAM Role
resource "aws_iam_role_policy" "policy" {
  for_each = var.iam_policies
  name = "${var.environment}-${var.role}-${each.key}-policy"
  role = aws_iam_role.role[0].id

  policy = each.value
}

resource "aws_iam_instance_profile" "profile" {
  count  = length(keys(var.iam_policies)) > 0 ? 1 : 0
  name = "${var.environment}-${var.role}-iam_instance_policy"
  role = aws_iam_role.role[0].name
}

# -------------------------------------------
# Create Security Group and Rules
# -------------------------------------------
resource "aws_security_group" "sg" {
  name       = "${var.environment}-${var.role}-security_group"
  vpc_id     = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    var.tags,
    {
     Name = "${var.environment}-${var.role}-security_group"
    },
  )
 }

resource "aws_security_group_rule" "rule" {
  for_each          = var.sg_rules

  type              = each.value.type
  description       = each.key
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  cidr_blocks       = [each.value.cidr]
  security_group_id = aws_security_group.sg.id
}

# -------------------------------------------
# Build EC2 Instance
# -------------------------------------------
resource "aws_instance" "instance" {
  ami           = var.ec2_ami_id == null ? data.aws_ami.ami.id : var.ec2_ami_id
  key_name      = var.ec2_ssh_key_name
  instance_type = var.ec2_instance_type
  subnet_id     = var.subnet_list == null ? var.ec2_subnet_id : local.subnet_id_per_az

  secondary_private_ips = var.ec2_secondary_private_ip == null ? null : [var.ec2_secondary_private_ip]

  iam_instance_profile   = length(aws_iam_instance_profile.profile) > 0 ? aws_iam_instance_profile.profile[0].id : null
  vpc_security_group_ids = [aws_security_group.sg.id]

  root_block_device {
    volume_size = var.ec2_volume_size
  }

  metadata_options {
    http_endpoint          = var.ec2_metadata == true ? "enabled": "disabled"
    instance_metadata_tags = var.ec2_metadata == true ? "enabled": "disabled"
  }


  user_data = var.user_data

  lifecycle {
    ignore_changes = [ami]    # prevents re-creation of instance if AMI changes due to update in AWS registry
  }

  tags = merge(
    var.tags,
    {
     Name = "${var.environment}-${var.role}"
    },
  )
}

# -------------------------------------------
# Create a static IP address
# -------------------------------------------

resource "aws_eip" "eip" {
  count = var.ec2_assign_eip == true ? 1 : 0
  instance = aws_instance.instance.id
}

resource "aws_eip" "secondary_eip" {
  count = var.ec2_assign_secondary_eip == true ? 1 : 0
  instance = aws_instance.instance.id
  associate_with_private_ip = var.ec2_secondary_private_ip
}

# -------------------------------------------
# Create Route53 A record for Public resolution if in Public Subnet
# -------------------------------------------
data "aws_route53_zone" "domain" {
  count        = var.route53_a_record != null ? 1 : 0
  name         = var.route53_zone
  private_zone = var.route53_zone_private
}

//this is required because of a limitation with terraform
// in some cases if the instnace modified terraform will not
// recognize this in its planning stage, this forces lookup of the data
data "aws_instance" "instance" {
  instance_id = aws_instance.instance.id
}

resource "aws_route53_record" "record" {
  count = var.route53_a_record != null ? 1 : 0

  name = (
    var.route53_a_record == "@" ?
    data.aws_route53_zone.domain[0].name :
    "${var.route53_a_record}.${data.aws_route53_zone.domain[0].name}"
  )
  zone_id = data.aws_route53_zone.domain[0].zone_id
  type    = "A"
  ttl     = var.route53_ttl
  records = [var.route53_zone_private == true ?
             data.aws_instance.instance.private_ip :
             var.ec2_assign_eip == true ?
                aws_eip.eip[0].public_ip :
                aws_instance.instance.public_ip
             ]
}