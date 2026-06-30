# -----------------------------------------------------------------------------
# PRIMARY (ap-southeast-5 / Kuala Lumpur) — ACTIVE region.
#
# Single-region, multi-AZ HA (matches the architecture diagram). There is no
# region-specific resource code here — just data fed into the reusable module.
# A future DR region would be a sibling env calling the same module.
# -----------------------------------------------------------------------------
module "region" {
  source = "../../modules/region"

  region_role = "primary"
  name_prefix = "nexus-primary"
  region_id   = var.region_id
  vpc_cidr    = "10.0.0.0/16"

  # Three AZs, public (FE) + private (BE/Aurora) subnets each.
  availability_zones = {
    a = {
      az_name      = "ap-southeast-5a"
      public_cidr  = "10.0.1.0/24"
      private_cidr = "10.0.2.0/24"
    }
    b = {
      az_name      = "ap-southeast-5b"
      public_cidr  = "10.0.3.0/24"
      private_cidr = "10.0.4.0/24"
    }
    c = {
      az_name      = "ap-southeast-5c"
      public_cidr  = "10.0.5.0/24"
      private_cidr = "10.0.6.0/24"
    }
  }

  # Aurora: 1 writer + 2 readers across the three AZs.
  db_replica_count   = 2
  db_master_password = var.db_master_password

  tags = {
    Environment = "production"
    Tier        = "active"
  }
}
