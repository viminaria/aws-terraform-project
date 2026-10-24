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
    k3s_control_plane_ip = aws_instance.control_plane.private_ip
    k3s_worker_ip        = aws_instance.worker.private_ip
  })

  depends_on = [aws_instance.control_plane, aws_instance.worker]

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

# Control plane instance in private subnet
resource "aws_instance" "control_plane" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type_cp
  subnet_id              = var.subnet_ids.private
  vpc_security_group_ids = [aws_security_group.k3s_cp.id]
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

  user_data = templatefile("${path.module}/scripts/control_plane.sh", {
    ssh_public_key = file("~/.ssh/k3s-cluster.pub")
  })

  tags = {
    Name = "${var.project_name}-control-plane"
    Role = "k3s-server"
  }
}

# SSM parameter for k3s cluster token (shared between nodes)
resource "aws_ssm_parameter" "k3s_token" {
  name  = "/k3s/cluster/token"
  type  = "String"
  value = "TEMP" # Overwritten by null_resource.extract_k3s_token after k3s starts

  tags = {
    Name = "${var.project_name}-k3s-token"
  }
}

# Extract k3s token and store in SSM after all instances are running
resource "null_resource" "extract_k3s_token" {
  triggers = {
    nginx_public_ip = aws_eip.nginx.public_ip
  }

  provisioner "local-exec" {
    command = "./${path.module}/scripts/extract_k3s_token.sh ${aws_eip.nginx.public_ip} ${aws_instance.control_plane.private_ip}"
  }

  depends_on = [aws_instance.control_plane, aws_instance.nginx]
}

# Extract k8s API server URL and save kubeconfig after control plane is running
resource "null_resource" "extract_k8s_certs" {
  triggers = {
    nginx_public_ip = aws_eip.nginx.public_ip
  }

  provisioner "local-exec" {
    command = "./${path.module}/scripts/extract_k8s_certs.sh ${aws_eip.nginx.public_ip} ${aws_instance.control_plane.private_ip}"
  }

  depends_on = [aws_instance.control_plane, aws_instance.nginx]
}

# Worker instance in private subnet
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
    ssh_public_key       = file("~/.ssh/k3s-cluster.pub")
    k3s_token            = aws_ssm_parameter.k3s_token.value
  })

  depends_on = [aws_ssm_parameter.k3s_token]

  tags = {
    Name = "${var.project_name}-worker"
    Role = "k3s-agent"
  }
}


