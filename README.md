# k3s Cluster on AWS

Self-managed Kubernetes cluster provisioned via Terraform for learning DevOps/SRE/cloud engineering skills during an AWS trial period.

## What's deployed

- **NGINX reverse proxy** (`t4g.micro`) — SSH jump host + HTTP/HTTPS/TCP stream proxy to the cluster
- **k3s control plane** (`t4g.small`) — etcd, API server, kubelet (with Traefik ingress controller)
- **k3s worker node** (`t4g.micro`) — runs application workloads via NodePort services
- **Networking** — VPC with public/private subnets, NAT Gateway, security groups
- **Services** — DynamoDB tables + S3 bucket for application data
- **Let's Encrypt TLS** — cert-manager provisions real certificates via Cloudflare DNS-01 challenge
- **DNS management** — Cloudflare A records for infrastructure subdomains and ingress hosts

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full technical breakdown.

## Quick start

### Prerequisites

1. [AWS CLI installed and configured](PREREQUISITES.md#1-aws-cli-installed)
2. An AWS IAM user with programmatic access (see [PREREQUISITES.md](PREREQUISITES.md))
3. Terraform >= 1.5.0
4. SSH key pair: `ssh-keygen -t ed25519 -f ~/.ssh/k3s-cluster -N ""`
5. Cloudflare account with a domain (for automatic DNS + Let's Encrypt certificates — optional, leave empty for manual)

### Deploy infrastructure

```bash
cd ~/aws-terraform-project

# Create tfvars with your SSH public key and region
cat > terraform.tfvars <<EOF
aws_region       = "eu-central-1"
project_name     = "k3s-cluster"
ssh_public_key   = "$(cat ~/.ssh/k3s-cluster.pub)"

# Cloudflare DNS + Let's Encrypt (optional, leave empty for manual)
cloudflare_api_token = ""
cloudflare_zone_id   = ""
dns_zone             = ""
cp_subdomain         = "cp"
worker_subdomain     = "k8s"
nginx_subdomain      = "nginx"
ingress_subdomains   = { go-api = "go-api" }
EOF

# First apply: creates S3 state bucket + DynamoDB lock table
terraform init
terraform apply

# Migrate to S3 backend (uncomment the backend block in backend.tf first)
# terraform init -migrate-state

# Join the worker node to the cluster
./compute/scripts/join-k3s-worker.sh $(terraform output -raw nginx_public_ip) ~/.ssh/k3s-cluster
```

### Deploy K8s resources

After joining the worker, deploy Go API and Ingress via CI or locally:

**Via CI (recommended):**
```bash
# Set up GitHub secrets first:
./scripts/update-github-secrets.sh $(terraform output -raw nginx_public_ip) \
  $(terraform output -raw control_plane_private_ip)

# Trigger a deployment with a specific image tag:
gh workflow run deploy.yml --field image_tag=arm64-latest
```

**Locally:**
```bash
export KUBECONFIG_CONTENT="$(cat ~/.kube/k3s-cluster)"
cd modules/kubernetes && terraform apply \
  -var="kubeconfig_content=$KUBECONFIG_CONTENT" \
  -var="dns_zone=$(terraform output -raw dns_zone)" \
  -var="ingress_subdomains={go-api=go-api}" \
  -var="dynamodb_tables={go-api=k3s-cluster-go-api-items}" \
  -var="image_tag=arm64-latest"

cd ../../
```

### Verify

```bash
# SSH through NGINX to the control plane
ssh ubuntu@<nginx-public-ip> -i ~/.ssh/k3s-cluster.pem

# From the control plane, check cluster status
sudo kubectl get nodes

# Check cert-manager certificates
sudo kubectl get certificates
sudo kubectl get tls secrets

# Check go-api pod is running
sudo kubectl get pods -l app=go-api
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

## CI/CD

- **Infra plan/apply** (`infra-plan.yml`): Plans on PRs, auto-applies on main push for AWS infra changes.
- **K8s deploy** (`deploy.yml`): Manual dispatch with image tag parameter, or auto-deploy via `deploy-*` git tags.

See [AGENTS.md#CI/CD](AGENTS.md) for full details and setup commands.

## Cost

~$50/month with NAT Gateway running. Stop NGINX and NAT Gateway when idle to save ~$43/mo.

## Structure

```
networking/   VPC, subnets, IGW, NAT GW, route tables
iam/          IAM roles, policies, instance profile
compute/      EC2 instances (control plane, worker, NGINX) + bootstrapping scripts
services/     DynamoDB tables, S3 bucket
dns/          Cloudflare DNS record management
cert-manager/ Let's Encrypt via cert-manager + Cloudflare DNS-01 challenge
modules/kubernetes/ K8s resources (deployment, service, ingress with cert-manager TLS)
k8s/          Legacy template manifests (superseded by modules/kubernetes/)
staging/      Separate environment for testing changes
.github/workflows/  CI: infra plan/apply, K8s deploy
scripts/        Helpers (SSH secret upload, etc.)
```

## Further reading

- [PREREQUISITES.md](PREREQUISITES.md) — Full setup guide with IAM policy details and cost estimates
- [ARCHITECTURE.md](ARCHITECTURE.md) — Complete architecture documentation including TLS termination, cert-manager, traffic flows, and AWS Well-Architected alignment
