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

  # k3s API server port — forward to control plane (from internet and cluster)
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "k3s API server (forwarded by nginx, from internet and pods)"
  }

  # SSH from your public IP
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.external_ip]
    description = "SSH access from trusted IP"
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

  # NodePort range — from nginx LB and cluster (needed for Traefik ingress)
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = [var.public_subnet_cidr, var.private_subnet_cidr]
    description = "Kubernetes NodePort range (ingress proxy)"
  }

  # HTTP from internet — for Traefik ACME + Cloudflare Flexible SSL mode
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP for Traefik web entry point (ACME + Cloudflare proxy)"
  }

  # Traefik entries from NGINX — HTTPS termination at CF, forwarded to Traefik
  ingress {
    from_port       = 8000
    to_port         = 8443
    protocol        = "tcp"
    security_groups = [aws_security_group.nginx.id]
    description     = "Traefik web+websecure from NGINX proxy"
  }

  # k3s worker security group — allow all TCP/UDP for flannel VXLAN and inter-node pod routing
  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.k3s_worker.id]
    description     = "Allow all TCP from worker (flannel VXLAN, pod routing)"
  }

  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "udp"
    security_groups = [aws_security_group.k3s_worker.id]
    description     = "Allow all UDP from worker (flannel VXLAN)"
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

  # HTTP from internet — for Traefik web entry point (Cloudflare proxy)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP for Traefik web entry point (Cloudflare proxy)"
  }

  # All TCP/UDP from private subnet — flannel VXLAN and inter-node pod routing
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.private_subnet_cidr]
    description = "Allow all TCP from private subnet (flannel VXLAN, pod routing)"
  }

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = [var.private_subnet_cidr]
    description = "Allow all UDP from private subnet (flannel VXLAN)"
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
