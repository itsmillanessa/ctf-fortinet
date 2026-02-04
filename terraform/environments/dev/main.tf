# =============================================================================
# DEV ENVIRONMENT — Full CTF Stack (Teams + CTFd + Utility Server)
# =============================================================================
# terraform apply -var="team_count=3"  → Deploys 3 FortiGate stacks + CTFd + Utility
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# =============================================================================
# VARIABLES
# =============================================================================

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "event_name" {
  type    = string
  default = "fortinet-ctf"
}

variable "team_count" {
  description = "Number of teams to deploy (1-10)"
  type        = number
  default     = 1

  validation {
    condition     = var.team_count >= 1 && var.team_count <= 10
    error_message = "Team count must be between 1 and 10."
  }
}

variable "fgt_ami" {
  description = "FortiGate AMI ID (PAYG or BYOL from AWS Marketplace)"
  type        = string
}

variable "key_name" {
  description = "EC2 SSH key pair name"
  type        = string
}

variable "admin_password" {
  description = "FortiGate admin password for all stacks"
  type        = string
  sensitive   = true
  default     = "FortinetCTF2026!"
}

variable "ctfd_admin_password" {
  description = "CTFd admin panel password"
  type        = string
  sensitive   = true
  default     = "CTFAdmin2026!"
}

variable "use_spot" {
  description = "Use spot instances for FortiGates"
  type        = bool
  default     = true
}

variable "admin_cidr" {
  description = "CIDR for admin access (your IP)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "deploy_ctfd" {
  description = "Deploy CTFd scoring platform"
  type        = bool
  default     = true
}

variable "deploy_utility" {
  description = "Deploy utility server (flag server + traffic gen)"
  type        = bool
  default     = true
}

variable "challenge_mode" {
  description = "Challenge mode: 'normal' or 'the_insider'"
  type        = string
  default     = "normal"
}

variable "deploy_fortianalyzer" {
  description = "Deploy FortiAnalyzer for Phase 2 challenges"
  type        = bool
  default     = false
}

variable "fortianalyzer_instance_type" {
  description = "FortiAnalyzer instance type"
  type        = string
  default     = "m5.large"
}

variable "faz_ami_id" {
  description = "FortiAnalyzer AMI ID (override for your marketplace subscription)"
  type        = string
  default     = ""
}

# =============================================================================
# CTF FLAGS — Unique per team, per challenge (hash-based, deterministic)
# =============================================================================

locals {
  team_flags = {
    for i in range(1, var.team_count + 1) : i => {
      # Challenge flags (match challenge IDs in flag server)
      recon             = "CTF{team${i}_recon_${substr(md5("recon-${i}-${var.event_name}"), 0, 8)}}"
      open_sesame       = "CTF{team${i}_dmz_breakout_${substr(md5("open_sesame-${i}-${var.event_name}"), 0, 8)}}"
      who_goes_there    = "CTF{team${i}_blocked_${substr(md5("who_goes_there-${i}-${var.event_name}"), 0, 8)}}"
      tunnel_vision     = "CTF{team${i}_vpn_master_${substr(md5("tunnel_vision-${i}-${var.event_name}"), 0, 8)}}"
      inspector_gadget  = "CTF{team${i}_security_pro_${substr(md5("inspector_gadget-${i}-${var.event_name}"), 0, 8)}}"
      the_insider       = "CTF{team${i}_troubleshooter_${substr(md5("the_insider-${i}-${var.event_name}"), 0, 8)}}"
      zero_trust        = "CTF{team${i}_zero_trust_${substr(md5("zero_trust-${i}-${var.event_name}"), 0, 8)}}"
    }
  }

  # Team configs for utility server (flag server needs to know team subnets/IPs)
  team_configs_for_utility = {
    for i in range(1, var.team_count + 1) : "team${i}" => {
      fgt_wan_ip  = module.network[i].fgt_wan_ip
      fgt_lan_ip  = module.network[i].fgt_lan_ip
      fgt_dmz_ip  = module.network[i].fgt_dmz_ip
      lan_subnet  = "10.${i}.2.0/24"
      dmz_subnet  = "10.${i}.3.0/24"
      wan_subnet  = "10.${i}.1.0/24"
      flags       = local.team_flags[i]
    }
  }
}

