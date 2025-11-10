output "opensearch_endpoint" {
  description = "The endpoint of the OpenSearch domain"
  value       = aws_instance.opensearch.private_ip
}

output "dispatch_dns_name" {
  description = "The DNS name of the Dispatch Service Load Balancer"
  value       = aws_alb.dispatch_alb.dns_name
}

output "bastion_public_ip" {
  description = "Public IP of the Bastion Host"
  value       = aws_instance.bastion.public_ip
}
