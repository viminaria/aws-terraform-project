# Architecture — k3s Cluster on AWS

This document describes the infrastructure, networking, compute, and service layers of the self-managed k3s cluster deployed on AWS via Terraform. It also maps design decisions to the [AWS Well-Architected Framework](https://docs.aws.amazon.com/wellarchitected/latest/framework/welcome.html).

---

## Architecture Diagram

```
Internet
  │
  ▼
┌───────────────────────┐
│  NGINX LB (t4g.micro)  │ Public subnet 10.0.1.0/24
│  :80 → :443 redirect   │
│  :443 → HTTPS proxy    │
│  :6443 → TCP stream    │
│  SSH:22                │
└──────────┬─────────────┘
           │
     ┌─────┴──────┐
     ▼            ▼
┌──────────┐ ┌──────────┐
│ Control   │ │ Worker    │ Private subnet 10.0.2.0/24
│ Plane     │ │ Node      │ No public IPs
│ (t4g.small)│ │(t4g.micro)│
│ k3s server│ │ k3s agent │
│ etcd:2379 │ │ NodePort  │
│ kubelet   │ │ :30000-   │
└──────────┘ │ :32767    │
             └─────┬──────┘
                   │
        NAT Gateway (outbound only)
        k3s image pulls, apt updates
```

### Traffic flows

| Traffic | Path |
|---|---|
| k8s API server | Internet → NGINX:6443 (stream proxy) → CP:6443 |
| NodePort services | Internet → NGINX:443 → upstream to worker or control plane NodePorts |
| Go API service | Internet → NGINX:443/api/ → k3s worker CP/control plane:31080 |
| SSH access | `ssh ubuntu@<nginx-public-ip> -i key.pem` then jump via nginx |

---

## Networking Layer

### VPC — `10.0.0.0/16`

Single VPC with DNS support and hostnames enabled. All resources reside in a single Availability Zone (`eu-central-1`).

### Subnets

| Subnet | CIDR | Tier | Purpose |
|---|---|---|---|
| `public` | `10.0.1.0/24` | Public | NGINX load balancer — has public IP, accessible from internet |
| `private` | `10.0.2.0/24` | Private | k3s control plane and worker nodes — no public IPs |

### Route Tables

- **Public route table**: Default route (`0.0.0.0/0`) → Internet Gateway
- **Private route table**: Default route (`0.0.0.0/0`) → NAT Gateway

### NAT Gateway

Placed in the public subnet, associated with an Elastic IP. Provides outbound internet access for the private subnet (k3s image pulls, `apt update`). No inbound internet access to private instances.

---

## Compute Layer

### EC2 Instances — Ubuntu 24.04 Noble (x86_64)

| Instance | Type | vCPU/RAM | Subnet | Role |
|---|---|---|---|---|
| `control-plane` | `t4g.small` | 2 / 2 GB | Private | k3s server, etcd, kubelet API |
| `worker` | `t4g.micro` | 2 / 1 GB | Private | k3s agent, NodePort services |
| `nginx` | `t4g.micro` | 2 / 1 GB | Public | Reverse proxy (HTTP/HTTPS/TCP stream), SSH jump host |

All instances share:
- **AMI**: Ubuntu 24.04 LTS (x86_64 HVM) — Canonical account `099720109477`
- **Root volume**: 20 GB gp3, encrypted
- **IAM instance profile**: `k3s-cluster-node-role` — DynamoDB + S3 access via least-privilege policies
- **SSH key pair**: `k3s-cluster-key`

### Bootstrapping (user_data)

Each instance runs a shell script on first boot:

1. **Control plane** (`control_plane.sh`): Creates 1 GB swap, installs k3s server with traefik disabled and cluster initialization enabled
2. **Worker** (`worker.sh`): Creates 1 GB swap, installs k3s agent (does not auto-join — manual join via `join-k3s-worker.sh`)
3. **NGINX** (`nginx.sh`): Installs NGINX, generates self-signed TLS cert, configures stream and HTTP/HTTPS reverse proxy with upstream routing to control plane and worker NodePorts

### Security Groups

| SG | Inbound Rules | Outbound |
|---|---|---|
| `nginx-sg` | TCP 80, 443 from `0.0.0.0/0`; TCP 6443 from private subnet; SSH from `0.0.0.0/0` | All → `0.0.0.0/0` |
| `k3s-cp-sg` | TCP 6443 from public+private subnets; TCP 10250 from private; TCP 2379-2380 self | All → `0.0.0.0/0` |
| `k3s-worker-sg` | TCP 10250 from private; NodePort 30000-32767 from public+private subnets | All → `0.0.0.0/0` |

---

## IAM Layer

### Role: `k3s-cluster-node-role`

Assumed by EC2 service, attached with two scoped policies:

| Policy | Permissions | Resource Scope |
|---|---|---|
| `k3s-cluster-node-dynamodb` | Full CRUD + Query/Scan/Batch ops on DynamoDB | Specific tables: `k3s-cluster-app-data`, `k3s-cluster-go-api-items` |
| `k3s-cluster-node-s3` | GetObject, PutObject, DeleteObject, ListBucket | Specific bucket: `k3s-cluster-app-storage` and all keys within it |

No wildcard resources — least-privilege applied at the table/bucket level.

---

## Services Layer

### DynamoDB Tables

| Table | Billing | Hash Key | Features |
|---|---|---|---|
| `k3s-cluster-app-data` | PAY_PER_REQUEST | `pk` (S) | Point-in-time recovery, SSE enabled |
| `k3s-cluster-go-api-items` | PAY_PER_REQUEST | `id` (S) | Point-in-time recovery, SSE enabled |

### S3 Bucket

Named `k3s-cluster-app-storage`, created dynamically with a random suffix in `backend.tf` for Terraform state. The application uses `k3s-cluster-app-storage`. Both are encrypted by default (S3 managed keys).

### Terraform State

- **Backend**: S3 bucket (created on first apply) + DynamoDB `k3s-cluster-tf-lock` for state locking
- **Encryption**: Enabled via `encrypt = true` in the backend config

---

## Module Structure

```
aws-terraform-project/
├── main.tf                    ← Orchestrate modules, pass variables
├── variables.tf               ← Root-level inputs
├── outputs.tf                 ← Root-level outputs (IPs, DNS, resource ARNs)
├── providers.tf               ← Terraform + AWS provider config
├── backend.tf                 ← S3 state + DynamoDB lock (commented until first apply)
│
├── networking/                ← VPC, subnets, IGW, NAT GW, route tables
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
│
├── iam/                       ← IAM role, policies, instance profile
│   ├── main.tf
│   ├── policies.tf            ← DynamoDB + S3 scoped policies
│   ├── variables.tf
│   └── outputs.tf
│
├── compute/                   ← 3 EC2 instances + security groups
│   ├── main.tf                ← Control plane, worker, NGINX instances
│   ├── security_groups.tf     ← nginx, k3s-cp, k3s-worker SGs
│   ├── key_pair.tf            ← SSH key pair resource
│   ├── variables.tf
│   └── scripts/               ← user_data bootstrapping scripts
│       ├── control_plane.sh
│       ├── worker.sh
│       └── nginx.sh
│
├── services/                  ← DynamoDB tables + S3 bucket
│   ├── main.tf
│   ├── s3.tf
│   ├── ecr.tf
│   ├── variables.tf
│   └── outputs.tf
│
├── dns/                       ← Optional Cloudflare DNS management
│   ├── main.tf
│   └── variables.tf
│
└── staging/                   ← Separate environment/workspace for testing changes
    └── (mirrors project structure)
```

---

## Apply Order

Terraform resolves dependencies automatically, but the logical order is:

1. **`backend.tf`** — S3 bucket + DynamoDB lock created first (then uncomment and migrate to S3 backend)
2. **`iam/`** — Roles and policies
3. **`networking/`** — VPC, subnets, IGW, NAT GW, route tables
4. **`compute/`** — Control plane → Worker → NGINX (dependency-ordered via `depends_on`)
5. **`services/`** — DynamoDB tables, S3 bucket

---

## Post-Deploy: Joining the Worker

After initial `terraform apply`, the control plane starts automatically but the worker must be joined manually:

```bash
cd ~/aws-terraform-project
./compute/scripts/join-k3s-worker.sh $(terraform output -raw nginx_public_ip) ~/.ssh/k3s-cluster
```

The script SSHes through NGINX, fetches the k3s join token from the control plane, then joins the worker.

---

## Cost Breakdown

| Resource | Monthly Cost (approx) |
|---|---|
| EC2 × 3 (`t4g.small`, `t4g.micro` × 2) | ~$28 |
| EBS gp3 × 3 (20 GB each) | Included in EC2 pricing range |
| NAT Gateway | ~$35 fixed + data processing |
| DynamoDB (PAY_PER_REQUEST × 2 tables) | ~$1-2 |
| S3 bucket | Cents, depends on usage |
| **Total** | **~$50/month** |

Save by stopping the NAT Gateway and NGINX instance when not in use. Use `terraform taint` for selective restart or `terraform destroy` for full teardown.

---

## AWS Well-Architected Framework Alignment

### [Operational Excellence]
- **IaC throughout**: Entire infrastructure managed via Terraform modules — reproducible, version-controlled deployments
- **Automated bootstrapping**: k3s and NGINX install via user_data scripts with `set -euo pipefail`
- **Documented procedures**: `PREREQUISITES.md` and `ARCHITECTURE.md` for post-deploy steps
- **Staging environment**: Separate workspace (`staging/`) for testing changes before applying to the main cluster

### [Security]
- **Least-privilege IAM**: Instance profile scoped to specific DynamoDB tables and S3 bucket — no wildcard resources
- **Network isolation**: k3s nodes in private subnet with no public IPs; NAT Gateway provides outbound-only access
- **Security group hardening**: Each SG restricts ingress to only the ports and CIDR blocks it needs
  - Control plane etcd (2379-2380) restricted to `self` only
  - k3s API port 6443 limited to public+private subnets (not 0.0.0.0/0)
  - NodePort range only accessible from known subnets
- **Encrypted volumes**: All EBS root volumes use gp3 with encryption enabled
- **Shared responsibility**: EC2 instances are in private subnets, reducing attack surface

### [Reliability]
- **Single Availability Zone**: Known limitation — all resources deployed to one AZ. Multi-AZ is out of scope but noted as a future improvement path
- **EBS gp3 volumes**: Independent from instance lifecycle; encrypted for data protection
- **DynamoDB PITR + SSE**: Application data tables have point-in-time recovery and server-side encryption enabled
- **No single points of failure (known)**: Single control plane node, single NAT Gateway, single NGINX — documented as trade-offs

### [Performance Efficiency]
- **Graviton2 instances (t4g.*)**: ARM64-based instances providing better price-performance than comparable x86
- **Right-sized workloads**: `t4g.micro` for NGINX/worker, `t4g.small` for control plane — minimum viable sizing for k3s with 1 GB swap
- **NAT Gateway over multiple NAT Instances**: Managed service eliminates operational overhead and scales automatically

### [Cost Optimization]
- **NAT Gateway stop/start**: ~$35/month fixed cost is the largest expense; can be stopped when cluster is idle
- **PAY_PER_REQUEST DynamoDB**: No provisioned capacity waste — pay only for reads/writes used
- **gp3 volumes**: Cheaper than gp2, independent throughput scaling
- **t4g instances**: Up to 18% better price-performance vs t3 equivalents
- **Destructible infrastructure**: `terraform destroy` enables full teardown when the AWS trial period ends

### [Sustainability]
- **Instance shutdown capability**: NAT Gateway and NGINX can be stopped when not in use, reducing energy consumption
- **Graviton2 efficiency**: ARM64 instances deliver more performance per watt than x86 alternatives
- **Resource right-sizing**: Minimal instance types matched to workload requirements — no over-provisioning

---

## Design Trade-offs (Known Limitations)

| Decision | Rationale | Future improvement |
|---|---|---|
| Single AZ | Simplicity, cost (~$50/mo target) | Add multi-AZ subnets + second control plane node |
| No ALB/NLB for Ingress | Learning project scope, NodePort sufficient initially | AWS NLB or k8s Ingress controller with cert-manager |
| Self-signed TLS on NGINX | Learning purposes, no public trust needed | acm-cert via Route53/Cloudflare for valid certificates |
| Single control plane node | Cost constraint — etcd needs odd number ≥ 3 for HA | Add additional CP nodes to a second AZ |
| x86_64 AMI (not ARM) | k3s compatibility testing on x86 first | Switch to `arm64` AMI filter matching t4g instances |
