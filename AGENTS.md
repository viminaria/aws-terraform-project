# aws-terraform-project: Self-managed k3s cluster on AWS

## Purpose

Learning Terraform and AWS services by provisioning a production-like infrastructure for a self-managed Kubernetes (k3s) cluster. Designed as a hands-on project for DevOps/SRE/Cloud Engineer skill development during an AWS trial period.

## Architecture

- **NGINX load balancer** (`t4g.micro`) — public subnet, entry point for all traffic
- **1x k3s control plane node** (`t4g.small`, 2 vCPU, 2GB RAM) — private subnet
- **1x k3s worker node** (`t4g.micro`, 2 vCPU, 1GB RAM) — private subnet
- NAT Gateway provides outbound internet access for k3s image pulls

```
Internet → NGINX (public IP/DNS) on port 6443 → k3s API server
                    └── :80/:443 → k8s NodePort services

SSH: ssh ubuntu@<nginx-public-ip> -i key.pem
     # from nginx: ssh ubuntu@<control-plane-private-ip> -i key.pem
```

## Goals

1. **Terraform proficiency** — modular structure, remote state with S3 + DynamoDB locking, variable/output patterns, templatefile for config injection
2. **AWS networking** — VPC, public/private subnets, IGW, NAT Gateway, security groups, route tables
3. **IAM security** — instance profiles, least-privilege policies for EC2 → DynamoDB/S3 access
4. **Compute management** — EC2 provisioning with user_data bootstrapping k3s + NGINX, NAT Gateway, key pairs
5. **Kubernetes on AWS** — self-managed cluster behind a reverse proxy, private subnets, NodePort services

## Cost targets

- ~$50/month total (EC2 × 3 + EBS × 3 + DynamoDB + S3 + NAT Gateway)
- EC2 (~$28/mo) + NAT GW (~$35/mo fixed + data processing)

**Save by stopping NAT/NGINX when not in use.** Terraform `terraform taint` or `terraform destroy` for the resources.

## Apply order

1. `backend.tf` — S3 bucket for state, DynamoDB for locking
2. `iam/` — Roles and policies
3. `networking/` — VPC, subnets, IGW, NAT GW, route tables
4. `compute/` — k3s control plane → worker → NGINX (dependency-ordered)
5. `services/` — DynamoDB table, S3 bucket for app data

## Post-deploy: joining the cluster

After `terraform apply`, the control plane starts automatically but the worker needs a manual join:

```bash
# cd into the project directory
cd ~/aws-terraform-project

# Run the helper script (pass your SSH key path if different)
./compute/scripts/join-k3s-worker.sh $(terraform output -raw nginx_public_ip) ~/.ssh/k3s-cluster
```

The script:
1. SSHes through NGINX → fetches k3s join token from control plane
2. SSHes through NGINX → joins worker to cluster via `k3s agent --server ...`
3. Prints confirmation

See PREREQUISITES.md for full details.

## Not in scope yet

- EKS (self-managed only)
- Multi-AZ redundancy
- ALB/NLB for k8s Ingress (NodePort/NGINX reverse proxy for now)
- CI/CD pipeline
- Monitoring stack (prometheus/grafana)
- TLS certificates (self-signed cert on NGINX for learning purposes)
