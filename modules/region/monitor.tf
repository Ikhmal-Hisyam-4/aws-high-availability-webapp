# CloudWatch alarms + Route 53 health check (the diagram's bottom CloudWatch box
# and the "DNS + ALB health checks" on Route 53). Alarms notify an SNS topic.

# SNS topic for alarm notifications — create one unless the caller supplies an ARN.
resource "aws_sns_topic" "alarms" {
  count = var.alarm_sns_topic_arn == "" ? 1 : 0
  name  = "${var.name_prefix}-alarms"
  tags  = local.common_tags
}

locals {
  alarm_sns_arn = var.alarm_sns_topic_arn != "" ? var.alarm_sns_topic_arn : aws_sns_topic.alarms[0].arn
}

# --- FE ASG average CPU ---
resource "aws_cloudwatch_metric_alarm" "fe_cpu" {
  alarm_name          = "${var.name_prefix}-fe-cpu-high"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 85
  period              = 300
  evaluation_periods  = 3
  dimensions          = { AutoScalingGroupName = aws_autoscaling_group.fe.name }
  alarm_actions       = [local.alarm_sns_arn]
  tags                = local.common_tags
}

# --- BE ASG average CPU ---
resource "aws_cloudwatch_metric_alarm" "be_cpu" {
  alarm_name          = "${var.name_prefix}-be-cpu-high"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 85
  period              = 300
  evaluation_periods  = 3
  dimensions          = { AutoScalingGroupName = aws_autoscaling_group.be.name }
  alarm_actions       = [local.alarm_sns_arn]
  tags                = local.common_tags
}

# --- Aurora replica lag: alerts if a reader falls behind the writer ---
resource "aws_cloudwatch_metric_alarm" "aurora_replica_lag" {
  alarm_name          = "${var.name_prefix}-aurora-replica-lag"
  namespace           = "AWS/RDS"
  metric_name         = "AuroraReplicaLag"
  statistic           = "Average"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1000 # milliseconds
  period              = 60
  evaluation_periods  = 3
  dimensions          = { DBClusterIdentifier = aws_rds_cluster.this.cluster_identifier }
  alarm_actions       = [local.alarm_sns_arn]
  tags                = local.common_tags
}

# --- ALB unhealthy host count (target health on the public FE target group) ---
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  alarm_name          = "${var.name_prefix}-alb-unhealthy-hosts"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  period              = 60
  evaluation_periods  = 3
  dimensions = {
    LoadBalancer = aws_lb.public.arn_suffix
    TargetGroup  = aws_lb_target_group.fe.arn_suffix
  }
  alarm_actions = [local.alarm_sns_arn]
  tags          = local.common_tags
}

# --- Route 53 health check: external probe of the public ALB (the "region-dark"
# probe). Route 53 evaluates it from multiple global checkers. ---
resource "aws_route53_health_check" "public_endpoint" {
  fqdn              = aws_lb.public.dns_name
  type              = "HTTPS"
  resource_path     = var.health_check_path
  port              = 443
  request_interval  = 30
  failure_threshold = 3
  tags              = merge(local.common_tags, { Name = "${var.name_prefix}-region-dark-probe" })
}
