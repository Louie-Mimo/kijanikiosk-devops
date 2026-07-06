terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  required_version = ">= 1.5"

  backend "s3" {
    bucket       = "kijanikiosk-terraform-state-louisza"
    key          = "staging/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_vpc" "default" {
  default = true
}

data "aws_ami" "ubuntu" {
  most_recent = true

  owners = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

locals {
  servers = {
    api = {
      instance_type = "t3.micro"
    }

    payments = {
      instance_type = "t3.micro"
    }

    logs = {
      instance_type = "t3.micro"
    }
  }
}

module "app_servers" {
  source = "./modules/app_server"

  for_each = local.servers

  name          = "kijanikiosk-${each.key}"
  instance_type = each.value.instance_type

  environment = var.environment
  ami_id      = data.aws_ami.ubuntu.id
  key_name    = var.key_name

  subnet_id = "subnet-04d343402d1843272"
  vpc_id    = data.aws_vpc.default.id

  ssh_cidr = var.ssh_cidr
}
