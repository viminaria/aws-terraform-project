# k3s Cluster on AWS

Self-managed Kubernetes cluster provisioned via Terraform for learning DevOps/SRE/cloud engineering skills during an AWS trial period.

## What's deployed

- **NGINX reverse proxy** (`t4g.micro`) — SSH jump host + HTTP/HTTPS/TCP stream proxy to the cluster
- **k3s control plane** (`t4g.small`) — etcd, API server, kubelet
- **k3s worker node** (`t4g.micro`) — runs application workloads via NodePort services
- **Networking** — VPC with public/private subnets, NAT Gateway, security groups
- **Services** — DynamoDB tables + S3 bucket for application data

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full technical breakdown.

## Quick start

### Prerequisites

1. [AWS CLI installed and configured](PREREQUISITES.md#1-aws-cli-installed)
2. An AWS IAM user with programmatic access (see [PREREQUISITES.md](PREREQUISITES.md))
3. Terraform >= 1.5.0
4. SSH key pair: `ssh-keygen -t ed25519 -f ~/.ssh/k3s-cluster -N ""`

### Deploy

```bash
cd ~/aws-terraform-project

# Create tfvars with your SSH public key and region
cat > terraform.tfvars <<EOF
aws_region       = "eu-central-1"
project_name     = "k3s-cluster"
ssh_public_key   = "$(cat ~/.ssh/k3s-cluster.pub)"

# Cloudflare DNS (optional, leave empty for manual)
cloudflare_api_token = ""
cloudflare_zone_id   = ""
EOF

# First apply: creates S3 state bucket + DynamoDB lock table
terraform init
terraform apply

# Migrate to S3 backend (uncomment the backend block in backend.tf first)
# terraform init -migrate-state

# Join the worker node to the cluster
./compute/scripts/join-k3s-worker.sh $(terraform output -raw nginx_public_ip) ~/.ssh/k3s-cluster
```

### Verify

```bash
# SSH through NGINX to the control plane
ssh ubuntu@<nginx-public-ip> -i ~/.ssh/k3s-cluster.pem

# From the control plane, check cluster status
sudo kubectl get nodes
```

## Key terraform commands

| Command | Purpose |
|---|---|
| `terraform init` | Initialize working directory |
| `terraform apply` | Create/update infrastructure |
| `terraform plan` | Preview changes |
| `terraform output -raw nginx_public_ip` | Get NGINX public IP for SSH/proxy access |
| `terraform taint aws_instance.nginx` | Force re-creation of a specific resource |
| `terraform destroy` | Tear down all provisioned resources |

## Cost

~$50/month with NAT Gateway running. Stop NGINX and NAT Gateway when idle to save ~$43/mo.

## Structure

```
networking/   VPC, subnets, IGW, NAT GW, route tables
iam/          IAM roles, policies, instance profile
compute/      EC2 instances (control plane, worker, NGINX) + bootstrapping scripts
services/     DynamoDB tables, S3 bucket
dns/          Optional Cloudflare DNS management
staging/      Separate environment for testing changes
k8s/          Kubernetes manifests (deployments, services)
```

## Further reading

- [PREREQUISITES.md](PREREQUISITES.md) — Full setup guide with IAM policy details and cost estimates
- [ARCHITECTURE.md](ARCHITECTURE.md) — Complete architecture documentation with security groups, traffic flows, and AWS Well-Architected alignment
