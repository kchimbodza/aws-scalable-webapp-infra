# AWS Scalable Web Application Infrastructure

Scalable, highly available web application infrastructure on AWS provisioned entirely with Terraform.

Traffic is load-balanced across EC2 instances in 3 availability zones, auto-scaled on CPU, and backed by a private RDS MySQL database. Each layer only accepts traffic from the layer in front of it (security group to security group).

**Key results**

- In a load test, CPU peaked at **75.6%**, the high-CPU alarm scaled the group **1 → 2 instances**, and it went back to 1 when the load dropped.
- `terraform validate`: **passes** (re-run 13 Nov 2026, see [Results](#results)).

---

## Architecture

<p align="center"><img src="docs/architecture.svg" width="100%" alt="Internet users reach an Application Load Balancer on HTTP port 80 in three public subnets of VPC 10.0.0.0/16 in us-east-1. It forwards to port 8080 on EC2 t3.micro instances in an Auto Scaling Group of 1 to 3, health-checked on GET /healthz every 30 seconds. The instances use an RDS MySQL 8.0 db.t3.micro database on port 3306 in two private subnets, encrypted, single-AZ and not public. CloudWatch alarms add an instance above 70 percent CPU for 2 minutes and remove one below 30 percent. Security groups chain internet to ALB :80 to EC2 :8080 to RDS :3306. Terraform creates it all; user data writes DB settings to .env and starts webapp.service."></p>

**Why this architecture**

| Choice | Why |
|---|---|
| Everything in Terraform | One `apply` builds the whole stack and one `destroy` removes it, so nothing is left running by accident. |
| ALB + Auto Scaling Group over 3 AZs | One instance or one AZ failing does not take the app down; with `health_check_type = "ELB"` the ASG replaces instances that fail `/healthz`. |
| Two CPU alarms with simple ±1 policies | Easy to reason about and to test: crossing 70% for 2 minutes adds exactly one instance. |
| RDS in private subnets, security group to security group | The database has no public address; only the EC2 group reaches 3306 and only the ALB reaches 8080. |
| Pre-built AMI + user data that writes `.env` | New instances from the ASG boot ready; only the DB endpoint and credentials are injected at launch. |
| EC2 in public subnets with public IPs | No NAT gateway is needed for outbound traffic; port 8080 is still closed to everything except the ALB. |

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

## Auto Scaling in Action

CloudWatch CPU alarms drive scaling:

| Alarm | Condition | Action |
|---|---|---|
| `webapp-cpu-high` | CPU > 70% for 2 consecutive minutes | Scale up: +1 instance, 60s cooldown |
| `webapp-cpu-low` | CPU < 30% for 2 consecutive minutes | Scale down: -1 instance, 120s cooldown |

During load testing, CPU peaked at 75.6% triggering a scale-up from 1 → 2 instances. Once load dropped, the scale-down alarm fired and capacity returned to 1.

---

## Results

| Check | Result | Source |
|---|---|---|
| Load test on AWS | CPU peaked at 75.6%, scale-up 1 → 2 instances, then back to 1 | My load-test run during development (no logs or screenshots are saved in this repo) |
| `terraform validate` | **Success! The configuration is valid.** | Re-run 13 Nov 2026: Terraform 1.14.0, AWS provider 5.100.0, `terraform init -backend=false` (no AWS credentials, nothing created) |
| `terraform fmt -check` | Fails on `rds.tf` and `variables.tf` (alignment of `=` only, no logic change) | Same run |
| Automated tests / CI | None yet | – |

## What worked and what didn't

| | What | Detail |
|---|---|---|
| ✅ | Autoscaling under load | The high-CPU alarm added an instance at 75.6% CPU and the low-CPU alarm removed it afterwards. |
| ✅ | Locked-down layers | EC2 is only reachable from the ALB and RDS only from EC2; RDS has `publicly_accessible = false`. |
| ⚠️ | DB password in user data | The password is rendered into the launch template's user data (and the Terraform state), so anyone who can read the launch template can read it. Secrets Manager or SSM Parameter Store would avoid that. |
| ⚠️ | Lab settings on RDS | Single-AZ, `backup_retention_period = 0`, `skip_final_snapshot = true`, `deletion_protection = false`. Fine for a lab, not for real data. |
| ⚠️ | No encryption in transit | ALB listens on HTTP only, and the MySQL parameter group sets `require_secure_transport = 0`. |
| ⚠️ | Account-specific inputs | Needs an existing IAM role named `LabRole` and a custom AMI with the app baked in; region and AZs are hard-coded to us-east-1. |
| ⚠️ | Local state only | No remote backend or state locking is configured. |
| ❌ | Formatting | `terraform fmt -check` fails on two files (whitespace only). |

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
