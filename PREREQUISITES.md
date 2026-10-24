# Prerequisites

Set up these before running any Terraform commands.

## 1. AWS CLI installed

```bash
aws --version   # v2.x recommended
```

Configure credentials:
```bash
aws configure
```

Enter:
- **AWS Access Key ID** — from IAM user (no root account access keys)
- **AWS Secret Access Key**
- **Default region name** — `eu-central-1` (or whichever region your trial covers)
- **Default output format** — `json` or `text`

## 2. AWS IAM user with programmatic access

Create an IAM user in the AWS Console:
- **Programmatic access** enabled (generates access key + secret)
- Attach these managed policies:

| Policy | Why |
|--------|-----|
| `AmazonVPCFullAccess` | VPC, subnets, IGW, NAT GW, route tables, security groups |
| `AmazonEC2FullAccess` | EC2 instances, EBS volumes, key pairs |
| `IAMFullAccess` | Creating IAM roles and policies (the project creates its own) |
| `AmazonS3FullAccess` | S3 buckets for state and app data |
| `AmazonDynamoDBFullAccess` | DynamoDB tables for state locking and app data |

Alternatively, attach `AdministratorAccess` during the trial period (you'll delete everything at the end).

## 3. Terraform installed

```bash
# Check version (project requires >= 1.5.0)
terraform version
```

Install via [terraform.io/downloads](https://developer.hashicorp.com/terraform/install) or your package manager (`brew install terraform`, etc.).

## 4. SSH key pair

Either:
- **Use an existing key** in `~/.ssh/` and reference it in a `.tfvars` file, or
- **Generate one**: `ssh-keygen -t ed25519 -f ~/.ssh/k3s-cluster -N ""`

## 5. Cloudflare account with a domain (optional but recommended)

For automatic DNS record creation and Let's Encrypt certificate provisioning, you need:
- A Cloudflare account (free tier is fine)
- Your domain's nameservers pointed to Cloudflare, or at least the subdomains you'll use

Get your API token: **My Profile → API Tokens → Create Token** (use a custom token with "Edit DNS" permission on your zone — not the Global API Key).

## 6. Create terraform.tfvars

In the project root (`~/aws-terraform-project/`), create `terraform.tfvars`:

```hcl
aws_region       = "eu-central-1"
project_name     = "k3s-cluster"
instance_type_cp = "t4g.small"
instance_type_worker = "t4g.micro"
instance_type_nginx = "t4g.micro"
root_volume_size   = 20

# SSH public key for all EC2 instances (replace with your actual key)
ssh_public_key = "ssh-ed25519 AAAA..."

# Cloudflare — set these if you want automatic DNS + Let's Encrypt certificates
dns_zone             = ""          # e.g. "viminaria.com"
cloudflare_api_token = ""         # Custom API Token with Edit DNS permission (optional)
cloudflare_zone_id   = ""         # Zone ID from your Cloudflare dashboard (optional)
cp_subdomain         = "cp"       # e.g. "cp" → cp.viminaria.com
worker_subdomain     = "k8s"      # e.g. "k8s" → k8s.viminaria.com
nginx_subdomain      = "nginx"    # optional dedicated NGINX subdomain

# Ingress subdomains for cert-manager (map of subdomain to app name)
ingress_subdomains   = { go-api = "go-api" }  # creates go-api.viminaria.com cert
```

Leave `cloudflare_api_token`, `cloudflare_zone_id`, and `dns_zone` empty to skip automatic DNS management and Let's Encrypt certificates. The infrastructure still deploys — you'll use Terraform outputs for manual DNS instead, and NGINX will serve its self-signed certificate.

## 7. Verify AWS access

```bash
aws sts get-caller-identity
```

Should return your account ID and user ARN. If this fails, re-run `aws configure`.

## 8. (Optional) Git initialization

```bash
cd ~/aws-terraform-project
git init
```

The `.gitignore` is already in place to exclude state files and credentials.

## Post-deploy: joining the k3s worker

After `terraform apply`, the control plane starts automatically but the worker needs a manual join:

```bash
# cd into the project directory
cd ~/aws-terraform-project

# Run the helper script (pass your SSH key path if different)
./compute/scripts/join-k3s-worker.sh $(terraform output -raw nginx_public_ip) ~/.ssh/k3s-cluster
```

This script:
1. SSHes through the NGINX bastion to fetch the k3s join token from the control plane
2. SSHes through NGINX to the worker node and runs the `k3s agent --server ... --token ...` command
3. Verifies the cluster has both nodes

## Applying Kubernetes resources

After joining the worker, apply the Go API K8s manifests:

```bash
export KUBECONFIG_CONTENT="$(cat ~/.kube/k3s-cluster)"
cd modules/kubernetes

terraform apply \
  -var="kubeconfig_content=$KUBECONFIG_CONTENT" \
  -var="dns_zone=$(terraform output -raw dns_zone)" \
  -var="ingress_subdomains={go-api=go-api}" \
  -var="dynamodb_tables={go-api=k3s-cluster-go-api-items}"

cd ../../
```

This applies the deployment, service, and Ingress resources to the cluster. The Ingress references the `letsencrypt-prod` ClusterIssuer (created by the `cert-manager/` module), so cert-manager automatically provisions Let's Encrypt TLS certificates via Cloudflare DNS-01.

## Cost estimate

| Resource | Monthly cost |
|----------|-------------|
| t4g.small (control plane) | ~$15 |
| t4g.micro (worker) | ~$8 |
| t4g.micro (nginx LB) | ~$8 |
| NAT Gateway + data processing | ~$35-40 |
| EBS volumes (3x 20GB gp3) | ~$3 |
| DynamoDB + S3 | ~$0.25 |
| **Total** | **~$70/mo** |

Stop NGINX and NAT Gateway when not actively working: shut down EC2 instances in the console or `terraform destroy -target=...` to save ~$43/mo while stopped.
