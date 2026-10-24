module "networking" {
  source = "./networking"

  aws_region          = var.aws_region
  project_name        = var.project_name
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
}

module "iam" {
  source                     = "./iam"
  project_name               = var.project_name
  dynamodb_table_name        = var.dynamodb_table_name
  go_api_dynamodb_table_name = var.go_api_dynamodb_table_name
  s3_bucket_name             = var.s3_bucket_name
  aws_region                 = var.aws_region
}

module "services" {
  source                     = "./services"
  project_name               = var.project_name
  dynamodb_table_name        = var.dynamodb_table_name
  go_api_dynamodb_table_name = var.go_api_dynamodb_table_name
  s3_bucket_name             = var.s3_bucket_name
}

module "compute" {
  source               = "./compute"
  project_name         = var.project_name
  instance_type_cp     = var.instance_type_cp
  instance_type_worker = var.instance_type_worker
  instance_type_nginx  = var.instance_type_nginx
  root_volume_size     = var.root_volume_size
  ssh_public_key       = var.ssh_public_key
  ssh_key_name         = var.ssh_key_name
  k3s_version          = var.k3s_version
  dns_zone             = var.dns_zone
  ingress_subdomains   = var.ingress_subdomains
  external_ip          = var.external_ip

  subnet_ids = {
    public  = module.networking.public_subnet_id
    private = module.networking.private_subnet_id
  }
  vpc_id                     = module.networking.vpc_id
  public_subnet_cidr         = var.public_subnet_cidr
  private_subnet_cidr        = var.private_subnet_cidr
  iam_instance_profile       = module.iam.instance_profile_name
  nginx_iam_instance_profile = module.iam.nginx_instance_profile_name
}
module "dns" {
  source = "./dns"

  dns_zone         = var.dns_zone
  cp_subdomain     = var.cp_subdomain
  worker_subdomain = var.worker_subdomain
  nginx_subdomain  = var.nginx_subdomain
  nginx_public_ip  = module.compute.nginx_public_ip
  ingress_records  = {}
}

# Kubernetes provider — shared by cert-manager and k8s resources in this root
locals {
  kubeconfig_path     = "~/.kube/k3s-cluster"
  kubeconfig_filename = "${pathexpand("~")}/.kube/k3s-cluster"
}

resource "local_file" "kubeconfig" {
  content              = var.kubeconfig_content
  filename             = local.kubeconfig_filename
  file_permission      = "0600"
  directory_permission = "0700"
}

provider "kubernetes" {
  config_path = local_file.kubeconfig.filename
}

# cert-manager — ACME certificate management with Cloudflare DNS-01 challenge
module "cert_manager" {
  source     = "./cert-manager"
  depends_on = [module.compute]

  dns_zone             = var.dns_zone
  cloudflare_api_token = var.cloudflare_api_token
  ingress_subdomains   = var.ingress_subdomains
}

# Kubernetes resources (go-api deployment/service/ingress) — uses kubeconfig
# extracted via SSH, no public API endpoint needed. Provision separately:
#   export KUBECONFIG_CONTENT="$(cat ~/.kube/k3s-cluster)"
#   cd modules/kubernetes && terraform apply -var="kubeconfig_content=$KUBECONFIG_CONTENT"
