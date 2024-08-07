output "instance_id" {
  value = aws_instance.instance.id
}

output "instance_tags" {
  value = aws_instance.instance.tags
}

output "private_ip" {
    value = aws_instance.instance.private_ip
}

output "public_ip" {
    value = var.ec2_assign_eip == true ? aws_eip.eip[0].public_ip : aws_instance.instance.public_ip
}

output "secondary_private_ip" {
    value = var.ec2_secondary_private_ip == null ? null : aws_instance.instance.secondary_private_ips
}

output "secondary_public_ip" {
    value = var.ec2_secondary_private_ip != null && var.ec2_assign_secondary_eip == true ? aws_eip.secondary_eip[0].public_ip : null
}

output "fqdn" {
    value = length(aws_route53_record.record) > 0 ? aws_route53_record.record[0].fqdn : null
}

output "iam_role" {
    value = length(aws_iam_role.role) > 0 ? aws_iam_role.role[0].arn : null
}

output "az" {
    value = aws_instance.instance.availability_zone
}