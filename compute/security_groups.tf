# Security group for NGINX load balancer — entry point from internet
resource "aws_security_group" "nginx" {
  name        = "${var.project_name}-nginx"
  description = "Security group for NGINX load balancer"
  vpc_id      = var.vpc_id

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from internet"
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from internet"
  }

  # k3s API server port — forward to control plane
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.private_subnet_cidr]
    description = "k3s API server (forwarded by nginx, from k8s pods)"
  }

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "${var.project_name}-nginx-sg"
  }
}

# Security group for k3s control plane — private access only
resource "aws_security_group" "k3s_cp" {
  name        = "${var.project_name}-k3s-cp"
  description = "Security group for k3s control plane node"
  vpc_id      = var.vpc_id

  # SSH from NGINX security group
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.nginx.id]
    description     = "SSH from NGINX jump host"
  }

  # k3s API server — from nginx LB and same subnet
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.public_subnet_cidr, var.private_subnet_cidr]
    description = "k3s API server (from nginx and cluster)"
  }

  # kubelet
  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = [var.private_subnet_cidr]
    description = "kubelet API (same subnet)"
  }

  # etcd
  ingress {
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    self        = true
    description = "etcd (internal cluster communication)"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "${var.project_name}-k3s-cp-sg"
  }
}

# Security group for k3s worker node — private access only
resource "aws_security_group" "k3s_worker" {
  name        = "${var.project_name}-k3s-worker"
  description = "Security group for k3s worker node"
  vpc_id      = var.vpc_id

  # SSH from NGINX security group
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.nginx.id]
    description     = "SSH from NGINX jump host"
  }

  # kubelet — from control plane and same subnet
  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = [var.private_subnet_cidr]
    description = "kubelet API (same subnet)"
  }

  # NodePort range — from nginx LB and cluster
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = [var.public_subnet_cidr, var.private_subnet_cidr]
    description = "Kubernetes NodePort range"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "${var.project_name}-k3s-worker-sg"
  }
}
