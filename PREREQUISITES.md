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

## 5. Cloudflare account with a domain

You need:
- A Cloudflare account (free tier is fine)
- Your domain's nameservers pointed to Cloudflare, or at least the subdomains you'll use

Get your API key: **My Profile → API Tokens → Global API Key** (or create a specific token with Edit DNS permission on your zone).

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

# Cloudflare — set these if you want the dns/ module to create records automatically
cloudflare_api_token = ""   # API Token or Global API Key (optional, leave empty for manual DNS)
cloudflare_zone_id   = ""   # Zone ID from your Cloudflare dashboard (optional)
cp_subdomain         = "cp"  # e.g. "cp" → cp.yourdomain.com
worker_subdomain     = "k8s"  # e.g. "k8s" → k8s.yourdomain.com
```

Leave `cloudflare_api_token` and `cloudflare_zone_id` empty to skip automatic DNS management — you'll use Terraform outputs instead (see below).

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
