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

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = each.value.Action
        Effect   = each.value.Effect
        Resource = each.value.Resource
      },
    ]
  })
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
  ami           = var.ec2_ami_id
  key_name      = var.ec2_ssh_key_name
  instance_type = var.ec2_instance_type
  subnet_id     = var.subnet_list == null ? var.ec2_subnet_id : local.subnet_id_per_az

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

  tags = merge(
    var.tags,
    {
     Name = "${var.environment}-${var.role}"
    },
  )
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

  zone_id = data.aws_route53_zone.domain[0].zone_id
  name    = "${var.route53_a_record}.${data.aws_route53_zone.domain[0].name}"
  type    = "A"
  ttl     = var.route53_ttl
  records = [var.route53_zone_private == true ? data.aws_instance.instance.private_ip : data.aws_instance.instance.public_ip]
}
