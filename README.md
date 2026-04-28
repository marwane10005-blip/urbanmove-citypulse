# UrbanMove — Cloud Native Smart Mobility Platform

Final project for *Big Data & Cloud Computing* (EPITA, S25). Dr. Badre Bousalem.

A cloud-native platform for ingesting real-time mobility telemetry from a connected
fleet, detecting congestion, surfacing live operations dashboards, and serving ML-backed
ETA predictions. Deployed on AWS in `eu-west-3` (Paris).

## Team

- Marwane Mhenni
- Farouk Rahal
- Ali Cherri
- Georges Ebaidallah

## Architecture at a glance

| Concern | Implementation |
|---|---|
| Device ingestion | AWS IoT Core (MQTT, cert auth) => IoT Rule => Kinesis Data Streams |
| Stream processing | Python consumers on EKS, writing to Aurora (hot) + S3 (cold) |
| Storage | Aurora PostgreSQL + PostGIS (OLTP), S3 data lake (analytics), ElastiCache Redis (cache) |
| Compute | Amazon EKS multi-AZ, 5 microservices behind ALB Ingress |
| Auth | Amazon Cognito (users), IoT cert auth (devices) |
| ML | SageMaker training + endpoint, orchestrated by Step Functions + EventBridge (daily) |
| Edge | CloudFront + AWS WAF + ACM certificates |
| Observability | CloudWatch (metrics, logs, dashboards, alarms) + X-Ray (distributed tracing) |
| Security | KMS CMKs, Secrets Manager, GuardDuty, Security Hub, IAM least-privilege |
| IaC | Terraform (root + reusable modules) |
| CI/CD | GitHub Actions => ECR + `kubectl apply` via OIDC |


## Repository layout

```
urbanmove-citypulse/
├── infra/terraform/        # AWS infrastructure as code
│   ├── envs/               # tfvars per environment
│   └── modules/            # reusable modules (network, eks, aurora, kinesis, ...)
├── apps/
│   ├── simulator/          # IoT fleet simulator (Python)
│   ├── mobility-api/       # vehicle + trip API (FastAPI)
│   ├── identity-fleet/     # auth + fleet administration (FastAPI)
│   ├── analytics-dashboard/# dashboard backend + WebSocket (FastAPI)
│   ├── stream-processor/   # Kinesis consumer (Python)
│   ├── ml-training/        # SageMaker training container
│   └── dashboard-web/      # Next.js operator dashboard
├── deploy/helm/            # Helm charts for EKS workloads
├── .github/workflows/      # CI/CD pipelines
├── loadtest/k6/            # load + scale-out test scripts
└── scripts/                # helper scripts
```

## Quick start

Prerequisites: AWS CLI, Terraform ≥ 1.7, Docker, kubectl, Helm, an AWS account
configured for `eu-west-3` with the team OIDC role.

```bash
make init       # terraform init, kubeconfig, ECR login
make up         # bring up the dev environment
make demo       # full multi-AZ + SageMaker + seed simulator
make down       # tear down expensive resources (keeps VPC, ECR, S3)
make destroy    # nuke everything (run after the final session)
```


