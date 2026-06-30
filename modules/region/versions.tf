# Region module provider requirements. The AWS provider itself (region, creds) is
# configured by the CALLER (environments/primary), not here — so the same module
# can be pointed at any region.
terraform {
  required_version = ">= 1.5.0, < 2.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
