# Networking: one VPC, public + private subnet per AZ, single NAT gateway for
# private-subnet outbound. for_each over var.availability_zones makes the AZ
# count data-driven (no copy-paste) — same pattern as the Alibaba module.

locals {
  common_tags = merge(var.tags, {
    Project    = "nexus-global-systems"
    Region     = var.region_id
    RegionRole = var.region_role
    ManagedBy  = "terraform"
    NamePrefix = var.name_prefix
  })

  az_keys = keys(var.availability_zones)
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.common_tags, { Name = "${var.name_prefix}-vpc" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.common_tags, { Name = "${var.name_prefix}-igw" })
}

# Public subnet per AZ (FE tier + public ALB live here).
resource "aws_subnet" "public" {
  for_each = var.availability_zones

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.value.az_name
  cidr_block              = each.value.public_cidr
  map_public_ip_on_launch = true
  tags                    = merge(local.common_tags, { Name = "${var.name_prefix}-pub-${each.key}", Tier = "public", AZ = each.key })
}

# Private subnet per AZ (BE tier + Aurora live here).
resource "aws_subnet" "private" {
  for_each = var.availability_zones

  vpc_id            = aws_vpc.this.id
  availability_zone = each.value.az_name
  cidr_block        = each.value.private_cidr
  tags              = merge(local.common_tags, { Name = "${var.name_prefix}-priv-${each.key}", Tier = "private", AZ = each.key })
}

# ---- Public routing: 0.0.0.0/0 -> Internet Gateway ----
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = merge(local.common_tags, { Name = "${var.name_prefix}-rt-public" })
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# ---- NAT gateway: private subnets get outbound (package updates, API calls)
# while staying unreachable from the internet. One NAT in the first public
# subnet serves the VPC (cost-conscious; one-per-AZ is the HA upgrade). ----
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = merge(local.common_tags, { Name = "${var.name_prefix}-nat-eip" })
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[local.az_keys[0]].id
  tags          = merge(local.common_tags, { Name = "${var.name_prefix}-nat" })
  depends_on    = [aws_internet_gateway.this]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }
  tags = merge(local.common_tags, { Name = "${var.name_prefix}-rt-private" })
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}
