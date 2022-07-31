output "instance_id" {
  value = aws_instance.instance.id
}

output "private_ip" {
    value = aws_instance.instance.private_ip
}

output "public_ip" {
    value = aws_instance.instance.public_ip
}

output "fqdn" {
    value = length(aws_route53_record.record) > 0 ? aws_route53_record.record[0].fqdn : null
}

output "iam_role" {
    value = length(aws_iam_role.role) > 0 ? aws_iam_role.role[0].arn : null
}