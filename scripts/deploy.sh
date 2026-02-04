#!/bin/bash
# =============================================================================
# 🏁 CTF FULL DEPLOY — One command to rule them all
# =============================================================================
# Usage:
#   ./deploy.sh                    # Deploy 1 team (dev/testing)
#   ./deploy.sh 5                  # Deploy 5 teams
#   ./deploy.sh 10 production      # Deploy 10 teams, event mode
#
# What it does:
#   1. terraform apply (VPCs + FortiGates + CTFd)
#   2. Wait for CTFd to be ready
#   3. Provision CTFd (teams, challenges, flags)
#   4. Generate access sheets
#   5. Print summary
# =============================================================================

set -euo pipefail

TEAM_COUNT="${1:-1}"
EVENT_MODE="${2:-dev}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TF_DIR="$SCRIPT_DIR/../terraform/environments/dev"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}${BOLD}"
echo "╔══════════════════════════════════════════════╗"
echo "║     🏁 FORTINET SECURITY CTF — DEPLOY       ║"
echo "╠══════════════════════════════════════════════╣"
echo "║  Teams:    $TEAM_COUNT                                 ║"
echo "║  Mode:     $EVENT_MODE                              ║"
echo "║  Region:   us-east-1                         ║"
echo "╚══════════════════════════════════════════════╝"
echo -e "${NC}"

# =============================================================================
# Step 1: Terraform Apply
# =============================================================================

echo -e "\n${GREEN}${BOLD}[Step 1/4] Deploying infrastructure...${NC}"
cd "$TF_DIR"

# Initialize if needed
if [ ! -d ".terraform" ]; then
    echo -e "${BLUE}  Initializing Terraform...${NC}"
    terraform init
fi

# Plan
echo -e "${BLUE}  Planning deployment for $TEAM_COUNT teams...${NC}"
terraform plan \
    -var="team_count=$TEAM_COUNT" \
    -var="deploy_ctfd=true" \
    -out=ctf.tfplan

# Apply
echo -e "${YELLOW}  Applying... (this takes 3-5 minutes)${NC}"
terraform apply ctf.tfplan

echo -e "${GREEN}  ✅ Infrastructure deployed!${NC}"

# =============================================================================
# Step 2: Wait for CTFd
# =============================================================================

echo -e "\n${GREEN}${BOLD}[Step 2/4] Waiting for CTFd to boot...${NC}"

CTFD_IP=$(terraform output -raw ctfd_public_ip 2>/dev/null || echo "")

if [ -z "$CTFD_IP" ]; then
    echo -e "${RED}  CTFd not deployed, skipping provisioning.${NC}"
    exit 0
fi

CTFD_URL="http://$CTFD_IP"
echo -e "${BLUE}  CTFd IP: $CTFD_IP${NC}"

# Wait up to 5 minutes
for i in $(seq 1 30); do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$CTFD_URL" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
        echo -e "\n${GREEN}  ✅ CTFd is ready! (HTTP $HTTP_CODE)${NC}"
        break
    fi
    echo -n "."
    sleep 10
done

# Extra wait for Docker services to fully initialize
echo -e "${BLUE}  Waiting 30s for database initialization...${NC}"
sleep 30

# =============================================================================
# Step 3: Provision CTFd
# =============================================================================

echo -e "\n${GREEN}${BOLD}[Step 3/4] Provisioning CTFd (teams + challenges + flags)...${NC}"

"$SCRIPT_DIR/provision-ctfd.sh" "$TF_DIR"

# =============================================================================
# Step 4: Summary
# =============================================================================

echo -e "\n${GREEN}${BOLD}[Step 4/4] Deployment complete!${NC}"

echo -e "\n${CYAN}${BOLD}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║              🏁 CTF DEPLOYMENT COMPLETE                 ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║                                                          ║"
echo "║  📊 CTFd Portal: $CTFD_URL"
echo "║  👤 Admin Login: admin / CTFAdmin2026!"
echo "║                                                          ║"
echo "║  📋 Teams deployed: $TEAM_COUNT"
echo "║                                                          ║"

for team_num in $(seq 1 "$TEAM_COUNT"); do
    FGT_IP=$(terraform output -json team_access | jq -r ".\"team-$team_num\".fortigate_ip")
    echo "║  🔥 Team $team_num: FortiGate @ https://$FGT_IP"
done

echo "║                                                          ║"
echo "║  📄 Access sheet: /opt/ctfd-access-sheet.md             ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Share team credentials with participants"
echo "  2. Set CTF start/end time in CTFd admin panel"
echo "  3. Monitor scoreboard at $CTFD_URL/scoreboard"
echo ""
echo -e "${GREEN}Good luck! 🎯${NC}"
