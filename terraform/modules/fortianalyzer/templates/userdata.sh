#!/bin/bash
# FortiAnalyzer EC2 Instance User Data Script
# CTF Fortinet - Phase 2 (Log Analysis & Incident Response)

set -euo pipefail

LOG_FILE="/var/log/ctf-userdata.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== FortiAnalyzer CTF User Data Script Started ==="
echo "Event: ${event_name}"
echo "Instance Type: ${instance_type}"
echo "Region: ${region}"
echo "S3 Bucket: ${s3_bucket}"
echo "Timestamp: $(date)"

# Install AWS CLI and other utilities
echo "Installing required packages..."
yum update -y
yum install -y awscli jq expect curl wget unzip

# Configure AWS CLI to use instance role
echo "Configuring AWS CLI..."
aws configure set default.region ${region}

# Download configuration files from S3
echo "Downloading configuration files from S3..."
mkdir -p /opt/ctf/config
cd /opt/ctf/config

# Download bootstrap configuration
echo "Downloading bootstrap configuration..."
aws s3 cp s3://${s3_bucket}/bootstrap.conf ./bootstrap.conf

# Download day-0 configuration script
echo "Downloading day-0 configuration script..."
aws s3 cp s3://${s3_bucket}/day0-config.sh ./day0-config.sh
chmod +x ./day0-config.sh

# Download seed data
echo "Downloading seed data..."
aws s3 cp s3://${s3_bucket}/seed_logs.json ./seed_logs.json

# Wait for FortiAnalyzer system to be ready
echo "Waiting for FortiAnalyzer to initialize..."
sleep 120

# Check if FortiAnalyzer is accessible
echo "Checking FortiAnalyzer accessibility..."
max_retries=30
retry_count=0

while [ $retry_count -lt $max_retries ]; do
    if curl -k -s -f https://127.0.0.1:443/logincheck > /dev/null 2>&1; then
        echo "FortiAnalyzer web interface is accessible"
        break
    else
        echo "Waiting for FortiAnalyzer... (attempt $((retry_count + 1))/$max_retries)"
        sleep 30
        ((retry_count++))
    fi
done

if [ $retry_count -eq $max_retries ]; then
    echo "ERROR: FortiAnalyzer failed to become accessible after $max_retries attempts"
    exit 1
fi

# Apply bootstrap configuration
echo "Applying bootstrap configuration..."
if [ -f "./bootstrap.conf" ]; then
    # Copy bootstrap config to FortiAnalyzer config directory
    cp ./bootstrap.conf /etc/fortianalyzer/bootstrap.conf
    
    # Signal FortiAnalyzer to reload configuration
    kill -HUP $(pgrep -f fortianalyzer) 2>/dev/null || true
    
    sleep 60
else
    echo "WARNING: Bootstrap configuration file not found"
fi

# Set up additional storage if EBS volume is attached
echo "Configuring additional storage..."
if [ -b /dev/nvme1n1 ] || [ -b /dev/xvdf ]; then
    # Determine the correct device name
    if [ -b /dev/nvme1n1 ]; then
        DEVICE="/dev/nvme1n1"
    else
        DEVICE="/dev/xvdf"
    fi
    
    echo "Formatting additional storage device: $DEVICE"
    
    # Create filesystem if not already formatted
    if ! blkid $DEVICE; then
        mkfs.ext4 $DEVICE
    fi
    
    # Create mount point and mount
    mkdir -p /var/log/fortianalyzer
    echo "$DEVICE /var/log/fortianalyzer ext4 defaults,noatime 0 2" >> /etc/fstab
    mount -a
    
    # Set ownership
    chown -R fortianalyzer:fortianalyzer /var/log/fortianalyzer
    
    echo "Additional storage configured and mounted"
else
    echo "No additional storage device found"
fi

# Configure system limits for high log volume
echo "Configuring system limits for high log volume..."
cat >> /etc/security/limits.conf << 'EOF'
# FortiAnalyzer CTF Configuration
fortianalyzer soft nofile 65536
fortianalyzer hard nofile 65536
fortianalyzer soft nproc 32768
fortianalyzer hard nproc 32768
EOF

# Configure sysctl for network optimization
cat >> /etc/sysctl.conf << 'EOF'
# FortiAnalyzer CTF Network Optimization
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = bbr
EOF

