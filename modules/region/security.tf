# Regional KMS CMK + tiered Security Groups.
# A KMS CMK is regional; the key encrypts EBS volumes, Aurora storage, and the
# Secrets Manager secret. Tiered SGs mean each tier only accepts traffic from the
# one in front:  internet --443--> ALB --443--> SG-FE --app_port--> SG-BE --3306--> SG-DB

resource "aws_kms_key" "this" {
  description             = "${var.name_prefix} regional CMK (EBS + Aurora + Secrets Manager)"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = local.common_tags
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.name_prefix}-cmk"
  target_key_id = aws_kms_key.this.key_id
}

# ---- ALB security group: 80/443 from the internet (public ALB). ----
resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-sg-alb"
  description = "Public ALB: HTTPS/HTTP from internet"
  vpc_id      = aws_vpc.this.id
  tags        = merge(local.common_tags, { Tier = "alb" })
}

resource "aws_security_group_rule" "alb_https_in" {
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  security_group_id = aws_security_group.alb.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "HTTPS from internet"
}

resource "aws_security_group_rule" "alb_http_in" {
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 80
  to_port           = 80
  security_group_id = aws_security_group.alb.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "HTTP from internet (redirect to HTTPS)"
}

resource "aws_security_group_rule" "alb_egress" {
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  security_group_id = aws_security_group.alb.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "ALB to targets"
}

# ---- FE tier: 443 from the ALB only. ----
resource "aws_security_group" "fe" {
  name        = "${var.name_prefix}-sg-fe"
  description = "FE tier: traffic from public ALB only"
  vpc_id      = aws_vpc.this.id
  tags        = merge(local.common_tags, { Tier = "fe" })
}

resource "aws_security_group_rule" "fe_from_alb" {
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 443
  to_port                  = 443
  security_group_id        = aws_security_group.fe.id
  source_security_group_id = aws_security_group.alb.id
  description              = "HTTPS from public ALB"
}

resource "aws_security_group_rule" "fe_egress" {
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  security_group_id = aws_security_group.fe.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "FE outbound (to internal ALB / NAT)"
}

# ---- Internal ALB security group: app_port from FE tier only. ----
resource "aws_security_group" "alb_internal" {
  name        = "${var.name_prefix}-sg-alb-internal"
  description = "Internal ALB: app port from FE tier only"
  vpc_id      = aws_vpc.this.id
  tags        = merge(local.common_tags, { Tier = "alb-internal" })
}

resource "aws_security_group_rule" "alb_internal_from_fe" {
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = var.app_port
  to_port                  = var.app_port
  security_group_id        = aws_security_group.alb_internal.id
  source_security_group_id = aws_security_group.fe.id
  description              = "App port from FE tier"
}

resource "aws_security_group_rule" "alb_internal_egress" {
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  security_group_id = aws_security_group.alb_internal.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Internal ALB to BE targets"
}

# ---- BE tier: app_port from the internal ALB only. ----
resource "aws_security_group" "be" {
  name        = "${var.name_prefix}-sg-be"
  description = "BE tier: app port from internal ALB only"
  vpc_id      = aws_vpc.this.id
  tags        = merge(local.common_tags, { Tier = "be" })
}

resource "aws_security_group_rule" "be_from_internal_alb" {
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = var.app_port
  to_port                  = var.app_port
  security_group_id        = aws_security_group.be.id
  source_security_group_id = aws_security_group.alb_internal.id
  description              = "App port from internal ALB"
}

resource "aws_security_group_rule" "be_egress" {
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  security_group_id = aws_security_group.be.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "BE outbound (to DB / NAT)"
}

# ---- DB tier: 3306 from BE tier only. ----
resource "aws_security_group" "db" {
  name        = "${var.name_prefix}-sg-db"
  description = "Aurora: MySQL 3306 from BE tier only"
  vpc_id      = aws_vpc.this.id
  tags        = merge(local.common_tags, { Tier = "db" })
}

resource "aws_security_group_rule" "db_from_be" {
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 3306
  to_port                  = 3306
  security_group_id        = aws_security_group.db.id
  source_security_group_id = aws_security_group.be.id
  description              = "MySQL from BE tier"
}
