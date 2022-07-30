// --------------------------------------------
// EC2 instance
// --------------------------------------------
# Assign a subnet ID per availibilty zone, this is to balance instances between zones,
# if no VPC ID is specified than it is assumed that all resources will be deployed in default VPC and this variable is not needed
locals {
  ec2_subnet_id = var.vpc_id == null ? null : (var.index % 2 == 0 ? var.subnet_ids[var.availabilty_zones[0]] : var.subnet_ids[var.availabilty_zones[1]])
}

# Create IAM Role
resource "aws_iam_role" "role" {
  name = "${var.environment}-${var.role}-${var.index}-iam_role"
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
     Name = "${var.environment}-${var.role}-${var.index}-iam_policy"
    },
  )
}

# Create IAM Role Policies and attach to IAM Role
resource "aws_iam_role_policy" "policy" {
  for_each = var.iam_policy
  name = "${var.environment}-${var.role}-${var.index}-${each.key}-policy"
  role = aws_iam_role.role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = [each.value.action]
        Effect   = each.value.effect
        Resource = each.value.resource
      },
    ]
  })
}

resource "aws_iam_instance_profile" "profile" {
  name = "${var.environment}-${var.role}-${var.index}-iam_instance_policy"
  role = aws_iam_role.role.name
}

# Create Security Group and Rules
resource "aws_security_group" "sg" {
  name       = "${var.environment}-${var.role}${var.index}-security_group"
  vpc_id     = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    var.tags,
    {
     Name = "${var.environment}-${var.role}${var.index}-security_group"
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

# Build EC2 Instance
resource "aws_instance" "instance" {
  ami           = var.ec2_image_id
  key_name      = var.ec2_ssh_key_name
  instance_type = var.ec2_instance_type
  subnet_id     = local.ec2_subnet_id

  iam_instance_profile   = aws_iam_instance_profile.profile.id
  vpc_security_group_ids = [aws_security_group.sg.id]

  root_block_device {
    volume_size = var.ec2_volume_size
  }

  user_data = var.user_data

  tags = merge(
    var.tags,
    {
     Name = "${var.environment}-${var.role}${var.index}"
    },
  )
}

# Create Route53 A record for Public resolution if in Public Subnet
resource "aws_route53_record" "record_public" {
  count = var.route53_zone_id_public == null ? 0 : 1

  zone_id = var.route53_zone_id_public
  name    = "${var.route53_a_record}.${var.route53_domain_public}"
  type    = "A"
  ttl     = var.route53_ttl
  records = [aws_instance.instance.public_ip]
}

# Create Route53 A record for Private resolution
resource "aws_route53_record" "record_private" {
  count = var.route53_zone_id_private == null ? 0 : 1

  zone_id = var.route53_zone_id_private
  name    = "${var.route53_a_record}.${var.route53_domain_private}"
  type    = "A"
  ttl     = var.route53_ttl
  records = [aws_instance.instance.private_ip]
}
