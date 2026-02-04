#!/bin/bash
# =============================================================================
# 🧹 CTF FULL DESTROY — Clean teardown
# =============================================================================
# Usage: ./destroy.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TF_DIR="$SCRIPT_DIR/../terraform/environments/dev"

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${RED}${BOLD}"
echo "╔══════════════════════════════════════════════╗"
echo "║     ⚠️  CTF FULL DESTROY — ALL RESOURCES    ║"
echo "╚══════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${YELLOW}This will destroy:${NC}"
echo "  - All FortiGate instances"
echo "  - All team VPCs and networks"
echo "  - CTFd server and database"
echo "  - All Elastic IPs"
echo ""

read -p "Are you sure? Type 'destroy' to confirm: " CONFIRM

if [ "$CONFIRM" != "destroy" ]; then
    echo "Aborted."
    exit 0
fi

cd "$TF_DIR"

echo -e "\n${YELLOW}Destroying all CTF resources...${NC}"
terraform destroy -auto-approve

echo -e "\n${GREEN}✅ All CTF resources destroyed.${NC}"
echo -e "${YELLOW}Don't forget to release any unused Elastic IPs in the AWS console.${NC}"
