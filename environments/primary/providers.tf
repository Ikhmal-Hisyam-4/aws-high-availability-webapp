# Single AWS provider pinned to the primary region. Credentials come from
# AWS_* env vars (CI-injected, scoped IAM creds), never hardcoded.
provider "aws" {
  region = var.region_id

  default_tags {
    tags = {
      Project   = "nexus-global-systems"
      ManagedBy = "terraform"
    }
  }
}
