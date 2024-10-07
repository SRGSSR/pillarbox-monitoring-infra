output "s3_mgmt_bucket" {
  description = "S3 bucket for mgmt"
  value       = one(aws_s3_bucket.s3-terraform[*].id)
}
