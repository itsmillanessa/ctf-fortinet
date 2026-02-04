# =============================================================================
# CTFd MODULE — Central CTF Scoring Platform
# =============================================================================
# Two modes:
#   1. create_vpc = true  → Creates dedicated VPC (needs VPC quota)
#   2. create_vpc = false → Uses existing VPC/subnet (for dev or tight quotas)
# =============================================================================

variable "event_name" {
  type    = string
  default = "fortinet-ctf"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "key_name" {
  type = string
}

variable "admin_password" {
  description = "CTFd admin password"
  type        = string
  sensitive   = true
  default     = "CTFAdmin2026!"
}

variable "team_count" {
  type    = number
  default = 1
}

variable "team_flags" {
  type    = map(map(string))
  default = {}
}

variable "team_fortigate_ips" {
  type    = map(string)
  default = {}
}

variable "create_vpc" {
  description = "Create a dedicated VPC for CTFd (set false to use existing)"
  type        = bool
  default     = false
}

variable "existing_vpc_id" {
  description = "Existing VPC ID (when create_vpc = false)"
  type        = string
  default     = ""
}

variable "existing_subnet_id" {
  description = "Existing subnet ID (when create_vpc = false)"
  type        = string
  default     = ""
}

locals {
  common_tags = {
    Project   = var.event_name
    Component = "ctfd-portal"
    ManagedBy = "terraform"
  }
}

# =============================================================================
# OPTION A: Dedicated VPC (production)
# =============================================================================

resource "aws_vpc" "ctfd" {
  count                = var.create_vpc ? 1 : 0
  cidr_block           = "10.100.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${var.event_name}-ctfd-vpc"
  })
}

resource "aws_internet_gateway" "ctfd" {
  count  = var.create_vpc ? 1 : 0
  vpc_id = aws_vpc.ctfd[0].id

  tags = merge(local.common_tags, {
    Name = "${var.event_name}-ctfd-igw"
  })
}

resource "aws_subnet" "ctfd" {
  count                   = var.create_vpc ? 1 : 0
  vpc_id                  = aws_vpc.ctfd[0].id
  cidr_block              = "10.100.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"

  tags = merge(local.common_tags, {
    Name = "${var.event_name}-ctfd-subnet"
  })
}

resource "aws_route_table" "ctfd" {
  count  = var.create_vpc ? 1 : 0
  vpc_id = aws_vpc.ctfd[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ctfd[0].id
  }

  tags = merge(local.common_tags, {
    Name = "${var.event_name}-ctfd-rt"
  })
}

resource "aws_route_table_association" "ctfd" {
  count          = var.create_vpc ? 1 : 0
  subnet_id      = aws_subnet.ctfd[0].id
  route_table_id = aws_route_table.ctfd[0].id
}

# =============================================================================
# Resolved IDs (pick dedicated or existing)
# =============================================================================

locals {
  vpc_id    = var.create_vpc ? aws_vpc.ctfd[0].id : var.existing_vpc_id
  subnet_id = var.create_vpc ? aws_subnet.ctfd[0].id : var.existing_subnet_id
}

# =============================================================================
# Security Group
# =============================================================================

resource "aws_security_group" "ctfd" {
  name_prefix = "${var.event_name}-ctfd-"
  vpc_id      = local.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.event_name}-ctfd-sg"
  })
}

# =============================================================================
# Ubuntu AMI
# =============================================================================

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# =============================================================================
# CTFd Instance
# =============================================================================

resource "aws_instance" "ctfd" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = local.subnet_id
  vpc_security_group_ids      = [aws_security_group.ctfd.id]
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/templates/ctfd_userdata.sh", {
    admin_password = var.admin_password
    event_name     = var.event_name
    team_count     = var.team_count
  })

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = merge(local.common_tags, {
    Name = "${var.event_name}-ctfd-server"
  })
}

# =============================================================================
# Elastic IP
# =============================================================================

resource "aws_eip" "ctfd" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.event_name}-ctfd-eip"
  })
}

resource "aws_eip_association" "ctfd" {
  instance_id   = aws_instance.ctfd.id
  allocation_id = aws_eip.ctfd.id
}

# =============================================================================
# OUTPUTS
# =============================================================================

output "ctfd_url" {
  value = "http://${aws_eip.ctfd.public_ip}"
}

output "ctfd_public_ip" {
  value = aws_eip.ctfd.public_ip
}

output "ctfd_instance_id" {
  value = aws_instance.ctfd.id
}

output "ctfd_admin_user" {
  value = "admin"
}

output "ctfd_admin_password" {
  value     = var.admin_password
  sensitive = true
}
