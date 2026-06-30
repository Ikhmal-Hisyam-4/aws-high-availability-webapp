variable "region_id" {
  description = "Primary AWS region — Kuala Lumpur."
  type        = string
  default     = "ap-southeast-5"
}

variable "db_master_password" {
  description = "Aurora master password — seeds Secrets Manager. Inject via TF_VAR_db_master_password (CI variable), never commit."
  type        = string
  sensitive   = true
  default     = ""
}
