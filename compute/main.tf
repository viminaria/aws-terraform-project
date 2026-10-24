data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }
}

# Shared cluster token — generated once at plan time, used by both control plane and workers
resource "random_password" "k3s_token" {
  length           = 32
  special          = false
  override_special = "abcdefghijklmnopqrstuvwxyz0123456789"
}

# NGINX load balancer in public subnet — depends on control plane for IP injection
resource "aws_instance" "nginx" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type_nginx
  subnet_id              = var.subnet_ids.public
  vpc_security_group_ids = [aws_security_group.nginx.id]
  iam_instance_profile   = var.nginx_iam_instance_profile
  key_name               = aws_key_pair.k3s.key_name
  monitoring             = true

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = templatefile("${path.module}/scripts/nginx.sh", {
    fallback_cp_ip = aws_instance.control_plane.private_ip
  })

  depends_on = [aws_instance.control_plane]

  tags = {
    Name = "${var.project_name}-nginx"
    Role = "load-balancer"
  }
}

# Elastic IP for NGINX — persists across stop/start/recreate
resource "aws_eip" "nginx" {
  domain   = "vpc"
  instance = aws_instance.nginx.id

  tags = {
    Name = "${var.project_name}-nginx-eip"
  }
}

# Elastic IP for control plane — allows direct SSH access for cluster management
resource "aws_eip" "control_plane" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-cp-eip"
  }
}

# Control plane instance in private subnet
resource "aws_instance" "control_plane" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type_cp
  subnet_id              = var.subnet_ids.private
  vpc_security_group_ids = [aws_security_group.k3s_cp.id]
  iam_instance_profile   = var.iam_instance_profile
  key_name               = aws_key_pair.k3s.key_name
  monitoring             = true

  associate_public_ip_address = true

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = templatefile("${path.module}/scripts/control_plane.sh", {
    ssh_public_key = var.ssh_public_key
    k3s_token      = random_password.k3s_token.result
  })

  tags = {
    Name = "${var.project_name}-control-plane"
    Role = "k3s-server"
  }
}

# Extract k8s API server URL and save kubeconfig after control plane is running
resource "null_resource" "extract_k8s_certs" {
  triggers = {
    nginx_public_ip = aws_eip.nginx.public_ip
  }

  provisioner "local-exec" {
    command = "./${path.module}/scripts/extract_k8s_certs.sh ${aws_eip.nginx.public_ip} ${aws_instance.control_plane.private_ip}"
  }

  depends_on = [aws_instance.nginx]
}

# Worker instance in private subnet — auto-joins using the same plan-time token
resource "aws_instance" "worker" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type_worker
  subnet_id              = var.subnet_ids.private
  vpc_security_group_ids = [aws_security_group.k3s_worker.id]
  iam_instance_profile   = var.iam_instance_profile
  key_name               = aws_key_pair.k3s.key_name
  monitoring             = true

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = templatefile("${path.module}/scripts/worker.sh", {
    k3s_control_plane_ip = aws_instance.control_plane.private_ip
    ssh_public_key       = var.ssh_public_key
    k3s_token            = random_password.k3s_token.result
  })

  tags = {
    Name = "${var.project_name}-worker"
    Role = "k3s-agent"
  }
}
