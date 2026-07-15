# Region module inputs. Every region/AZ/CIDR/sizing value is a variable here; the
# module body has no region or AZ literals, so the same module can be reused for
# another region with only data changes.

variable "region_role" {
  description = "Logical role of this region instance: 'primary' (active) or 'dr' (standby). Drives tagging."
  type        = string
  validation {
    condition     = contains(["primary", "dr"], var.region_role)
    error_message = "region_role must be either 'primary' or 'dr'."
  }
}

variable "name_prefix" {
  description = "Prefix applied to all resource names, e.g. 'nexus-primary'."
  type        = string
}

variable "region_id" {
  description = "AWS region ID for this instance, e.g. 'ap-southeast-5' (Kuala Lumpur)."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block, e.g. 10.0.0.0/16."
  type        = string
}

# Per-AZ layout. Map keys ('a','b','c') are iterated with for_each to create a
# public + private subnet per AZ. Adding/removing an AZ is just a data change.
variable "availability_zones" {
  description = "Map of AZ short-key => { az_name, public_cidr, private_cidr }."
  type = map(object({
    az_name      = string
    public_cidr  = string
    private_cidr = string
  }))
  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least two AZs are required for cross-AZ HA."
  }
}

# ---- Database (Aurora MySQL) ----
variable "db_engine_version" {
  description = "Aurora MySQL engine version."
  type        = string
  default     = "8.0.mysql_aurora.3.05.2"
}

variable "db_instance_class" {
  description = "Aurora instance class (writer + readers)."
  type        = string
  default     = "db.r6g.large"
}

variable "db_replica_count" {
  description = "Number of Aurora reader instances (in addition to the writer). 2 readers + 1 writer = 3 instances spread across the AZs, matching the diagram."
  type        = number
  default     = 2
}

variable "db_name" {
  description = "Initial database name."
  type        = string
  default     = "nexus"
}

variable "db_master_username" {
  description = "Aurora master username."
  type        = string
  default     = "nexus_app"
}

variable "db_master_password" {
  description = "Aurora master password — seeds the Secrets Manager secret. Inject via CI variable / tfvars, never commit."
  type        = string
  sensitive   = true
  default     = "" # PLACEHOLDER: supply at apply time to seed the secret.
}

variable "db_backup_retention_days" {
  description = "Automated backup retention (days) — enables point-in-time restore."
  type        = number
  default     = 7
}

# ---- Compute (EC2 + Auto Scaling) ----
variable "instance_type" {
  description = "EC2 instance type for FE and BE tiers."
  type        = string
  default     = "t3.medium"
}

variable "ami_id" {
  description = "AMI ID for EC2 instances. Leave empty to auto-resolve the newest Ubuntu 22.04 AMI via the data source."
  type        = string
  default     = ""
}

variable "asg_min_size" {
  description = "Minimum instances per Auto Scaling group (per tier)."
  type        = number
  default     = 3 # one per AZ
}

variable "asg_max_size" {
  description = "Maximum instances per Auto Scaling group (per tier)."
  type        = number
  default     = 6
}

variable "asg_desired_capacity" {
  description = "Desired instances per Auto Scaling group (per tier)."
  type        = number
  default     = 3 # one per AZ
}

variable "app_port" {
  description = "Application port the BE tier listens on (FE -> internal ALB -> BE)."
  type        = number
  default     = 8080
}

# ---- Monitoring / failover ----
variable "health_check_path" {
  description = "HTTP path used by ALB target groups and the Route 53 health check."
  type        = string
  default     = "/healthz"
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for the public HTTPS listener. Supply a real ARN at apply; the default is a syntactically valid placeholder so plan/validate pass."
  type        = string
  default     = "arn:aws:acm:ap-southeast-5:000000000000:certificate/PLACEHOLDER"
}

variable "alarm_sns_topic_arn" {
  description = "Optional SNS topic ARN that CloudWatch alarms notify. Empty = create one."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
