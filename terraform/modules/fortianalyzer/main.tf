# =============================================================================
# FORTIANALYZER MODULE — Shared FAZ with ADOMs for Multi-Team CTF
# =============================================================================
# Single FortiAnalyzer instance serving all teams via Administrative Domains:
# - 1 ADOM per team (isolated log storage)
# - Team-specific analyst users
# - API-driven ADOM/user provisioning post-deploy
# - Supports up to 10 ADOMs (AWS PAYG license)
# =============================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}

# ─── Local Variables ───────────────────────────────────────────────────

locals {
  common_tags = {
    Project   = var.event_name
    ManagedBy = "terraform"
    Component = "fortianalyzer"
    Phase     = "phase2"
  }

  # Use provided AMI or default to latest FortiAnalyzer PAYG
  faz_ami_id = var.faz_ami_id != "" ? var.faz_ami_id : data.aws_ami.fortianalyzer[0].id

  # Generate team ADOMs config for post-deploy provisioning
  team_adoms = {
    for team_id, config in var.team_configs : team_id => {
      adom_name = "ADOM-${team_id}"
      analyst_user = "${team_id}-analyst"
      analyst_password = "CTF${team_id}2026!"
      fortigate_ip = config.fgt_wan_ip
      flags = config.flags
    }
  }
}

# ─── Data Sources ──────────────────────────────────────────────────────

data "aws_ami" "fortianalyzer" {
  count       = var.faz_ami_id == "" ? 1 : 0
  most_recent = true
  owners      = ["679593333241"] # Fortinet

  filter {
    name   = "name"
    values = ["FortiAnalyzer-VM64-AWSONDEMAND*"]
  }
}

data "aws_subnet" "selected" {
  id = var.subnet_id
}

data "aws_availability_zone" "current" {
  name = data.aws_subnet.selected.availability_zone
}

# ─── Security Group ────────────────────────────────────────────────────

resource "aws_security_group" "fortianalyzer" {
  name_prefix = "${var.event_name}-faz-"
  vpc_id      = var.vpc_id
  description = "FortiAnalyzer security group for CTF Phase 2"

  # HTTPS Web UI
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
    description = "HTTPS Web UI"
  }

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
    description = "SSH CLI access"
  }

  # FortiGate log reception (TCP)
  ingress {
    from_port   = 514
    to_port     = 514
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Syslog TCP from FortiGates"
  }

  # FortiGate log reception (UDP)
  ingress {
    from_port   = 514
    to_port     = 514
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Syslog UDP from FortiGates"
  }

  # FortiAnalyzer protocol
  ingress {
    from_port   = 541
    to_port     = 541
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "FAZ protocol"
  }

  # Log aggregation
  ingress {
    from_port   = 1514
    to_port     = 1514
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Log aggregation"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(local.common_tags, {
    Name = "${var.event_name}-faz-sg"
  })
}

# ─── IAM Role for S3 Access ────────────────────────────────────────────

resource "aws_iam_role" "fortianalyzer" {
  name_prefix = "${var.event_name}-faz-"

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

resource "aws_iam_role_policy" "fortianalyzer_s3" {
  name = "s3-config"
  role = aws_iam_role.fortianalyzer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:ListBucket"]
      Resource = [
        aws_s3_bucket.config.arn,
        "${aws_s3_bucket.config.arn}/*"
      ]
    }]
  })
}

resource "aws_iam_instance_profile" "fortianalyzer" {
  name_prefix = "${var.event_name}-faz-"
  role        = aws_iam_role.fortianalyzer.name
}

# ─── S3 Bucket for Config & Seed Data ──────────────────────────────────

