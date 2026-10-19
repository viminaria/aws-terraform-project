# Hardcoded Ubuntu 24.04 x86_64 HVM AMI for Floci (no AWS data source lookup)
locals {
  ubuntu_amd64_noble_2404 = "ami-0c55b159cbfafe1f0"
}

# NGINX load balancer in public subnet — depends on control plane for IP injection
resource "aws_instance" "nginx" {
  ami                         = local.ubuntu_amd64_noble_2404
  instance_type               = var.instance_type_nginx
  subnet_id                   = var.subnet_ids.public
  vpc_security_group_ids      = [aws_security_group.nginx.id]
  iam_instance_profile        = var.iam_instance_profile
  associate_public_ip_address = true
  key_name                    = aws_key_pair.k3s.key_name

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

# Control plane instance in private subnet
resource "aws_instance" "control_plane" {
  ami                    = local.ubuntu_amd64_noble_2404
  instance_type          = var.instance_type_cp
  subnet_id              = var.subnet_ids.private
  vpc_security_group_ids = [aws_security_group.k3s_cp.id]
  iam_instance_profile   = var.iam_instance_profile
  key_name               = aws_key_pair.k3s.key_name

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = file("${path.module}/scripts/control_plane.sh")

  tags = {
    Name = "${var.project_name}-control-plane"
    Role = "k3s-server"
  }
}

# Worker instance in private subnet
resource "aws_instance" "worker" {
  ami                    = local.ubuntu_amd64_noble_2404
  instance_type          = var.instance_type_worker
  subnet_id              = var.subnet_ids.private
  vpc_security_group_ids = [aws_security_group.k3s_worker.id]
  iam_instance_profile   = var.iam_instance_profile
  key_name               = aws_key_pair.k3s.key_name

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = file("${path.module}/scripts/worker.sh")

  depends_on = [aws_instance.control_plane]

  tags = {
    Name = "${var.project_name}-worker"
    Role = "k3s-agent"
  }
}
