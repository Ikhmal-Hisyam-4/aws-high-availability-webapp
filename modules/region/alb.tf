# Application Load Balancers — cross-AZ HA within the region.
#   Public ALB (internet-facing): Users -> FE   |   Internal ALB: FE -> BE
# Both span all AZs via their subnets. (Cross-region failover would be Route 53;
# in this single-region design Route 53 just health-checks the one public ALB.)

# ---- Public ALB: internet-facing, in the public subnets (FE tier) ----
resource "aws_lb" "public" {
  name               = "${var.name_prefix}-alb-public"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb.id]
  subnets            = [for k in local.az_keys : aws_subnet.public[k].id]
  tags               = merge(local.common_tags, { Tier = "alb-public" })
}

resource "aws_lb_target_group" "fe" {
  name        = "${var.name_prefix}-tg-fe"
  port        = 443
  protocol    = "HTTPS"
  vpc_id      = aws_vpc.this.id
  target_type = "instance"

  health_check {
    enabled  = true
    protocol = "HTTPS"
    path     = var.health_check_path
    matcher  = "200"
  }
  tags = merge(local.common_tags, { Tier = "fe" })
}

# HTTP :80 -> redirect to HTTPS.
resource "aws_lb_listener" "public_http_redirect" {
  load_balancer_arn = aws_lb.public.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS :443 -> FE target group.
resource "aws_lb_listener" "public_https" {
  load_balancer_arn = aws_lb.public.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  # Supply a real ACM certificate ARN via var.acm_certificate_arn at apply.
  certificate_arn = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.fe.arn
  }
}

# ---- Internal ALB: intranet-only, in the private subnets (BE tier) ----
resource "aws_lb" "internal" {
  name               = "${var.name_prefix}-alb-internal"
  load_balancer_type = "application"
  internal           = true
  security_groups    = [aws_security_group.alb_internal.id]
  subnets            = [for k in local.az_keys : aws_subnet.private[k].id]
  tags               = merge(local.common_tags, { Tier = "alb-internal" })
}

resource "aws_lb_target_group" "be" {
  name        = "${var.name_prefix}-tg-be"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.this.id
  target_type = "instance"

  health_check {
    enabled  = true
    protocol = "HTTP"
    path     = var.health_check_path
    matcher  = "200"
  }
  tags = merge(local.common_tags, { Tier = "be" })
}

resource "aws_lb_listener" "internal_app" {
  load_balancer_arn = aws_lb.internal.arn
  port              = var.app_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.be.arn
  }
}