# =============================================================================
# TEAM STACKS (Network + FortiGate per team)
# =============================================================================

module "network" {
  source   = "../../modules/network"
  for_each = { for i in range(1, var.team_count + 1) : i => i }

  team_id    = each.value
  event_name = var.event_name
  aws_region = var.aws_region
}

module "fortigate" {
  source   = "../../modules/fortigate"
  for_each = { for i in range(1, var.team_count + 1) : i => i }

  team_id           = each.value
  event_name        = var.event_name
  vpc_id            = module.network[each.key].vpc_id
  wan_subnet_id     = module.network[each.key].wan_subnet_id
  lan_subnet_id     = module.network[each.key].lan_subnet_id
  dmz_subnet_id     = module.network[each.key].dmz_subnet_id
  fortigate_sg_id   = module.network[each.key].fortigate_sg_id
  fgt_wan_ip        = module.network[each.key].fgt_wan_ip
  fgt_lan_ip        = module.network[each.key].fgt_lan_ip
  fgt_dmz_ip        = module.network[each.key].fgt_dmz_ip
  fgt_ami           = var.fgt_ami
  key_name          = var.key_name
  admin_password    = var.admin_password
  admin_cidr        = var.admin_cidr
  use_spot          = var.use_spot
  ctf_flags         = local.team_flags[each.value]
  challenge_mode    = var.challenge_mode
  utility_server_ip = var.deploy_utility ? module.utility[0].utility_private_ip : ""
  faz_ip            = var.deploy_fortianalyzer ? module.fortianalyzer[0].fortianalyzer_public_ip : ""
  faz_serial        = ""  # FAZ will auto-discover
}

# =============================================================================
# UTILITY SERVER (Flag Server + Traffic Generator)
# =============================================================================

module "utility" {
  source = "../../modules/utility"
  count  = var.deploy_utility ? 1 : 0

  event_name   = var.event_name
  vpc_id       = "vpc-09f83d7c1bcf59913"       # General VPC
  subnet_id    = "subnet-06d0ca5397c5d9026"     # 172.31.1.0/24
  key_name     = var.key_name
  admin_cidr   = var.admin_cidr
  team_configs = local.team_configs_for_utility
}

# =============================================================================
# FORTIANALYZER (Phase 2 — Log Analytics & Incident Response)
# =============================================================================

module "fortianalyzer" {
  source = "../../modules/fortianalyzer"
  count  = var.deploy_fortianalyzer ? 1 : 0

  event_name    = var.event_name
  vpc_id        = "vpc-09f83d7c1bcf59913"
  subnet_id     = "subnet-06d0ca5397c5d9026"
  instance_type = var.fortianalyzer_instance_type
  key_name      = var.key_name
  admin_cidr    = var.admin_cidr
  team_configs  = local.team_configs_for_utility
  faz_ami_id    = var.faz_ami_id
}

# =============================================================================
# CTFd SCORING PLATFORM (Central — 1 instance)
# =============================================================================

module "ctfd" {
  source = "../../modules/ctfd"
  count  = var.deploy_ctfd ? 1 : 0

  event_name     = var.event_name
  aws_region     = var.aws_region
  key_name       = var.key_name
  admin_password = var.ctfd_admin_password
  team_count     = var.team_count

  create_vpc          = false
  existing_vpc_id     = "vpc-09f83d7c1bcf59913"
  existing_subnet_id  = "subnet-06d0ca5397c5d9026"

  team_flags = {
    for i in range(1, var.team_count + 1) : "team${i}" => local.team_flags[i]
  }

