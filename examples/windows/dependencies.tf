terraform {
  required_version = ">= 1.3.0"
}

# ---------------------------------------------------------------------------------------------------------------------
# Generate an SSH key pair so we can retrieve the Windows administrator password later.
# ---------------------------------------------------------------------------------------------------------------------

resource "tls_private_key" "windows_generated_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "random_id" "windows_tls_key_suffix" {
  byte_length = 4
}

resource "aws_key_pair" "windows_generated_key" {
  key_name   = "${var.environment}-${var.role}-windows-${random_id.windows_tls_key_suffix.hex}"
  public_key = tls_private_key.windows_generated_key.public_key_openssh
}

resource "local_sensitive_file" "windows_priv_key_pem" {
  content         = tls_private_key.windows_generated_key.private_key_pem
  filename        = "windows_priv_key.pem"
  file_permission = "0600"
}
