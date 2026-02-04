# =============================================================================
# FORTIGATE MODULE — FortiGate VM deployment per team
# =============================================================================
# Deploys a FortiGate VM with:
# - 3 NICs (WAN, LAN, DMZ)
# - Bootstrap config with team-specific settings
# - Elastic IP for management access
# - IAM role for FortiGate cloud integration
# =============================================================================

variable "team_id" {
  type = number
}

variable "team_name" {
  type    = string
  default = ""
}

variable "event_name" {
  type    = string
  default = "fortinet-ctf"
}

variable "vpc_id" {
  type = string
}

variable "wan_subnet_id" {
  type = string
}

variable "lan_subnet_id" {
  type = string
}

variable "dmz_subnet_id" {
  type = string
}

variable "fortigate_sg_id" {
  type = string
}

variable "fgt_wan_ip" {
  type = string
}

variable "fgt_lan_ip" {
  type = string
}

variable "fgt_dmz_ip" {
  type = string
}

variable "instance_type" {
  description = "EC2 instance type for FortiGate"
  type        = string
  default     = "c5.large"
}

variable "use_spot" {
  description = "Use spot instances for cost savings"
  type        = bool
  default     = true
}

variable "spot_price" {
  description = "Maximum spot price (USD/hr)"
  type        = string
  default     = "0.10"
}

variable "fgt_ami" {
  description = "FortiGate AMI ID (PAYG or BYOL)"
  type        = string
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
}

variable "admin_password" {
  description = "FortiGate admin password"
  type        = string
  sensitive   = true
  default     = "FortineCTF2026!"
}

variable "admin_cidr" {
  description = "CIDR allowed for admin access"
  type        = string
  default     = "0.0.0.0/0"
}

variable "ctf_flags" {
  description = "Map of flag names to flag values to embed in config"
  type        = map(string)
  default     = {}
}

variable "challenge_mode" {
  description = "Challenge mode: 'normal' or 'the_insider' (plants broken config)"
  type        = string
  default     = "normal"
}

variable "utility_server_ip" {
  description = "IP of the utility server (flag server + traffic gen)"
  type        = string
  default     = ""
}

variable "faz_ip" {
  description = "FortiAnalyzer IP for log forwarding (Phase 2)"
  type        = string
  default     = ""
}

variable "faz_serial" {
  description = "FortiAnalyzer serial number for registration"
  type        = string
  default     = ""
}

locals {
  team_label = var.team_name != "" ? var.team_name : "team-${var.team_id}"
  hostname   = "CTF-${upper(local.team_label)}-FGT"

  common_tags = {
    Project   = var.event_name
    Team      = local.team_label
    TeamID    = var.team_id
    ManagedBy = "terraform"
    Component = "fortigate"
  }
}

# --- FortiGate Bootstrap Config ---
data "template_file" "fgt_config" {
  template = file("${path.module}/templates/fgt_bootstrap.conf")

  vars = {
    hostname       = local.hostname
    admin_password = var.admin_password
    wan_ip         = var.fgt_wan_ip
    wan_mask       = "255.255.255.0"
    wan_gw         = cidrhost(cidrsubnet("10.${var.team_id}.0.0/16", 8, 1), 1)
    lan_ip         = var.fgt_lan_ip
    lan_mask       = "255.255.255.0"
    dmz_ip         = var.fgt_dmz_ip
    dmz_mask       = "255.255.255.0"
    admin_cidr     = var.admin_cidr
    team_id        = var.team_id
    team_name      = local.team_label
    # Flags embedded in config (for flag-hunt challenges)
    flag_recon     = lookup(var.ctf_flags, "recon", "CTF{recon_flag_not_set}")
    flag_config    = join("\n", [for k, v in var.ctf_flags : "# CTF_FLAG_${k}: ${v}"])
    # Broken config for "The Insider" challenge
    broken_config  = var.challenge_mode == "the_insider" ? file("${path.module}/templates/broken_config.conf") : ""
    # FortiAnalyzer config (Phase 2)
    faz_ip         = var.faz_ip
    faz_serial     = var.faz_serial
  }
}

# --- Network Interfaces ---
resource "aws_network_interface" "wan" {
  subnet_id         = var.wan_subnet_id
  private_ips       = [var.fgt_wan_ip]
  security_groups   = [var.fortigate_sg_id]
  source_dest_check = false

  tags = merge(local.common_tags, {
    Name = "${var.event_name}-${local.team_label}-fgt-wan"
  })
}

resource "aws_network_interface" "lan" {
  subnet_id         = var.lan_subnet_id
  private_ips       = [var.fgt_lan_ip]
  security_groups   = [var.fortigate_sg_id]
  source_dest_check = false

  tags = merge(local.common_tags, {
    Name = "${var.event_name}-${local.team_label}-fgt-lan"
  })
}

resource "aws_network_interface" "dmz" {
  subnet_id         = var.dmz_subnet_id
  private_ips       = [var.fgt_dmz_ip]
  security_groups   = [var.fortigate_sg_id]
  source_dest_check = false

  tags = merge(local.common_tags, {
    Name = "${var.event_name}-${local.team_label}-fgt-dmz"
  })
}

# --- Elastic IP (management access) ---
resource "aws_eip" "fgt" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.event_name}-${local.team_label}-fgt-eip"
  })
}

resource "aws_eip_association" "fgt" {
  allocation_id        = aws_eip.fgt.id
  network_interface_id = aws_network_interface.wan.id
}

# --- FortiGate EC2 Instance ---
# Using on-demand with spot market request via launch template
# (spot_instance_request doesn't support network_card_index)

resource "aws_instance" "fgt" {
  ami           = var.fgt_ami
  instance_type = var.instance_type
  key_name      = var.key_name
  user_data     = data.template_file.fgt_config.rendered

  instance_market_options {
    market_type = var.use_spot ? "spot" : null
    dynamic "spot_options" {
      for_each = var.use_spot ? [1] : []
      content {
        max_price          = var.spot_price
        spot_instance_type = "one-time"
      }
    }
  }

  network_interface {
    network_interface_id = aws_network_interface.wan.id
    device_index         = 0
  }

  network_interface {
    network_interface_id = aws_network_interface.lan.id
    device_index         = 1
  }

  network_interface {
    network_interface_id = aws_network_interface.dmz.id
    device_index         = 2
  }

  tags = merge(local.common_tags, {
    Name = "${var.event_name}-${local.team_label}-fgt"
  })
}

# =============================================================================
# OUTPUTS
# =============================================================================

output "fgt_public_ip" {
  value = aws_eip.fgt.public_ip
}

output "fgt_instance_id" {
  value = aws_instance.fgt.id
}

output "fgt_wan_eni" {
  value = aws_network_interface.wan.id
}

output "fgt_hostname" {
  value = local.hostname
}

output "fgt_admin_url" {
  value = "https://${aws_eip.fgt.public_ip}"
}