  team_fortigate_ips = {
    for i in range(1, var.team_count + 1) : "team${i}" => module.fortigate[i].fgt_public_ip
  }
}

# =============================================================================
# VPC PEERING — Connect team VPCs to utility server VPC
# =============================================================================
# The utility server needs to reach each team's FortiGate (for SSH validation)
# and teams need to reach the utility server (for flag endpoints)

resource "aws_vpc_peering_connection" "team_to_utility" {
  for_each = var.deploy_utility ? { for i in range(1, var.team_count + 1) : i => i } : {}

  vpc_id      = module.network[each.key].vpc_id          # Team VPC
  peer_vpc_id = "vpc-09f83d7c1bcf59913"                  # Utility/General VPC
  auto_accept = true

  tags = {
    Name      = "${var.event_name}-peer-team${each.value}-utility"
    Project   = var.event_name
    ManagedBy = "terraform"
  }
}

# Route from team WAN subnet to utility VPC
resource "aws_route" "team_to_utility" {
  for_each = var.deploy_utility ? { for i in range(1, var.team_count + 1) : i => i } : {}

  route_table_id            = module.network[each.key].wan_route_table_id
  destination_cidr_block    = "172.31.0.0/16"
  vpc_peering_connection_id = aws_vpc_peering_connection.team_to_utility[each.key].id
}

# Route from utility VPC to each team VPC
resource "aws_route" "utility_to_team" {
  for_each = var.deploy_utility ? { for i in range(1, var.team_count + 1) : i => i } : {}

  route_table_id            = data.aws_vpc.general.main_route_table_id
  destination_cidr_block    = "10.${each.value}.0.0/16"
  vpc_peering_connection_id = aws_vpc_peering_connection.team_to_utility[each.key].id
}

# Data source for general VPC route table
data "aws_vpc" "general" {
  id = "vpc-09f83d7c1bcf59913"
}

# Additional routes for FortiAnalyzer (if deployed)
# FortiAnalyzer needs to receive logs from all team FortiGates via syslog/FortiAnalyzer protocols

# =============================================================================
# OUTPUTS
# =============================================================================

# --- Utility Server ---
output "utility_server_ip" {
  description = "Utility server public IP (flag server + traffic gen)"
  value       = var.deploy_utility ? module.utility[0].utility_public_ip : "not deployed"
}

output "utility_server_private_ip" {
  description = "Utility server private IP (for VPC peering)"
  value       = var.deploy_utility ? module.utility[0].utility_private_ip : "not deployed"
}

# --- FortiAnalyzer (Phase 2) ---
output "fortianalyzer_ip" {
  description = "FortiAnalyzer public IP (Phase 2 log analysis)"
  value       = var.deploy_fortianalyzer ? module.fortianalyzer[0].fortianalyzer_public_ip : "not deployed"
}

output "fortianalyzer_url" {
  description = "FortiAnalyzer web interface URL"
  value       = var.deploy_fortianalyzer ? module.fortianalyzer[0].fortianalyzer_web_url : "not deployed"
}

output "fortianalyzer_admin_credentials" {
  description = "FortiAnalyzer admin credentials"
  value       = var.deploy_fortianalyzer ? module.fortianalyzer[0].fortianalyzer_admin_credentials : null
  sensitive   = true
}

# --- CTFd Portal ---
output "ctfd_url" {
  description = "CTFd scoring platform URL"
  value       = var.deploy_ctfd ? module.ctfd[0].ctfd_url : "not deployed"
}

output "ctfd_public_ip" {
  description = "CTFd server public IP"
  value       = var.deploy_ctfd ? module.ctfd[0].ctfd_public_ip : "not deployed"
}

