# Key pair for EC2 instances — use provided SSH key or placeholder for Floci testing
resource "aws_key_pair" "k3s" {
  key_name   = var.ssh_key_name
  public_key = var.ssh_public_key != "" ? var.ssh_public_key : "ssh-ed25519 staging-placeholder-key@floci"
}
