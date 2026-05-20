# finpay-infrastructure

Terraform configuration for the FinPay API AWS infrastructure.
Deploy the complete stack to any region in under 20 minutes.

## What this provisions

| Resource | Type | Description |
|---|---|---|
| ECR | Container registry | Stores Docker images with vulnerability scanning |
| RDS | db.t3.micro PostgreSQL 15 | Private database — only reachable from EB |
| Elastic Beanstalk | t3.micro · Docker | Runs the Node.js API + React frontend |
| CodeBuild | build.general1.small | Builds Docker image, runs lint, pushes to ECR |
| CodePipeline | V2 · QUEUED | GitHub → CodeBuild → EB — triggers on push |
| S3 | Pipeline artifacts | Stores build artifacts between stages |
| IAM | 4 roles | Least privilege access for each service |
| Security Groups | 2 groups | EB (HTTP/3000) and RDS (PostgreSQL from EB only) |

## Prerequisites

1. AWS CLI configured: `aws configure`
2. Terraform installed: `terraform --version` (>= 1.5.0)
3. GitHub connection created in AWS Console:
   - CodePipeline → Settings → Connections → Create connection → GitHub
   - Copy the ARN into terraform.tfvars

## First-time setup

```bash
# Clone the repo
git clone https://github.com/devopschroniclesGit/finpay-infrastructure
cd finpay-infrastructure

# Copy and fill in secrets
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars  # fill in all values

# Initialise Terraform
terraform init

# Preview what will be created
terraform plan

# Deploy everything
terraform apply
```

## Deploying to a different region

Change one line in `terraform.tfvars`:

```hcl
aws_region = "us-east-1"  # or ap-southeast-1, eu-west-1, etc.
```

Then:

```bash
terraform apply
```

All 8 resources recreate in the new region automatically.
No clicking. No forgetting steps. No wrong passwords in the wrong field.

## After apply

Terraform prints:

```
eb_environment_url  = "http://finpay-production.XXXX.elasticbeanstalk.com"
ecr_repository_url  = "ACCOUNT.dkr.ecr.REGION.amazonaws.com/finpay-api"
health_check_url    = "http://finpay-production.XXXX.elasticbeanstalk.com/api/v1/health"
swagger_url         = "http://finpay-production.XXXX.elasticbeanstalk.com/api/docs"
```

Run the database migrations manually once after first deploy:

```bash
DATABASE_URL='postgresql://...' npx prisma@5 migrate deploy
DATABASE_URL='postgresql://...' node prisma/seed.cjs
```

## Teardown

```bash
terraform destroy
```

Deletes everything. RDS, ECR images, EB environment — all gone.

## File structure

```
finpay-infrastructure/
├── main.tf                   # Provider, backend, data sources
├── variables.tf              # All input variables
├── ecr.tf                    # ECR repository + lifecycle policy
├── iam.tf                    # 4 IAM roles + policies
├── security_groups.tf        # EB and RDS security groups
├── rds.tf                    # PostgreSQL instance
├── elastic_beanstalk.tf      # EB app + environment + env vars
├── codepipeline.tf           # S3 + CodeBuild + CodePipeline
├── outputs.tf                # Printed values after apply
├── terraform.tfvars.example  # Template — copy to terraform.tfvars
└── .gitignore                # Excludes tfstate and tfvars
```
