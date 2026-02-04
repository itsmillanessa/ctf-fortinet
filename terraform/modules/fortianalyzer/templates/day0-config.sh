#!/bin/bash
# FortiAnalyzer Day-0 Configuration Script
# CTF Fortinet - Phase 2 Setup

set -euo pipefail

LOG_FILE="/var/log/ctf-day0-config.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== FortiAnalyzer CTF Day-0 Configuration Started ==="
echo "Event: ${event_name}"
echo "Timestamp: $(date)"
echo "Teams configured: ${length(team_configs)}"

# Wait for FortiAnalyzer to be fully ready
echo "Waiting for FortiAnalyzer to be ready..."
sleep 60

# Function to execute FortiAnalyzer CLI commands
faz_cli() {
    local cmd="$1"
    echo "Executing: $cmd"
    
    # Use expect to automate CLI interaction
    expect << EOF
spawn ssh -o StrictHostKeyChecking=no admin@127.0.0.1
expect "Password:"
send "FortiCTF2026!\r"
expect "# "
send "$cmd\r"
expect "# "
send "exit\r"
expect eof
EOF
}

# Install expect if not present
if ! command -v expect &> /dev/null; then
    echo "Installing expect..."
    yum update -y
    yum install -y expect
fi

# Configure log retention policies for CTF
echo "Configuring log retention policies..."
faz_cli "config log-storage policy
edit ctf-retention
set max-log-age 7
set max-log-age-unit day
set device all
next
end"

# Set up automated log processing for CTF challenges
echo "Setting up automated log processing..."

# Create pre-seeded log entries for consistent challenge flags
echo "Creating pre-seeded log data..."

cat > /tmp/seed_logs.sql << 'EOF'
-- APT Campaign Log Entries
%{ for team_id, config in team_configs ~}
INSERT INTO logs_${team_id} (timestamp, source_ip, dest_ip, action, attack_type, severity, campaign_id) VALUES
('2026-01-31 08:30:00', '198.51.100.10', '${config.fgt_wan_ip}', 'scan', 'Port Scan', 'medium', '3071-${team_id}-APT'),
('2026-01-31 10:15:00', '198.51.100.10', '${config.fgt_wan_ip}', 'exploit', 'Code Injection', 'high', '3071-${team_id}-APT'),
('2026-01-31 12:45:00', '198.51.100.10', '${config.fgt_wan_ip}', 'persistence', 'Registry Modification', 'high', '3071-${team_id}-APT'),
('2026-01-31 14:23:00', '198.51.100.10', '${config.fgt_wan_ip}', 'exfiltration', 'Data Transfer', 'critical', '3071-${team_id}-APT');

-- DNS Tunneling Entries (21 unique subdomain chunks)
INSERT INTO dns_logs_${team_id} (timestamp, source_ip, query, query_type, response) VALUES
%{ for chunk_num in range(21) ~}
('2026-01-31 15:${format("%02d", chunk_num + 10)}:00', '${config.fgt_lan_ip}', '73656e7369746976655f66696e616e6369616c5f646174615f${format("%02d", chunk_num)}.exfil.evil-domain.com', 'A', 'NXDOMAIN')${chunk_num < 20 ? "," : ";"}
%{ endfor ~}

-- Behavioral Anomaly Entries
INSERT INTO user_logs_${team_id} (timestamp, username, action, source_ip, anomaly_score) VALUES
('2026-01-31 03:47:00', 'jsmith', 'login', '${config.fgt_lan_ip}', 95),
('2026-01-31 23:15:00', 'mgarcia', 'file_access', '${config.fgt_lan_ip}', 87),
('2026-01-31 02:30:00', 'rjohnson', 'privilege_escalation', '${config.fgt_lan_ip}', 92);

