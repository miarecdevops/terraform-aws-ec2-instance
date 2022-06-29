output "instance_id" {
  value = aws_instance.instance.id
}

output "private_ip_address" {
    value = aws_instance.instance.private_ip
}

output "public_ip_address" {
    value = aws_instance.instance.public_ip
}

output "fqdn" {
    value = aws_route53_record.record_public[*].fqdn
}

output "private_fqdn" {
    value = aws_route53_record.record_private[*].fqdn
}

output "iam_role" {
    value = aws_iam_role.role.arn
}