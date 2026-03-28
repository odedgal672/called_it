# AWS Infrastructure

> Status: decided
> Topic order: 7 of N

---

## Services Used

| AWS Service | Purpose |
|---|---|
| **ECS Fargate** | Run all 4 application containers — no server management |
| **ECR** | Container registry — store Docker images for each service |
| **RDS PostgreSQL** | Managed PostgreSQL — automated backups, patching, failover |
| **Amazon MSK** | Managed Kafka — broker management handled by AWS |
| **ALB** | Application Load Balancer — public entry point, routes to API Gateway service |
| **VPC** | Isolated private network — all resources live inside |
| **NAT Gateway** | Allows Ingestion Worker (private subnet) to reach VLR.gg |
| **CloudWatch** | Logs and metrics for all services |
| **IAM** | Roles and policies for service-to-service permissions |

---

## Network Layout

Single availability zone. Can be extended to multi-AZ when the app moves toward production.

```
Internet
    │
    ▼
Application Load Balancer  (public subnet)
    │  HTTPS traffic only
    ▼
┌─────────────────────────────────────────────┐
│               VPC (private subnet)          │
│                                             │
│   ┌─────────────────┐                       │
│   │  API Gateway    │  ECS Fargate service  │
│   │  (ECS)          │  validates JWT,       │
│   │                 │  routes to App svc    │
│   └────────┬────────┘                       │
│            │                                │
│   ┌────────▼────────┐                       │
│   │  App Service    │  ECS Fargate service  │
│   │  (ECS)          │  HTTP CRUD, auth      │
│   └────────┬────────┘                       │
│            │                                │
│   ┌────────▼────────┐                       │
│   │  RDS PostgreSQL │  managed database     │
│   └─────────────────┘                       │
│                                             │
│   ┌─────────────────┐                       │
│   │  Ingestion      │  ECS Fargate task     │
│   │  Worker (ECS)   │  scheduled polling    │
│   └────────┬────────┘                       │
│            │ (outbound via NAT Gateway)      │
│            ▼                                │
│   ┌─────────────────┐                       │
│   │  Amazon MSK     │  managed Kafka        │
│   │  (Kafka)        │                       │
│   └────────┬────────┘                       │
│            │                                │
│   ┌────────▼────────┐                       │
│   │  Scoring Worker │  ECS Fargate service  │
│   │  (ECS)          │  Kafka consumer       │
│   └─────────────────┘                       │
│                                             │
└─────────────────────────────────────────────┘
         │
         └── NAT Gateway → Internet (Ingestion Worker → VLR.gg)
```

---

## ECS Service Definitions

| Service | Type | Scaling |
|---|---|---|
| API Gateway | ECS Service (always running) | Scale with ALB request count |
| App Service | ECS Service (always running) | Scale with ALB request count |
| Ingestion Worker | ECS Scheduled Task | Fixed single instance; runs on cron |
| Scoring Worker | ECS Service (always running) | Scale with Kafka consumer lag |

The Ingestion Worker runs as a **scheduled ECS task** — ECS starts the container on the defined schedule, it runs its jobs, then stops. Not a long-running service.

The Scoring Worker runs as a **long-running ECS service** — always on, consuming from Kafka continuously.

---

## Security Groups

Security groups act as firewalls. Each resource only accepts traffic from expected sources.

| Resource | Accepts traffic from |
|---|---|
| ALB | Internet (0.0.0.0/0) on port 443 |
| API Gateway (ECS) | ALB only |
| App Service (ECS) | API Gateway only |
| RDS | App Service, Ingestion Worker, Scoring Worker |
| MSK (Kafka) | Ingestion Worker, Scoring Worker |
| Scoring Worker | MSK only (no inbound HTTP) |
| Ingestion Worker | No inbound (outbound only via NAT) |

---

## IAM Roles

Each ECS task has its own IAM role with least-privilege permissions.

| Service | IAM permissions needed |
|---|---|
| API Gateway | None (no AWS service calls) |
| App Service | RDS access (via VPC, no IAM needed), Secrets Manager (DB credentials) |
| Ingestion Worker | MSK produce, Secrets Manager |
| Scoring Worker | MSK consume, Secrets Manager |

DB credentials stored in **AWS Secrets Manager** — never hardcoded or in environment variables in plain text.

---

## Key Design Decisions

| Decision | Choice | Reasoning |
|---|---|---|
| Compute | ECS Fargate | Right fit for 4 services; teaches core AWS without Kubernetes overhead |
| Database | RDS PostgreSQL | Managed, simple, standard — no need for Aurora at this scale |
| Kafka | Amazon MSK | Focus on learning Kafka concepts, not Kafka operations |
| Availability | Single AZ | Cost-effective for learning stage; multi-AZ can be added later |
| Public exposure | ALB only | All services in private subnet; only load balancer is internet-facing |
| Outbound internet | NAT Gateway | Ingestion Worker needs to reach VLR.gg; NAT allows outbound, blocks inbound |
| Secrets | AWS Secrets Manager | DB credentials and API keys never in plaintext config |
