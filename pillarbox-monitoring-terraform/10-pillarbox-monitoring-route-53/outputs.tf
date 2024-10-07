output "route_53_name_servers" {
  description = "Route 53 name servers"
  value       = aws_route53_zone.main_zone.name_servers
}

output "route53_zone_id" {
  description = "Route 53 zone identifier"
  value       = aws_route53_zone.main_zone.zone_id
}