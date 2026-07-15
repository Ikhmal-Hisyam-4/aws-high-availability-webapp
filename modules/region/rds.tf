# Aurora MySQL — the diagram's "Aurora DB (writer) + 2 sync in-AZ replicas".
#
# Aurora is ONE distributed storage volume, 6-way replicated across 3 AZs. The
# cluster has a single writer + reader instances; on writer/AZ loss Aurora
# auto-fails-over to a reader (typically < 60s) — that is the in-region HA story.
# Automated backups + snapshots (PITR) cover logical corruption (bad deploy,
# dropped table) that replication would otherwise faithfully copy.

# Cluster spans the private subnets across all AZs.
resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-db-subnets"
  subnet_ids = [for k in local.az_keys : aws_subnet.private[k].id]
  tags       = local.common_tags
}

# DB master password lives in Secrets Manager, encrypted by the regional CMK —
# not passed around as a plain value downstream. The password enters once (CI
# variable) to seed the secret; consumers read it from here.
resource "aws_secretsmanager_secret" "db_password" {
  name        = "${var.name_prefix}-aurora-master-password"
  description = "${var.name_prefix} Aurora master account password"
  kms_key_id  = aws_kms_key.this.arn
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = var.db_master_password
}

resource "aws_rds_cluster" "this" {
  cluster_identifier = "${var.name_prefix}-aurora"
  engine             = "aurora-mysql"
  engine_version     = var.db_engine_version

  database_name   = var.db_name
  master_username = var.db_master_username
  # Read the password back from the managed secret rather than the raw variable.
  master_password = aws_secretsmanager_secret_version.db_password.secret_string

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]

  # Encryption at rest with the regional CMK.
  storage_encrypted = true
  kms_key_id        = aws_kms_key.this.arn

  # Automated backups -> point-in-time restore (logical corruption / bad deploy).
  backup_retention_period      = var.db_backup_retention_days
  preferred_backup_window      = "02:00-03:00"
  preferred_maintenance_window = "sun:04:00-sun:05:00"

  skip_final_snapshot = true # PLACEHOLDER: set false + final_snapshot_identifier for prod.

  tags = merge(local.common_tags, {
    Tier         = "aurora"
    WriterIntent = var.region_role == "primary" ? "read-write" : "read-only-until-failover"
  })
}

# Writer + readers. count = 1 writer + var.db_replica_count readers. Aurora picks
# distinct AZs automatically, giving the cross-AZ instance spread in the diagram.
resource "aws_rds_cluster_instance" "this" {
  count = 1 + var.db_replica_count

  identifier         = "${var.name_prefix}-aurora-${count.index}"
  cluster_identifier = aws_rds_cluster.this.id
  engine             = aws_rds_cluster.this.engine
  engine_version     = aws_rds_cluster.this.engine_version
  instance_class     = var.db_instance_class

  db_subnet_group_name = aws_db_subnet_group.this.name

  # Faster auto-failover targets the lowest-numbered healthy reader first.
  promotion_tier = count.index

  tags = merge(local.common_tags, {
    Tier = "aurora"
    Role = count.index == 0 ? "writer-preferred" : "reader"
  })
}
