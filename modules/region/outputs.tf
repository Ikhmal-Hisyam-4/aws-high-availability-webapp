# Outputs for operator visibility (and for a future global/ layer if a DR region
# is ever added — it would read these via remote state, like the Alibaba design).

output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "VPC CIDR block."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Map of AZ key => public subnet ID."
  value       = { for k, v in aws_subnet.public : k => v.id }
}

output "private_subnet_ids" {
  description = "Map of AZ key => private subnet ID."
  value       = { for k, v in aws_subnet.private : k => v.id }
}

output "public_alb_dns_name" {
  description = "Public ALB DNS name — the Route 53 record target."
  value       = aws_lb.public.dns_name
}

output "public_alb_zone_id" {
  description = "Public ALB hosted zone ID (for Route 53 alias records)."
  value       = aws_lb.public.zone_id
}

output "internal_alb_dns_name" {
  description = "Internal ALB DNS name (FE -> BE)."
  value       = aws_lb.internal.dns_name
}

output "aurora_cluster_endpoint" {
  description = "Aurora writer endpoint."
  value       = aws_rds_cluster.this.endpoint
}

output "aurora_reader_endpoint" {
  description = "Aurora reader endpoint (load-balanced across readers)."
  value       = aws_rds_cluster.this.reader_endpoint
}

output "kms_key_arn" {
  description = "Regional KMS CMK ARN."
  value       = aws_kms_key.this.arn
}

output "db_secret_arn" {
  description = "Secrets Manager ARN holding the Aurora master password."
  value       = aws_secretsmanager_secret.db_password.arn
}

output "route53_health_check_id" {
  description = "Route 53 health check ID for the public endpoint."
  value       = aws_route53_health_check.public_endpoint.id
}

output "region_role" {
  description = "Role of this region (primary | dr)."
  value       = var.region_role
}
