# Compute tiers: stateless FE + BE EC2, each fronted by an Auto Scaling Group
# (the "2 ASGs (FE + BE) each across 3 AZs" box in the diagram). State lives in
# Aurora, so instances are disposable. Each ASG spans all AZs and self-heals.

# AMI — auto-resolve newest Ubuntu 22.04 unless an explicit AMI is supplied.
# AMI IDs are region-specific, so this looks one up in the caller's region.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  ami_id          = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu.id
  public_subnets  = [for k in local.az_keys : aws_subnet.public[k].id]
  private_subnets = [for k in local.az_keys : aws_subnet.private[k].id]
}

# EBS root volumes encrypted with the regional CMK.
locals {
  block_device = {
    device_name = "/dev/sda1"
    ebs = {
      volume_size = 20
      volume_type = "gp3"
      encrypted   = true
      kms_key_id  = aws_kms_key.this.arn
    }
  }
}

# ============================== FE tier =====================================
resource "aws_launch_template" "fe" {
  name_prefix   = "${var.name_prefix}-fe-"
  image_id      = local.ami_id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.fe.id]

  block_device_mappings {
    device_name = local.block_device.device_name
    ebs {
      volume_size = local.block_device.ebs.volume_size
      volume_type = local.block_device.ebs.volume_type
      encrypted   = local.block_device.ebs.encrypted
      kms_key_id  = local.block_device.ebs.kms_key_id
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.common_tags, { Name = "${var.name_prefix}-fe", Tier = "fe" })
  }
}

resource "aws_autoscaling_group" "fe" {
  name                = "${var.name_prefix}-asg-fe"
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  desired_capacity    = var.asg_desired_capacity
  vpc_zone_identifier = local.public_subnets # spread across all public subnets -> multi-AZ
  target_group_arns   = [aws_lb_target_group.fe.arn]
  health_check_type   = "ELB"

  launch_template {
    id      = aws_launch_template.fe.id
    version = "$Latest"
  }

  tag {
    key                 = "Tier"
    value               = "fe"
    propagate_at_launch = true
  }
}

# ============================== BE tier =====================================
resource "aws_launch_template" "be" {
  name_prefix   = "${var.name_prefix}-be-"
  image_id      = local.ami_id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.be.id]

  block_device_mappings {
    device_name = local.block_device.device_name
    ebs {
      volume_size = local.block_device.ebs.volume_size
      volume_type = local.block_device.ebs.volume_type
      encrypted   = local.block_device.ebs.encrypted
      kms_key_id  = local.block_device.ebs.kms_key_id
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.common_tags, { Name = "${var.name_prefix}-be", Tier = "be" })
  }
}

resource "aws_autoscaling_group" "be" {
  name                = "${var.name_prefix}-asg-be"
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  desired_capacity    = var.asg_desired_capacity
  vpc_zone_identifier = local.private_subnets
  target_group_arns   = [aws_lb_target_group.be.arn]
  health_check_type   = "ELB"

  launch_template {
    id      = aws_launch_template.be.id
    version = "$Latest"
  }

  tag {
    key                 = "Tier"
    value               = "be"
    propagate_at_launch = true
  }
}