sysctl -p

# Configure log rotation
echo "Configuring log rotation..."
cat > /etc/logrotate.d/ctf-fortianalyzer << 'EOF'
/var/log/ctf*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}
EOF

# Set up health monitoring
echo "Setting up health monitoring..."
cat > /opt/ctf/health-check.sh << 'EOF'
#!/bin/bash
# FortiAnalyzer Health Check Script

LOG_FILE="/var/log/ctf-health.log"
TIMESTAMP=$(date)

echo "[$TIMESTAMP] Starting health check..." >> $LOG_FILE

# Check FortiAnalyzer processes
if pgrep -f fortianalyzer > /dev/null; then
    echo "[$TIMESTAMP] FortiAnalyzer process: OK" >> $LOG_FILE
else
    echo "[$TIMESTAMP] FortiAnalyzer process: FAILED" >> $LOG_FILE
fi

# Check web interface
if curl -k -s -f https://127.0.0.1:443/logincheck > /dev/null 2>&1; then
    echo "[$TIMESTAMP] Web interface: OK" >> $LOG_FILE
else
    echo "[$TIMESTAMP] Web interface: FAILED" >> $LOG_FILE
fi

# Check disk space
DISK_USAGE=$(df /var/log | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $DISK_USAGE -lt 80 ]; then
    echo "[$TIMESTAMP] Disk usage: OK ($DISK_USAGE%)" >> $LOG_FILE
else
    echo "[$TIMESTAMP] Disk usage: WARNING ($DISK_USAGE%)" >> $LOG_FILE
fi

# Check memory usage
MEM_USAGE=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
if [ $MEM_USAGE -lt 90 ]; then
    echo "[$TIMESTAMP] Memory usage: OK ($MEM_USAGE%)" >> $LOG_FILE
else
    echo "[$TIMESTAMP] Memory usage: WARNING ($MEM_USAGE%)" >> $LOG_FILE
fi

echo "[$TIMESTAMP] Health check completed" >> $LOG_FILE
EOF

chmod +x /opt/ctf/health-check.sh

# Set up cron job for health monitoring
echo "*/5 * * * * root /opt/ctf/health-check.sh" >> /etc/crontab

# Execute day-0 configuration script
echo "Executing day-0 configuration..."
if [ -f "./day0-config.sh" ]; then
    ./day0-config.sh
else
    echo "WARNING: Day-0 configuration script not found"
fi

# Create completion marker
echo "Creating completion marker..."
cat > /opt/ctf/deployment-status.json << EOF
{
    "status": "completed",
    "timestamp": "$(date -Iseconds)",
    "event_name": "${event_name}",
    "instance_type": "${instance_type}",
    "region": "${region}",
    "public_ip": "$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)",
    "private_ip": "$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)",
    "instance_id": "$(curl -s http://169.254.169.254/latest/meta-data/instance-id)",
    "components": {
        "fortianalyzer": "configured",
        "bootstrap": "applied", 
        "day0_config": "executed",
        "storage": "mounted",
        "monitoring": "enabled"
    },
    "access": {
        "web_url": "https://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)",
        "admin_user": "admin",
        "admin_password": "FortiCTF2026!"
    },
    "ctf_ready": true
}
EOF

# Upload deployment status to S3
aws s3 cp /opt/ctf/deployment-status.json s3://${s3_bucket}/deployment-status.json

# Final verification
echo "=== Final Verification ==="
echo "FortiAnalyzer Status: $(systemctl is-active fortianalyzer 2>/dev/null || echo 'N/A')"
echo "Web Interface: https://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "Storage Usage: $(df -h /var/log | tail -1)"
echo "System Load: $(uptime)"

echo "=== FortiAnalyzer CTF User Data Script Completed Successfully ==="
echo "Deployment timestamp: $(date)"
echo "Instance ready for CTF Phase 2"

# Send completion notification (optional)
if command -v aws &> /dev/null; then
    aws sns publish --topic-arn "arn:aws:sns:${region}:$(aws sts get-caller-identity --query Account --output text):ctf-notifications" \
        --message "FortiAnalyzer deployment completed for ${event_name}" \
        --subject "CTF FortiAnalyzer Ready" 2>/dev/null || echo "SNS notification skipped (topic not found)"
fi