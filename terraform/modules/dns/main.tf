# =============================================================================
# DNS MODULE — Route53 Records for CTF Components
# =============================================================================
# Creates friendly DNS names like:
#   ctf.senorthmx.com           → CTFd Portal
#   faz.senorthmx.com           → FortiAnalyzer
#   fortigate.team1.senorthmx.com → FortiGate Team 1
#   fortigate.team2.senorthmx.com → FortiGate Team 2
# =============================================================================

variable "event_name" {
  type    = string
  default = "ctf"
}

variable "zone_name" {
  type    = string
  default = "senorthmx.com"
}

variable "ctfd_ip" {
  type    = string
  default = ""
}

variable "fortigate_ips" {
  type    = map(string)
  default = {}
}

variable "fortianalyzer_ip" {
  type    = string
  default = ""
}

variable "utility_ip" {
  type    = string
  default = ""
}

variable "ttl" {
  type    = number
  default = 60
}

variable "enabled" {
  type    = bool
  default = true
}

# ─── Data Sources ──────────────────────────────────────────────────────

data "aws_route53_zone" "main" {
  count = var.enabled ? 1 : 0
  name  = var.zone_name
}

# ─── CTFd Portal: ctf.senorthmx.com ────────────────────────────────────

resource "aws_route53_record" "ctfd" {
  count   = var.enabled && var.ctfd_ip != "" ? 1 : 0
  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = "ctf"
  type    = "A"
  ttl     = var.ttl
  records = [var.ctfd_ip]
}

# ─── FortiAnalyzer: faz.senorthmx.com ──────────────────────────────────

resource "aws_route53_record" "fortianalyzer" {
  count   = var.enabled && var.fortianalyzer_ip != "" ? 1 : 0
  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = "faz"
  type    = "A"
  ttl     = var.ttl
  records = [var.fortianalyzer_ip]
}

# ─── FortiGates: fortigate.team1.senorthmx.com ─────────────────────────

resource "aws_route53_record" "fortigate" {
  for_each = var.enabled ? var.fortigate_ips : {}
  zone_id  = data.aws_route53_zone.main[0].zone_id
  name     = "fortigate.${each.key}"
  type     = "A"
  ttl      = var.ttl
  records  = [each.value]
}

# ─── Utility: flags.senorthmx.com ──────────────────────────────────────

resource "aws_route53_record" "utility" {
  count   = var.enabled && var.utility_ip != "" ? 1 : 0
  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = "flags"
  type    = "A"
  ttl     = var.ttl
  records = [var.utility_ip]
}

# ─── Outputs ───────────────────────────────────────────────────────────

output "all_urls" {
  description = "All CTF URLs"
  value = {
    ctfd           = var.ctfd_ip != "" ? "http://ctf.${var.zone_name}" : null
    fortianalyzer  = var.fortianalyzer_ip != "" ? "https://faz.${var.zone_name}" : null
    flags_server   = var.utility_ip != "" ? "http://flags.${var.zone_name}:8080" : null
    fortigates     = { 
      for k, v in var.fortigate_ips : k => "https://fortigate.${k}.${var.zone_name}" 
    }
  }
}

output "team_urls" {
  description = "URLs organized by team"
  value = {
    for team_id, ip in var.fortigate_ips : team_id => {
      fortigate = "https://fortigate.${team_id}.${var.zone_name}"
      ctfd      = "http://ctf.${var.zone_name}"
      faz       = "https://faz.${var.zone_name}"
    }
  }
}
