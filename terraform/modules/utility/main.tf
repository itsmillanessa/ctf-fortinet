# =============================================================================
# UTILITY SERVER MODULE — Flag Server + Traffic Generator
# =============================================================================
# Single t3.micro that serves all teams:
# - Flask flag server (validates conditions, serves flags)
# - Traffic generator (tcpreplay + custom scripts)
# - Connected to all team VPCs via peering
# =============================================================================

variable "event_name" {
  type    = string
  default = "fortinet-ctf"
}

variable "vpc_id" {
  description = "Default VPC or dedicated utility VPC"
  type        = string
}

variable "subnet_id" {
  description = "Subnet for the utility server"
  type        = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "key_name" {
  type = string
}

variable "team_configs" {
  description = "Map of team_id to their network config (FortiGate IPs, subnets, flags)"
  type = map(object({
    fgt_wan_ip  = string
    fgt_lan_ip  = string
    fgt_dmz_ip  = string
    lan_subnet  = string
    dmz_subnet  = string
    wan_subnet  = string
    flags       = map(string)
  }))
  default = {}
}

variable "admin_cidr" {
  type    = string
  default = "0.0.0.0/0"
}

locals {
  common_tags = {
    Project   = var.event_name
    ManagedBy = "terraform"
    Component = "utility-server"
  }
}

# --- AMI ---
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# --- Security Group ---
resource "aws_security_group" "utility" {
  name_prefix = "${var.event_name}-utility-"
  vpc_id      = var.vpc_id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  # Flag server HTTP (public - for CTF participants)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP public access"
  }

  # Flag server API (public - for CTF challenges)
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Flag server API public access"
  }

  # Allow all from team networks (for traffic gen responses)
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/8"]
    description = "Internal team network access"
  }

  # Outbound all
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.event_name}-utility-sg"
  })
}

# --- S3 bucket for CTF app files (avoids user_data size limit) ---
resource "aws_s3_bucket" "ctf_files" {
  bucket_prefix = "${var.event_name}-files-"
  force_destroy = true
  tags          = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "ctf_files" {
  bucket                  = aws_s3_bucket.ctf_files.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- Build tar.gz archive of app files ---
data "archive_file" "ctf_app" {
  type        = "zip"
  output_path = "${path.module}/files/.ctf_app.zip"

  source {
    content  = file("${path.module}/files/flagserver/app.py")
    filename = "flagserver/app.py"
  }
  source {
    content  = file("${path.module}/files/flagserver/challenges.py")
    filename = "flagserver/challenges.py"
  }
  source {
    content  = file("${path.module}/files/trafficgen/generator.py")
    filename = "trafficgen/generator.py"
  }
  source {
    content  = <<-REQ
flask==3.1.0
paramiko==3.5.0
requests==2.32.0
REQ
    filename = "flagserver/requirements.txt"
  }
}

resource "aws_s3_object" "ctf_app_zip" {
  bucket = aws_s3_bucket.ctf_files.id
  key    = "ctf_app.zip"
  source = data.archive_file.ctf_app.output_path
  etag   = data.archive_file.ctf_app.output_md5
}

resource "aws_s3_object" "team_configs" {
  bucket  = aws_s3_bucket.ctf_files.id
  key     = "team_configs.json"
  content = jsonencode(var.team_configs)
}

# --- IAM role so EC2 can pull from S3 ---
resource "aws_iam_role" "utility" {
  name_prefix = "${var.event_name}-utility-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "utility_s3" {
  name = "s3-read"
  role = aws_iam_role.utility.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:ListBucket"]
      Resource = [
        aws_s3_bucket.ctf_files.arn,
        "${aws_s3_bucket.ctf_files.arn}/*"
      ]
    }]
  })
}

resource "aws_iam_instance_profile" "utility" {
  name_prefix = "${var.event_name}-utility-"
  role        = aws_iam_role.utility.name
}

# --- User Data (minimal bootstrap — downloads files from S3) ---
locals {
  s3_bucket = aws_s3_bucket.ctf_files.id

  userdata_raw = <<-USERDATA
#!/bin/bash
set -ex
exec > /var/log/ctf-bootstrap.log 2>&1
apt-get update -y
apt-get install -y python3-pip python3-venv tcpreplay nmap hping3 curl jq unzip awscli
mkdir -p /opt/ctf/{flagserver,trafficgen,pcaps,logs}
# Download app files from S3
aws s3 cp s3://${local.s3_bucket}/ctf_app.zip /tmp/ctf_app.zip
aws s3 cp s3://${local.s3_bucket}/team_configs.json /opt/ctf/team_configs.json
cd /opt/ctf
unzip -o /tmp/ctf_app.zip
rm /tmp/ctf_app.zip
# Setup Python venv
python3 -m venv /opt/ctf/venv
/opt/ctf/venv/bin/pip install -r /opt/ctf/flagserver/requirements.txt
# Systemd service
cat > /etc/systemd/system/ctf-flagserver.service <<'S'
[Unit]
Description=CTF Flag Server
After=network.target
[Service]
Type=simple
User=root
WorkingDirectory=/opt/ctf/flagserver
Environment=PATH=/opt/ctf/venv/bin:/usr/bin
ExecStart=/opt/ctf/venv/bin/python app.py
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
S
systemctl daemon-reload
systemctl enable ctf-flagserver
systemctl start ctf-flagserver
echo "ready" > /opt/ctf/ready
USERDATA
}

# --- EC2 Instance ---
resource "aws_instance" "utility" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.utility.id]
  iam_instance_profile        = aws_iam_instance_profile.utility.name
  user_data_base64            = base64encode(local.userdata_raw)
  user_data_replace_on_change = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = merge(local.common_tags, {
    Name = "${var.event_name}-utility-server"
  })
}

# --- Elastic IP ---
resource "aws_eip" "utility" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.event_name}-utility-eip"
  })
}

resource "aws_eip_association" "utility" {
  allocation_id = aws_eip.utility.id
  instance_id   = aws_instance.utility.id
}

# =============================================================================
# OUTPUTS
# =============================================================================

output "utility_public_ip" {
  value = aws_eip.utility.public_ip
}

output "utility_private_ip" {
  value = aws_instance.utility.private_ip
}

output "utility_instance_id" {
  value = aws_instance.utility.id
}
