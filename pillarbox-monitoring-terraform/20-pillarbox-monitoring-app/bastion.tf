# -----------------------------------
# Bastion configuration
# -----------------------------------

resource "aws_key_pair" "bastion_key" {
  key_name   = "bastion-keypair"
  public_key = var.bastion_public_key
}

# Security Group for the Bastion Host
resource "aws_security_group" "bastion_sg" {
  name        = "bastion-sg"
  description = "Allow SSH access by IP"
  vpc_id      = data.aws_vpc.main_vpc.id

  ingress {
    description = "SSH from my Allowed IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.bastion_allowed_ips
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Bastion Host EC2 Instance in Public Subnet
resource "aws_instance" "bastion" {
  ami                         = local.bastion.ami
  instance_type               = local.bastion.instance_type
  subnet_id                   = data.aws_subnets.public_subnets.ids[0]
  key_name                    = "bastion-keypair"
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true

  tags = {
    Name = "bastion-host"
  }
}
