# Remote state in S3 + DynamoDB lock table (created by bootstrap/). The bucket
# name is injected by CI via -backend-config; hardcoded here so local init works.
terraform {
  backend "s3" {
    bucket         = "nexus-aws-tfstate-primary" # created via bootstrap/
    key            = "primary/terraform.tfstate"
    region         = "ap-southeast-5"
    encrypt        = true
    dynamodb_table = "nexus-aws-tflock" # state locking
  }
}
