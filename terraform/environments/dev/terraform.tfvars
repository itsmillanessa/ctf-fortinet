aws_region          = "us-east-1"
event_name          = "forti-ctf-test"
team_count          = 1
fgt_ami             = "ami-0a868b222f973e16b"
key_name            = "amillan"
admin_password      = "FortinetCTF2026!"
ctfd_admin_password = "CTFAdmin2026!"
use_spot            = true
admin_cidr          = "0.0.0.0/0"

# Phase Deployment
deploy_ctfd           = true
deploy_utility        = true
deploy_fortianalyzer  = true

fortianalyzer_instance_type = "m5.2xlarge"
challenge_mode = "normal"

# FortiAnalyzer AMI (PAYG basic - your subscribed product)
faz_ami_id = "ami-06916af9d2d512513"

# DNS Configuration (disabled - domain expired)
enable_dns = false
dns_zone_name = "senorthmx.com"
