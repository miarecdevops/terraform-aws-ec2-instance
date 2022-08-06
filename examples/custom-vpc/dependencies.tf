# ---------------------------------------------------------------------------------------------------------------------
# LOOK UP THE LATEST UBUNTU AMI
# ---------------------------------------------------------------------------------------------------------------------

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "image-type"
    values = ["machine"]
  }

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

// --------------------------------------------
// Generate SSH Key for EC2 Access
// --------------------------------------------
resource "tls_private_key" "generated_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Generate a Random ID to ensure AWS keys are unique when uploaded to AWS account
resource "random_id" "tls_key_suffix" {
  byte_length = 8
}

# Create AWS Key Pair
resource "aws_key_pair" "generated_key" {
  key_name   = "${var.environment}-${var.role}-key-${random_id.tls_key_suffix.hex}"
  public_key = tls_private_key.generated_key.public_key_openssh
}

# Create Local Copy of private key for storage
resource "local_sensitive_file" "priv_key_pem" {
  content = tls_private_key.generated_key.private_key_pem
  filename          = "priv_key.pem"
  file_permission   = "0600"
}

// ---------------------------------------------------------
// VPC
// ---------------------------------------------------------
locals {
  public_cidr_block  = cidrsubnet(var.vpc_cidr, 1, 0)
  private_cidr_block = cidrsubnet(var.vpc_cidr, 1, 1)

  // Define map zone_name => index
  availability_zones_map = { for idx, az in var.availability_zones : az => idx }
}

resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr

  tags = {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
  }
}

// ---------------------------------------------------------
// Public subnets
// ---------------------------------------------------------
resource "aws_subnet" "public_subnets" {
  for_each = local.availability_zones_map

  vpc_id            = aws_vpc.vpc.id
  availability_zone = each.key
  cidr_block        = cidrsubnet(local.public_cidr_block, 7, each.value)

  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.environment}-${each.key}-public-subnet"
    Environment = var.environment
  }
}

// ---------------------------------------------------------
// Internet gateway
// It is required for the Internet access to/from public subnets
// ---------------------------------------------------------
resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name        = "${var.environment}-igw"
    Environment = var.environment
  }
}

// ---------------------------------------------------------
// Route table for public subnets (Internet access)
// Note a route table is shared by all public subnets
// ---------------------------------------------------------
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ig.id
  }
  tags = {
    Name        = "${var.environment}-public-route-table"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "public_route_table_assoc" {
  for_each = local.availability_zones_map

  subnet_id      = aws_subnet.public_subnets[each.key].id
  route_table_id = aws_route_table.public_route_table.id

  depends_on = [
    aws_subnet.public_subnets,
    aws_route_table.public_route_table,
  ]
}
