# Terraform root

## Bootstrap (one-time per AWS account)

Remote state lives in S3 with versioning and KMS encryption, with a native
S3 lock file (Terraform ≥ 1.10). Create the bucket manually before first
`terraform init`:

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws s3api create-bucket \
  --bucket urbanmove-tfstate-$ACCOUNT_ID \
  --region eu-west-3 \
  --create-bucket-configuration LocationConstraint=eu-west-3
aws s3api put-bucket-versioning \
  --bucket urbanmove-tfstate-$ACCOUNT_ID \
  --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption \
  --bucket urbanmove-tfstate-$ACCOUNT_ID \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
```

Then edit `envs/dev.backend.hcl` to substitute the account ID and run:

```bash
terraform init -backend-config=envs/dev.backend.hcl
```

## Daily usage

From the repo root:

```bash
make plan         # terraform plan against dev.tfvars
make up           # brings up dev environment (single-AZ NAT)
make down         # tears down expensive resources
make demo         # full multi-AZ + SageMaker, presentation day
```

## Module map

| Module | Status | Purpose |
|---|---|---|
| `modules/network` | implemented | VPC with public + private subnets, IGW, NAT, route tables, S3 endpoint |
| `modules/ecr` | stub | Per-service container registries |
| `modules/s3-lake` | stub | Data lake bucket, KMS CMK, lifecycle rules |
| `modules/kinesis` | stub | Kinesis Data Stream + Firehose → S3 |
| `modules/iot` | stub | IoT Core policy, Thing type, IoT Rule → Kinesis |
| `modules/aurora` | stub | Aurora PostgreSQL cluster (primary + read replica) |
| `modules/cognito` | stub | Cognito user pool, app client, groups |
| `modules/eks` | stub | EKS cluster, node groups, add-ons, ALB controller |
| `modules/sagemaker` | stub | Training job role, Step Functions, Glue job |
| `modules/observability` | stub | CloudWatch dashboards, alarms, SNS |
| `modules/secrets` | stub | Secrets Manager entries + rotation |

Modules marked "stub" have a valid `main.tf`/`variables.tf`/`outputs.tf`
skeleton so `terraform validate` passes, but contain no resources yet.
Implement in dependency order: `ecr` + `s3-lake` first, then `kinesis`,
`iot`, `aurora`, `cognito`, `eks`, `secrets`, `observability`, `sagemaker`.
