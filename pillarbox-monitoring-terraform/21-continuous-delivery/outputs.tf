output "gha_role_arns" {
  description = "ARNs of the GitHub Actions IAM roles"
  value = {
    for k, role in aws_iam_role.gha_role :
    k => role.arn
  }
}