resource "aws_s3_bucket" "config" {
  bucket_prefix = "${var.event_name}-faz-config-"
  force_destroy = true
  tags          = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "config" {
  bucket                  = aws_s3_bucket.config.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bootstrap config for ADOM setup (used by post-deploy script)
resource "aws_s3_object" "adom_config" {
  bucket  = aws_s3_bucket.config.id
  key     = "adom_config.json"
  content = jsonencode({
    admin_password = var.custom_admin_password != "" ? var.custom_admin_password : "FortiCTF2026!"
    enable_adoms   = true
    teams          = local.team_adoms
    timestamp      = timestamp()
  })

  tags = merge(local.common_tags, {
    Purpose = "ADOM provisioning config"
  })
}

# Seed data for Phase 2 challenges
resource "aws_s3_object" "seed_data" {
  bucket  = aws_s3_bucket.config.id
  key     = "seed_logs.json"
  content = jsonencode({
    description = "Pre-seeded log data for CTF Phase 2 analytical challenges"
    teams       = keys(var.team_configs)
    log_volume  = "48h_preload"
    timestamp   = timestamp()
    seed_config = {
      # APT campaign indicators for each team
      apt_campaigns = [
        for team_id, config in var.team_configs : {
          team_id     = team_id
          campaign_id = "${substr(md5(team_id), 0, 4)}-${team_id}-APT"
          indicators = {
            source_ips = ["198.51.100.10", "198.51.100.20", "198.51.100.30"]
            domains    = ["evil-domain.com", "exfil.evil-domain.com"]
            files      = ["svchost32.exe", "system.dll", "update.scr"]
          }
          timeline = {
            reconnaissance = "08:30:00"
            initial_access = "10:15:00"
            persistence    = "12:45:00"
            exfiltration   = "14:23:00"
          }
        }
      ]
      # DNS tunneling data
      dns_tunneling = {
        domain_pattern   = "*.exfil.evil-domain.com"
        data_exfiltrated = "sensitive_financial_data_q3_results_complete_database_export_with_customer_information_and_payment_details_accounting_records_full_backup_2026_including_transaction_histories_user_profiles_authentication_tokens_session_data_encrypted_passwords_and_personal_identifiable_information_extracted_from_production_systems"
        chunks_count     = 21
      }
      # Behavioral anomalies
      behavioral_anomalies = {
        compromised_users = ["jsmith", "mgarcia", "rjohnson", "alopez", "pchen", "lwilliams"]
        anomaly_patterns  = ["off_hours_access", "unusual_file_access", "privilege_escalation"]
      }
    }
  })

  tags = merge(local.common_tags, {
    Purpose = "Phase 2 seed data"
  })
}

# ─── EC2 Instance ──────────────────────────────────────────────────────

resource "aws_instance" "fortianalyzer" {
  ami                    = local.faz_ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.fortianalyzer.id]
  iam_instance_profile   = aws_iam_instance_profile.fortianalyzer.name

  # Note: FortiAnalyzer marketplace AMIs require manual EULA acceptance
  # on first boot. For production, use a pre-configured AMI or accept
  # via EC2 Serial Console.
  #
  # ADOM and user provisioning is done post-deploy via API.

  tags = merge(local.common_tags, {
    Name = "${var.event_name}-fortianalyzer"
    Role = "log-analysis"
    Architecture = "shared-adom"
  })

  lifecycle {
    create_before_destroy = false
  }
}

# ─── Elastic IP ────────────────────────────────────────────────────────

resource "aws_eip" "fortianalyzer" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.event_name}-fortianalyzer-eip"
  })
}

resource "aws_eip_association" "fortianalyzer" {
  allocation_id = aws_eip.fortianalyzer.id
  instance_id   = aws_instance.fortianalyzer.id
}

# ─── Route53 DNS (Optional) ─────────────────────────────────────────────

data "aws_route53_zone" "main" {
  count = var.enable_dns_record ? 1 : 0
  name  = var.dns_zone_name
}

resource "aws_route53_record" "fortianalyzer" {
  count   = var.enable_dns_record ? 1 : 0
  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = "faz-${var.event_name}"
  type    = "A"
  ttl     = 300
  records = [aws_eip.fortianalyzer.public_ip]
}

# ─── Null Resource for Post-Deploy ADOM Provisioning ───────────────────

resource "null_resource" "provision_adoms" {
  count = var.auto_provision_adoms ? 1 : 0

  depends_on = [aws_eip_association.fortianalyzer]

  triggers = {
    team_config_hash = sha256(jsonencode(var.team_configs))
    faz_ip           = aws_eip.fortianalyzer.public_ip
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for FortiAnalyzer to be ready..."
      sleep 120  # Wait for FAZ to boot and accept EULA manually
      
      echo "ADOM provisioning requires manual setup or pre-configured AMI."
      echo "FAZ IP: ${aws_eip.fortianalyzer.public_ip}"
      echo "Admin Password: ${var.custom_admin_password != "" ? var.custom_admin_password : "FortiCTF2026!"}"
      echo ""
      echo "To enable ADOMs manually:"
      echo "1. Login to https://${aws_eip.fortianalyzer.public_ip}"
      echo "2. Go to System Settings > All ADOMs"
      echo "3. Enable ADOM mode"
      echo "4. Create ADOMs for each team"
      echo ""
      echo "ADOM config saved to S3: s3://${aws_s3_bucket.config.id}/adom_config.json"
    EOT
  }
}
