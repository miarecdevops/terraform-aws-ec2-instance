output "instance_public_ip" {
  description = "Public IP of the Windows instance (requires ec2_assign_eip = true)."
  value       = module.windows_instance.public_ip
}

output "rdp_connection_hint" {
  description = "Helper string showing how to start an RDP session once credentials are retrieved."
  value       = "mstsc /v ${module.windows_instance.public_ip}"
}
