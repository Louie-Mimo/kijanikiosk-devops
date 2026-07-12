resource "aws_security_group" "app" {
  name        = "${var.name}-sg"
  description = "Security group for KijaniKiosk API"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH"

    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [var.ssh_cidr]
  }

  ingress {
    description = "HTTP"

    from_port = 80
    to_port   = 80
    protocol  = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {

    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.name}-sg"
    Environment = var.environment
  }
}

resource "aws_instance" "this" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name
  subnet_id     = var.subnet_id
  vpc_security_group_ids = [
    aws_security_group.app.id
  ]

  tags = {
    Name        = var.name
    Service     = var.name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
