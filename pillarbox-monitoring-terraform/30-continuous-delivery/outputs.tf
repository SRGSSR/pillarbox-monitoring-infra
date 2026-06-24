output "gha_role_arns" {
  description = "ARNs of the GitHub Actions IAM roles"
  value = {
    for name, role in aws_iam_role.gha_role :
    name => role.arn
  }
}
