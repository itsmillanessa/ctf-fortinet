# =============================================================================
# NETWORK MODULE — Isolated VPC per team
# =============================================================================
# Creates a complete network stack for one CTF team:
# - VPC with isolated CIDR
# - Public subnet (WAN/management)
# - Private subnet (LAN/internal)  
# - DMZ subnet (for vulnerable servers)
# - Internet Gateway + NAT Gateway
# - Route tables
# =============================================================================

variable "team_id" {
  description = "Team number (1-10)"
  type        = number
}

variable "team_name" {
  description = "Team display name"
  type        = string
  default     = ""
}

variable "event_name" {
  description = "Event identifier"
  type        = string
  default     = "fortinet-ctf"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

locals {
  team_label = var.team_name != "" ? var.team_name : "team-${var.team_id}"
  
  # Each team gets a /16 VPC: 10.<team_id>.0.0/16
  vpc_cidr     = "10.${var.team_id}.0.0/16"
  
  # Subnets within the VPC
  wan_subnet   = "10.${var.team_id}.1.0/24"    # WAN/Management
  lan_subnet   = "10.${var.team_id}.2.0/24"    # LAN/Internal  
  dmz_subnet   = "10.${var.team_id}.3.0/24"    # DMZ (vulnerable servers)
  
  # FortiGate IPs (predictable)
  fgt_wan_ip   = "10.${var.team_id}.1.10"
  fgt_lan_ip   = "10.${var.team_id}.2.10"
  fgt_dmz_ip   = "10.${var.team_id}.3.10"
  
  common_tags = {
    Project   = var.event_name
    Team      = local.team_label
    TeamID    = var.team_id
    ManagedBy = "terraform"
  }
}

# --- VPC ---
resource "aws_vpc" "team" {
  cidr_block           = local.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${var.event_name}-${local.team_label}-vpc"
  })
}

# --- Internet Gateway ---
resource "aws_internet_gateway" "team" {
  vpc_id = aws_vpc.team.id

  tags = merge(local.common_tags, {
    Name = "${var.event_name}-${local.team_label}-igw"
  })
}

# --- WAN Subnet (Public) ---
resource "aws_subnet" "wan" {
  vpc_id                  = aws_vpc.team.id
  cidr_block              = local.wan_subnet
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"

  tags = merge(local.common_tags, {
    Name = "${var.event_name}-${local.team_label}-wan"
    Role = "wan"
  })
}

# --- LAN Subnet (Private) ---
resource "aws_subnet" "lan" {
  vpc_id            = aws_vpc.team.id
  cidr_block        = local.lan_subnet
  availability_zone = "${var.aws_region}a"

  tags = merge(local.common_tags, {
    Name = "${var.event_name}-${local.team_label}-lan"
    Role = "lan"
  })
}

# --- DMZ Subnet ---
resource "aws_subnet" "dmz" {
  vpc_id            = aws_vpc.team.id
  cidr_block        = local.dmz_subnet
  availability_zone = "${var.aws_region}a"

  tags = merge(local.common_tags, {
    Name = "${var.event_name}-${local.team_label}-dmz"
    Role = "dmz"
  })
}

# --- Route Table (WAN — public) ---
resource "aws_route_table" "wan" {
  vpc_id = aws_vpc.team.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.team.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.event_name}-${local.team_label}-rt-wan"
  })
}

resource "aws_route_table_association" "wan" {
  subnet_id      = aws_subnet.wan.id
  route_table_id = aws_route_table.wan.id
}

# --- Route Table (LAN — through FortiGate) ---
resource "aws_route_table" "lan" {
  vpc_id = aws_vpc.team.id

  tags = merge(local.common_tags, {
    Name = "${var.event_name}-${local.team_label}-rt-lan"
  })
}

resource "aws_route_table_association" "lan" {
  subnet_id      = aws_subnet.lan.id
  route_table_id = aws_route_table.lan.id
}

# --- Route Table (DMZ — through FortiGate) ---
resource "aws_route_table" "dmz" {
  vpc_id = aws_vpc.team.id

  tags = merge(local.common_tags, {
    Name = "${var.event_name}-${local.team_label}-rt-dmz"
  })
}

resource "aws_route_table_association" "dmz" {
  subnet_id      = aws_subnet.dmz.id
  route_table_id = aws_route_table.dmz.id
}

# --- Security Group (FortiGate — allow all for CTF lab) ---
resource "aws_security_group" "fortigate" {
  name_prefix = "${var.event_name}-${local.team_label}-fgt-"
  vpc_id      = aws_vpc.team.id
  description = "FortiGate security group - CTF lab (permissive)"

  # Allow all inbound (lab environment)
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.event_name}-${local.team_label}-sg-fgt"
  })
}

# --- Security Group (Internal VMs) ---
resource "aws_security_group" "internal" {
  name_prefix = "${var.event_name}-${local.team_label}-int-"
  vpc_id      = aws_vpc.team.id
  description = "Internal VMs security group"

  # Allow all from VPC
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [local.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.event_name}-${local.team_label}-sg-int"
  })
}

# =============================================================================
# OUTPUTS
# =============================================================================

output "vpc_id" {
  value = aws_vpc.team.id
}

output "wan_subnet_id" {
  value = aws_subnet.wan.id
}

output "lan_subnet_id" {
  value = aws_subnet.lan.id
}

output "dmz_subnet_id" {
  value = aws_subnet.dmz.id
}

output "fortigate_sg_id" {
  value = aws_security_group.fortigate.id
}

output "internal_sg_id" {
  value = aws_security_group.internal.id
}

output "fgt_wan_ip" {
  value = local.fgt_wan_ip
}

output "fgt_lan_ip" {
  value = local.fgt_lan_ip
}

output "fgt_dmz_ip" {
  value = local.fgt_dmz_ip
}

output "vpc_cidr" {
  value = local.vpc_cidr
}

output "team_label" {
  value = local.team_label
}

output "wan_route_table_id" {
  value = aws_route_table.wan.id
}

output "lan_route_table_id" {
  value = aws_route_table.lan.id
}

output "dmz_route_table_id" {
  value = aws_route_table.dmz.id
}
