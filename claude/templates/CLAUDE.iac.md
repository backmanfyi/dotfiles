# <Repo Name> — IaC

## What this repo does
<!-- One paragraph: what infrastructure this manages, what environments exist, who owns it -->

## Stack
- **IaC tool**: Terraform / Terragrunt
- **State backend**: S3 (`<bucket-name>`) + DynamoDB (`<table-name>`)
- **Cloud**: AWS / GCP / Azure
- **Region(s)**: <!-- e.g. eu-west-1, us-east-1 -->
- **Environments**: dev / staging / prod

## Repo structure
```
modules/          # reusable modules
environments/
  dev/
  staging/
  prod/
```

## Naming conventions
- Resources: `<project>-<env>-<resource>` (e.g. `myapp-prod-eks-cluster`)
- Terraform workspaces: not used — separate state per environment directory
- Tags: all resources must have `env`, `team`, `managed-by = terraform`

## Working here

### Plan / Apply workflow
```sh
cd environments/<env>
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### Adding a new resource
1. Check if a module exists in `modules/` before writing inline resources
2. Run `tflint` before committing
3. PR required for staging and prod — no direct applies

### Sensitive values
- Secrets are stored in AWS SSM Parameter Store / Secrets Manager
- Never commit secrets or reference them as plain Terraform variables
- Use `data "aws_ssm_parameter"` to fetch at apply time

## Permissions
- Auto-allow: `terraform plan`, `tflint`, read-only AWS CLI commands (`aws ec2 describe-*`, `aws s3 ls`, etc.)
- Ask before: `terraform apply`, any destructive AWS CLI operation
- Never: direct AWS console changes to managed resources

## Known quirks
<!-- Document anything non-obvious: unusual provider configs, manual steps, known drift, etc. -->
