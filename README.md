# AWS Scalable Web Application Infrastructure

Scalable, highly available web application infrastructure on AWS provisioned entirely with Terraform.

Designed for production-grade workloads: traffic is load-balanced across EC2 instances in 3 availability zones, auto-scaled based on CPU metrics, and backed by a private RDS MySQL database. All components are locked down with least-privilege security groups.

---

## Architecture

```
Internet
    │
    ▼
Application Load Balancer (webapp-alb)
  - HTTP :80, public subnets across 3 AZs
  - Health checks: GET /healthz every 30s
    │
    ▼
Auto Scaling Group (webapp-asg)
  - Min: 1 / Desired: 1 / Max: 3
  - EC2 t3.micro (Ubuntu 24.04)
  - Scale up:   CPU > 70% for 2 mins → +1 instance
  - Scale down: CPU < 30% for 2 mins → -1 instance
    │
    ▼
RDS MySQL 8.0 (webapp-db)
  - db.t3.micro, 20 GiB gp2, encrypted
  - Private subnets only — not publicly accessible
  - Accessible only from EC2 security group
```

### VPC Layout

```
VPC: 10.0.0.0/16
├── Public Subnets  (ALB + EC2)
│   ├── 10.0.1.0/24  us-east-1a
│   ├── 10.0.2.0/24  us-east-1b
│   └── 10.0.3.0/24  us-east-1c
└── Private Subnets (RDS)
    ├── 10.0.4.0/24  us-east-1a
    └── 10.0.5.0/24  us-east-1b
```

---

## Infrastructure Components

| Resource | Description |
|---|---|
| `networking.tf` | VPC, subnets, IGW, route tables |
| `security_groups.tf` | ALB, EC2, RDS security groups |
| `alb.tf` | Application Load Balancer, target group, listener |
| `launch_template.tf` | EC2 launch template, IAM instance profile |
| `autoscaling.tf` | ASG, scale-up/down policies, CloudWatch CPU alarms |
| `rds.tf` | RDS MySQL instance, subnet group, parameter group |
| `variables.tf` | Input variables |
| `outputs.tf` | ALB DNS, VPC ID, ASG name |
| `userdata.sh.tpl` | EC2 bootstrap — writes `.env`, starts webapp service |

---

## Security Design

- **ALB** accepts HTTP :80 from `0.0.0.0/0`
- **EC2** accepts HTTP :8080 from ALB security group only — not internet-accessible
- **RDS** accepts MySQL :3306 from EC2 security group only — no public access
- **Storage** encrypted at rest (gp2)
- **IAM** instance profile scoped to LabRole — no hardcoded credentials

---

## Prerequisites

- Terraform >= 1.3.0
- AWS CLI configured with appropriate IAM permissions
- An AMI with your web application pre-installed (see [Web Application](#web-application) below)

---

## Usage

### 1. Clone the repo

```bash
git clone https://github.com/kchimbodza/aws-scalable-webapp-infra
cd aws-scalable-webapp-infra
```

### 2. Configure variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
db_password  = "your-secure-password"
db_username  = "webapp_admin"
db_name      = "webapp_db"
ami_id       = "your-custom-ami-id"
instance_type = "t3.micro"
```

### 3. Deploy

```bash
terraform init
terraform plan
terraform apply
```

### 4. Test

```bash
# Health check
curl http://<alb_dns_name>/healthz

# Create user
curl -s -X POST http://<alb_dns_name>/v1/user \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Password123","first_name":"Test","last_name":"User"}'

# Get user
curl -s http://<alb_dns_name>/v1/user/self \
  -u "test@example.com:Password123"
```

### 5. Destroy

```bash
terraform destroy
```

---

## Web Application

The infrastructure is designed for any web application that:
- Runs on port `8080`
- Exposes `GET /healthz` returning HTTP 200
- Reads DB config from `/usr/bin/csye6225/.env`
- Runs as a systemd service (`webapp.service`)

A custom Go web application with `POST /v1/user` and `GET /v1/user/self` endpoints backed by RDS MySQL was used during development and load testing.

---

## Auto Scaling in Action

CloudWatch CPU alarms drive scaling:

| Alarm | Condition | Action |
|---|---|---|
| `webapp-cpu-high` | CPU > 70% for 2 consecutive minutes | Scale up: +1 instance, 60s cooldown |
| `webapp-cpu-low` | CPU < 30% for 2 consecutive minutes | Scale down: -1 instance, 120s cooldown |

During load testing, CPU peaked at 75.6% triggering a scale-up from 1 → 2 instances. Once load dropped, the scale-down alarm fired and capacity returned to 1.

---

## Tech Stack

| Layer | Technology |
|---|---|
| IaC | Terraform >= 1.3 |
| Cloud | AWS (us-east-1) |
| Compute | EC2 t3.micro, Auto Scaling Group |
| Load Balancing | Application Load Balancer |
| Database | RDS MySQL 8.0 |
| Monitoring | CloudWatch CPU alarms |
| Networking | VPC, public/private subnets, IGW |
| Security | IAM, security groups, encrypted storage |

---

## License

MIT
