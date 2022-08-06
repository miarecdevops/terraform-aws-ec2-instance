output "public_ip" {
  description = "Public IP address of the instance"
  value       = module.instance.public_ip
}

output "ec2_ssh_key_name" {
  value = aws_key_pair.generated_key.key_name
}

output "private_key" {
  value     = tls_private_key.generated_key.private_key_pem
  sensitive = true
}

output "public_key" {
  value = tls_private_key.generated_key.public_key_openssh
}