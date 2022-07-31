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
