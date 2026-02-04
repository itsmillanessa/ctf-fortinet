# =============================================================================
# FORTIANALYZER MODULE OUTPUTS — Shared ADOM Architecture
# =============================================================================

output "fortianalyzer_instance_id" {
  description = "FortiAnalyzer EC2 instance ID"
  value       = aws_instance.fortianalyzer.id
}

output "fortianalyzer_public_ip" {
  description = "FortiAnalyzer public IP address"
  value       = aws_eip.fortianalyzer.public_ip
}

output "fortianalyzer_private_ip" {
  description = "FortiAnalyzer private IP address"
  value       = aws_instance.fortianalyzer.private_ip
}

output "fortianalyzer_web_url" {
  description = "FortiAnalyzer web interface URL"
  value       = "https://${aws_eip.fortianalyzer.public_ip}"
}

output "fortianalyzer_admin_credentials" {
  description = "FortiAnalyzer admin login credentials"
  value = {
    url      = "https://${aws_eip.fortianalyzer.public_ip}"
    username = "admin"
    password = var.custom_admin_password != "" ? var.custom_admin_password : "FortiCTF2026!"
  }
  sensitive = false  # Intentionally not sensitive for CTF use
}

output "fortianalyzer_security_group_id" {
  description = "Security group ID for FortiAnalyzer"
  value       = aws_security_group.fortianalyzer.id
}

output "config_bucket" {
  description = "S3 bucket containing FAZ configuration"
  value       = aws_s3_bucket.config.id
}

# ─── ADOM Architecture Outputs ─────────────────────────────────────────

output "adom_architecture" {
  description = "ADOM architecture summary"
  value = {
    type        = "shared"
    max_adoms   = 10
    teams       = keys(var.team_configs)
    team_count  = length(var.team_configs)
  }
}

output "team_adoms" {
  description = "ADOM configuration for each team"
  value = {
    for team_id, config in var.team_configs : team_id => {
      adom_name        = "ADOM-${team_id}"
      analyst_user     = "${team_id}-analyst"
      analyst_password = "CTF${team_id}2026!"
      fortigate_ip     = config.fgt_wan_ip
    }
  }
}

output "adom_setup_instructions" {
  description = "Instructions for setting up ADOMs"
  value = <<-EOT
    
    ╔══════════════════════════════════════════════════════════════════╗
    ║           FortiAnalyzer ADOM Setup Instructions                  ║
    ╠══════════════════════════════════════════════════════════════════╣
    ║                                                                  ║
    ║  1. Login to FAZ: https://${aws_eip.fortianalyzer.public_ip}     ║
    ║     User: admin                                                  ║
    ║     Pass: ${var.custom_admin_password != "" ? var.custom_admin_password : "FortiCTF2026!"}                                          ║
    ║                                                                  ║
    ║  2. Enable ADOMs:                                                ║
    ║     System Settings > Admin Settings > Admin Domain Mode: Enable ║
    ║                                                                  ║
    ║  3. Create ADOMs for each team:                                  ║
%{for team_id, config in var.team_configs~}
    ║     - ADOM-${team_id} (FortiGate: ${config.fgt_wan_ip})          ║
%{endfor~}
    ║                                                                  ║
    ║  4. Create analyst users in each ADOM                            ║
    ║                                                                  ║
    ║  Config saved to: s3://${aws_s3_bucket.config.id}/adom_config.json
    ║                                                                  ║
    ╚══════════════════════════════════════════════════════════════════╝
  EOT
}

# ─── Cost Estimate ─────────────────────────────────────────────────────

output "cost_estimate" {
  description = "Estimated hourly cost for shared FAZ architecture"
  value = {
    instance_type      = var.instance_type
    hourly_cost_usd    = var.instance_type == "m5.2xlarge" ? 0.384 : 0.192
    monthly_cost_usd   = var.instance_type == "m5.2xlarge" ? 280 : 140
    teams_supported    = length(var.team_configs)
    cost_per_team_usd  = length(var.team_configs) > 0 ? (var.instance_type == "m5.2xlarge" ? 280 : 140) / length(var.team_configs) : 0
    savings_vs_individual = "${length(var.team_configs) > 1 ? (length(var.team_configs) - 1) * 100 / length(var.team_configs) : 0}%"
    note               = "Shared ADOM architecture: 1 FAZ for all teams"
  }
}
