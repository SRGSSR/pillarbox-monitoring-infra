output "grafana_endpoint" {
  description = "Grafana endpoint"
  value       = aws_grafana_workspace.grafana_workspace.endpoint
}

output "opensearch_endpoint" {
  description = "The endpoint of the OpenSearch domain"
  value       = aws_opensearch_domain.opensearch_domain.endpoint
}

output "dispatch_dns_name" {
  description = "The DNS name of the Dispatch Service Load Balancer"
  value       = aws_alb.dispatch_alb.dns_name
}

output "grafana_alert_topic" {
  description = "The ARN of the topic for grafana alerts"
  value       = aws_sns_topic.grafana_alerts.arn
}

output "ec2_proxy_private_ip" {
  description = "Private IP of the EC2 Nginx Proxy Instance (accessible within VPC)"
  value       = aws_instance.il_proxy.private_ip
}
