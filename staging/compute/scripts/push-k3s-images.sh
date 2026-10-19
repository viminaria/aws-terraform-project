#!/bin/bash
# Pre-provisioning script: push k3s images to Floci ECR from the host machine.
# Run this BEFORE terraform apply in staging/ if you want air-gapped nodes.
# If your EC2 instances have internet access, this is optional (images pull from Docker Hub).
set -euo pipefail

ECR_URI="${ECR_URI:-000000000000.dkr.ecr.eu-central-1.localhost:4566}"
K3S_VERSION="${K3S_VERSION:-v1.31.2-k3s1}"

echo "=== Authenticating against Floci ECR ==="
aws ecr get-login-password --endpoint-url http://localhost:4566 \
  | docker login --username AWS --password-stdin "$ECR_URI" >/dev/null 2>&1
echo "Logged in to $ECR_URI"

# Images required by k3s - push them so nodes can pull from ECR over localhost
IMAGES=(
  "rancher/k3s:${K3S_VERSION}"
  "rancher/mirrored-cluster-register:v0.1.11"
  "rancher/mirrored-library-coredns:1.12.1"
  "rancher/mirrored-library-etcd:3.5.16"
  "rancher/mirrored-library-traefik:v2.11.11"
  "rancher/mirrored-library-metrics-server:v0.7.2"
  "rancher/local-path-provisioner:v0.0.28"
  "rancher/mirrored-library-helm:3.16.4"
)

echo "=== Pulling, tagging, and pushing images to ECR ==="
for img in "${IMAGES[@]}"; do
  echo -n "Processing $img ... "
  
  # Pull from Docker Hub (requires internet on host)
  docker pull "$img" >/dev/null 2>&1 || { echo "PULL FAILED, skipping"; continue; }
  
  # Extract just the repo:tag portion for ECR path
  REPO_TAG="${img#rancher/}"
  
  # Tag for ECR and push
  docker tag "$img" "$ECR_URI/${REPO_TAG}" >/dev/null 2>&1
  docker push "$ECR_URI/${REPO_TAG}" >/dev/null 2>&1
  
  echo "done"
done

echo ""
echo "=== Pushed images ==="
aws ecr list-images --repository-name k3s-cluster-k3s-images \
  --endpoint-url http://localhost:4566 --output table