# --- Team Access (safe to share with participants) ---
output "team_access" {
  description = "Team access information (share with participants)"
  value = {
    for i in range(1, var.team_count + 1) : "team${i}" => {
      # Phase 1 - FortiGate Access
      fortigate_url  = module.fortigate[i].fgt_admin_url
      fortigate_ip   = module.fortigate[i].fgt_public_ip
      admin_user     = "ctfplayer"
      admin_password = "CTFPlayer2026!"
      
      # Phase 2 - FortiAnalyzer Access (if deployed)
      fortianalyzer_url      = var.deploy_fortianalyzer ? module.fortianalyzer[0].fortianalyzer_web_url : "not deployed"
      fortianalyzer_user     = var.deploy_fortianalyzer ? "team${i}-analyst" : "not deployed"
      fortianalyzer_password = var.deploy_fortianalyzer ? "CTFteam${i}2026!" : "not deployed"
      
      # General CTF Access
      ctfd_team      = "Team ${i}"
      ctfd_password  = "team${i}ctf2026"
      ctfd_portal    = var.deploy_ctfd ? module.ctfd[0].ctfd_url : "not deployed"
      flag_server    = var.deploy_utility ? "http://${module.utility[0].utility_public_ip}:8080" : "not deployed"
    }
  }
}

# --- Admin Access (sensitive — all flags) ---
output "admin_access" {
  description = "Admin access with all flags (DO NOT share with participants)"
  sensitive   = true
  value = {
    for i in range(1, var.team_count + 1) : "team${i}" => {
      fortigate_url = module.fortigate[i].fgt_admin_url
      admin_user    = "admin"
      admin_pass    = var.admin_password
      flags         = local.team_flags[i]
    }
  }
}

# --- Quick Deploy Summary ---
output "deploy_summary" {
  description = "Quick deployment summary"
  value = {
    event             = var.event_name
    teams             = var.team_count
    challenge_mode    = var.challenge_mode
    phases_deployed   = var.deploy_fortianalyzer ? ["phase1", "phase2"] : ["phase1"]
    ctfd_url          = var.deploy_ctfd ? module.ctfd[0].ctfd_url : "not deployed"
    utility_ip        = var.deploy_utility ? module.utility[0].utility_public_ip : "not deployed"
    fortianalyzer_url = var.deploy_fortianalyzer ? module.fortianalyzer[0].fortianalyzer_web_url : "not deployed"
    fortigate_ips     = [for i in range(1, var.team_count + 1) : module.fortigate[i].fgt_public_ip]
    spot_enabled      = var.use_spot
    region            = var.aws_region
    
    # Phase breakdown
    phase1_ready      = true
    phase2_ready      = var.deploy_fortianalyzer
    total_challenges  = var.deploy_fortianalyzer ? 17 : 7  # 7 Phase 1 + 10 Phase 2
    total_points      = var.deploy_fortianalyzer ? 3850 : 1300  # 1300 Phase 1 + 2550 Phase 2
  }
}

# =============================================================================
# DNS MODULE — Route53 Records
# =============================================================================

variable "enable_dns" {
  description = "Enable Route53 DNS records"
  type        = bool
  default     = false
}

variable "dns_zone_name" {
  description = "Route53 zone name"
  type        = string
  default     = "senorthmx.com"
}

module "dns" {
  source = "../../modules/dns"
  count  = var.enable_dns ? 1 : 0

  event_name       = var.event_name
  zone_name        = var.dns_zone_name
  ctfd_ip          = var.deploy_ctfd ? module.ctfd[0].ctfd_public_ip : ""
  fortianalyzer_ip = var.deploy_fortianalyzer ? module.fortianalyzer[0].fortianalyzer_public_ip : ""
  utility_ip       = var.deploy_utility ? module.utility[0].utility_public_ip : ""
  
  fortigate_ips = {
    for i in range(1, var.team_count + 1) : "team${i}" => module.fortigate[i].fgt_public_ip
  }
}

output "dns_urls" {
  description = "DNS URLs for all components"
  value       = var.enable_dns ? module.dns[0].all_urls : null
}
