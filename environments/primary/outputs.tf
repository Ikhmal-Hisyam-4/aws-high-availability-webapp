output "vpc_id" {
  value = module.region.vpc_id
}

output "public_alb_dns_name" {
  description = "Public ALB DNS name — point your Route 53 record here."
  value       = module.region.public_alb_dns_name
}

output "aurora_cluster_endpoint" {
  description = "Aurora writer endpoint."
  value       = module.region.aurora_cluster_endpoint
}

output "aurora_reader_endpoint" {
  description = "Aurora reader endpoint."
  value       = module.region.aurora_reader_endpoint
}

output "db_secret_arn" {
  value = module.region.db_secret_arn
}

output "route53_health_check_id" {
  value = module.region.route53_health_check_id
}
