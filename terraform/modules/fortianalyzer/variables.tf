# =============================================================================
# FORTIANALYZER MODULE VARIABLES — Shared ADOM Architecture
# =============================================================================

variable "event_name" {
  description = "Name of the CTF event"
  type        = string
  default     = "fortinet-ctf"
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.event_name))
    error_message = "Event name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "vpc_id" {
  description = "VPC ID where FortiAnalyzer will be deployed"
  type        = string
  
  validation {
    condition     = can(regex("^vpc-[a-z0-9]+$", var.vpc_id))
    error_message = "VPC ID must be a valid AWS VPC ID format."
  }
}

variable "subnet_id" {
  description = "Subnet ID for FortiAnalyzer deployment"
  type        = string
  
  validation {
    condition     = can(regex("^subnet-[a-z0-9]+$", var.subnet_id))
    error_message = "Subnet ID must be a valid AWS subnet ID format."
  }
}

variable "instance_type" {
  description = "EC2 instance type for FortiAnalyzer (shared instance for all teams)"
  type        = string
  default     = "m5.2xlarge"  # 8 vCPU, 32GB - handles up to 10 teams
  
  validation {
    condition = contains([
      "m5.xlarge", "m5.2xlarge", "m5.4xlarge",
      "c5.xlarge", "c5.2xlarge", "c5.4xlarge",
      "r5.xlarge", "r5.2xlarge", "r5.4xlarge"
    ], var.instance_type)
    error_message = "Instance type must be a supported EC2 instance type for FortiAnalyzer."
  }
}

variable "key_name" {
  description = "EC2 Key Pair name for SSH access"
  type        = string
  
  validation {
    condition     = length(var.key_name) > 0
    error_message = "Key name cannot be empty."
  }
}

variable "team_configs" {
  description = "Configuration for each CTF team (used for ADOM creation)"
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
  
  validation {
    condition     = length(var.team_configs) <= 10
    error_message = "Maximum 10 teams supported per FortiAnalyzer instance (ADOM limit)."
  }
}

variable "admin_cidr" {
  description = "CIDR block for administrative access to FortiAnalyzer"
  type        = string
  default     = "0.0.0.0/0"
  
  validation {
    condition     = can(cidrhost(var.admin_cidr, 0))
    error_message = "Admin CIDR must be a valid CIDR notation."
  }
}

variable "faz_ami_id" {
  description = "Override AMI ID for FortiAnalyzer (use your subscribed Marketplace product)"
  type        = string
  default     = ""
}

variable "custom_admin_password" {
  description = "Custom admin password (default: FortiCTF2026!)"
  type        = string
  default     = ""
  sensitive   = true
  
  validation {
    condition     = var.custom_admin_password == "" || length(var.custom_admin_password) >= 8
    error_message = "Custom admin password must be at least 8 characters long."
  }
}

variable "enable_dns_record" {
  description = "Create Route53 DNS record for FortiAnalyzer"
  type        = bool
  default     = false
}

variable "dns_zone_name" {
  description = "Route53 zone name for DNS record creation"
  type        = string
  default     = "itsmillan.com"
}

variable "auto_provision_adoms" {
  description = "Attempt to auto-provision ADOMs (requires manual EULA acceptance first)"
  type        = bool
  default     = false
}

variable "timezone" {
  description = "Timezone for FortiAnalyzer system"
  type        = string
  default     = "America/Monterrey"
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
