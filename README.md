# AWS High-Availability Infrastructure (Terraform)

Production-style **Terraform** for a **single-region, multi-AZ high-availability**
web stack on AWS in **Kuala Lumpur (`ap-southeast-5`)** — deployed through a
**GitLab CI/CD pipeline** with remote state, state locking, and a gated apply.

**Stack:** VPC · EC2 Auto Scaling · Application Load Balancers · Aurora MySQL
(Multi-AZ) · KMS · Secrets Manager · Route 53 · CloudWatch · Terraform · GitLab CI

> **Design note — DR-constrained:** AWS has no region in Johor, so this build
> delivers resilience **within one region across 3 Availability Zones**. If any
> AZ fails, the load balancers and Auto Scaling keep the app serving, and Aurora
> auto-fails-over the database to a healthy AZ in under a minute. A second-region
> warm standby is a documented future add-on (see [Roadmap](#roadmap)).

## Architecture

![Architecture](architecture-diagram/nexus-aws-architecture.png)

**Request flow:** Users → **Route 53** (DNS + health checks) → **public ALB** →
**FE** EC2 (Auto Scaling across 3 AZs) → **internal ALB** → **BE** EC2 (Auto
Scaling across 3 AZs) → **Aurora MySQL**.

| Layer | What it does |
|---|---|
| **Route 53** | DNS entry point; health-checks the public ALB endpoint. |
| **Public ALB** | Internet-facing; spreads traffic to FE instances across all 3 AZs. |
| **EC2 + Auto Scaling** | Stateless FE and BE tiers; each ASG self-heals and spans 3 AZs. |
| **Internal ALB** | Private; routes FE → BE traffic inside the VPC. |
| **Aurora MySQL** | 1 writer + 2 in-AZ readers on one storage volume 6-way replicated across 3 AZs; auto-failover to a reader on AZ/instance loss (typically < 60s). |
| **NAT gateway** | Outbound-only internet for private subnets. |
| **CloudWatch** | Alarms on EC2 CPU, Aurora replica lag, ALB target health, Route 53 checks. |

## Highlights

- **One reusable module, data-driven.** All infrastructure lives in
  `modules/region/` — it contains no region/AZ/CIDR literals. The environment
  folder only supplies data, so adding a DR region is a copy of the *data*, not
  the code.
- **Real pipeline, gated apply.** `validate` runs free on every commit; `plan`
  runs against a real AWS account (proving the code applies); `apply` is a
  manual, human-approved step so nothing is built by accident.
- **Verified.** `terraform plan` runs clean against live AWS — **59 resources,
  0 errors** — using an S3 remote-state backend with DynamoDB state locking.

## Repo layout

```
bootstrap/              S3 state bucket + DynamoDB lock table (local backend)
modules/region/         ONE reusable module (network, security, alb, compute, rds, monitor)
environments/primary/   KL ap-southeast-5 — calls the module (active)
.gitlab-ci.yml          validate (free) -> plan -> apply (manual, gated)
```

## Security

- **Tiered security groups** — `internet → ALB → FE → BE → DB`; each tier only
  accepts traffic from the tier in front of it.
- **Encryption at rest** — a regional KMS CMK encrypts EBS volumes, Aurora
  storage, and the Secrets Manager secret.
- **No plaintext secrets** — the DB password is injected once via a CI variable
  into Secrets Manager and read from there; it is never a plain Terraform value.
- **TLS in transit** — HTTPS on the public ALB, TLS on the Aurora endpoint.

## How to run

```bash
# 1. One-time: create the remote-state backend (S3 + DynamoDB lock)
cd bootstrap && terraform init && terraform apply

# 2. Deploy the region
cd ../environments/primary
terraform init -backend-config="bucket=nexus-aws-tfstate-primary"
terraform plan
terraform apply
```

Supply the DB password via `TF_VAR_db_master_password` (CI variable) or a local
`secret.auto.tfvars` (gitignored). See `secret.auto.tfvars.example`.

## Roadmap

- **Second-region warm standby** — a sibling `environments/dr/` calling the same
  module, plus a `global/` layer for Route 53 failover routing and Aurora Global
  Database (cross-region replication).
- Swap the placeholder ACM certificate ARN (`var.acm_certificate_arn`) for a real
  certificate before a live apply.

## Notes

This repository is a portfolio / assessment project. The Terraform is validated
and plans cleanly against a real AWS account; a full `apply` is intentionally
gated (it provisions billable resources).
