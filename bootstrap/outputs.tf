output "instance_id" {
  value = aws_instance.workstation.id
}

output "role_name" {
  value = aws_iam_role.workstation.name
}

output "boundary_arn" {
  value = aws_iam_policy.boundary.arn
}
