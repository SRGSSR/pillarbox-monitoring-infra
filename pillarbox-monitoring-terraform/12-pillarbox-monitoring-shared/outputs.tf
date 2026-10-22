output "bastion_public_ip" {
  description = "Public IP of the Bastion Host"
  value       = aws_instance.bastion.public_ip
}

output "bastion_security_group_id" {
  description = "Security group of the Bastion Host, to authorize it on application resources"
  value       = aws_security_group.bastion_sg.id
}

output "vpc_endpoints_security_group_id" {
  description = "Security group attached to the shared VPC interface endpoints"
  value       = aws_security_group.vpc_endpoints_sg.id
}