-- IOC Entries for Comandante de Incidentes
INSERT INTO iocs_${team_id} (ioc_type, ioc_value, first_seen, last_seen, confidence) VALUES
('ip', '198.51.100.10', '2026-01-31 08:30:00', '2026-01-31 14:23:00', 'high'),
('ip', '198.51.100.20', '2026-01-31 08:35:00', '2026-01-31 14:20:00', 'high'),
('ip', '198.51.100.30', '2026-01-31 08:40:00', '2026-01-31 14:18:00', 'medium'),
('domain', 'evil-domain.com', '2026-01-31 15:10:00', '2026-01-31 15:30:00', 'high'),
('domain', 'exfil.evil-domain.com', '2026-01-31 15:10:00', '2026-01-31 15:30:00', 'critical'),
('file', 'svchost32.exe', '2026-01-31 12:45:00', '2026-01-31 12:45:00', 'high'),
('file', 'system.dll', '2026-01-31 12:46:00', '2026-01-31 12:46:00', 'medium'),
('file', 'update.scr', '2026-01-31 12:47:00', '2026-01-31 12:47:00', 'medium'),
('registry', 'HKLM\\Software\\Microsoft\\Windows\\CurrentVersion\\Run\\SecurityUpdate', '2026-01-31 12:45:00', '2026-01-31 12:45:00', 'high'),
('user', 'jsmith', '2026-01-31 03:47:00', '2026-01-31 03:47:00', 'high'),
('user', 'mgarcia', '2026-01-31 23:15:00', '2026-01-31 23:15:00', 'medium');

%{ endfor ~}
EOF

echo "Seeded log data created for ${length(team_configs)} teams"

# Configure FortiAnalyzer reports for CTF challenges
echo "Configuring CTF-specific reports..."

# Create custom dashboard for each team
%{ for team_id, config in team_configs ~}
echo "Configuring dashboard for ${team_id}..."

faz_cli "config report layout
edit ${team_id}-dashboard
set title 'CTF ${team_id} Security Analysis Dashboard'
set type dashboard
set device ${team_id}
next
end"

faz_cli "config report dataset
edit ${team_id}-security-events
set query 'SELECT * FROM logs WHERE device = \"${team_id}\" AND timestamp >= DATE_SUB(NOW(), INTERVAL 24 HOUR)'
set policy device-based
next
end"

%{ endfor ~}

# Set up automated backup of configurations
echo "Setting up configuration backup..."
faz_cli "config system backup all-settings
edit ctf-backup
set status enable
set hour 2
set minute 0
set destination disk
next
end"

# Configure system maintenance
echo "Configuring system maintenance..."
faz_cli "config system maintenance
edit ctf-maintenance
set status enable
set hour 3
set minute 0
set day sunday
next
end"

# Create challenge-specific log views
echo "Creating challenge-specific log views..."

# View for "Primera Vista" challenge
faz_cli "config log logview
edit primera-vista-view
set title 'Security Logs - Last 24h'
set filter 'severity >= warning AND timestamp >= DATE_SUB(NOW(), INTERVAL 24 HOUR)'
set columns 'timestamp,source,destination,action,attack_type,severity'
next
end"

# View for "Filtro Maestro" challenge  
faz_cli "config log logview
edit filtro-maestro-view
set title 'Port Scan Analysis'
set filter 'attack_type = \"Port Scan\"'
set group-by source
set sort-order count_desc
next
end"

# View for "Timeline Master" challenge
faz_cli "config log logview
edit timeline-master-view
set title 'APT Campaign Timeline'
set filter 'campaign_id LIKE \"%APT\"'
set sort-order timestamp_asc
set columns 'timestamp,action,attack_type,source,campaign_id'
next
end"

# Configure alerting for real-time analysis
echo "Configuring real-time alerting..."
faz_cli "config alertemail setting
set status enable
set server 127.0.0.1
set port 25
next
end"

# Create API access for flag server integration
echo "Configuring API access..."
faz_cli "config system api-user
edit ctf-flag-server
set api-key 'CTF-FAZ-API-2026'
set accprofile super_admin
set vdom root
set trusthost1 0.0.0.0 0.0.0.0
set comments 'CTF Flag Server API Access'
next
end"

# Final system optimization
echo "Optimizing system performance for CTF..."
faz_cli "config log disk setting
set max-log-files 1000
set max-log-file-size 50
next
end"

faz_cli "config system performance
set max-log-forward-rate 10000
set max-log-device-quota 1000
next
end"

# Restart services to apply all changes
echo "Restarting FortiAnalyzer services..."
faz_cli "execute reboot"

echo "=== FortiAnalyzer CTF Day-0 Configuration Completed ==="
echo "Dashboard URL: https://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "Admin credentials: admin / FortiCTF2026!"
echo "Teams configured: ${join(", ", keys(team_configs))}"
echo "Log retention: 7 days"
echo "API access configured for flag server integration"
echo "Configuration completed at: $(date)"