#!/bin/bash
# =============================================================================
# CTF Fortinet — Reset a single team's stack
# =============================================================================
# Usage: ./reset-team.sh <team_id> [environment]
# Example: ./reset-team.sh 3 prod
# =============================================================================

set -euo pipefail

TEAM_ID=${1:?"Usage: $0 <team_id> [environment]"}
ENVIRONMENT=${2:-dev}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TF_DIR="${SCRIPT_DIR}/../terraform/environments/${ENVIRONMENT}"

echo "🔄 Resetting Team ${TEAM_ID} stack..."
echo "============================================"

cd "${TF_DIR}"

# Destroy only this team's resources
terraform destroy \
  -target="module.network[${TEAM_ID}]" \
  -target="module.fortigate[${TEAM_ID}]" \
  -auto-approve

echo "♻️  Rebuilding Team ${TEAM_ID}..."

# Recreate
terraform apply \
  -target="module.network[${TEAM_ID}]" \
  -target="module.fortigate[${TEAM_ID}]" \
  -auto-approve

echo ""
echo "✅ Team ${TEAM_ID} stack reset complete!"
echo "🔗 New access:"
terraform output -json team_access | python3 -c "
import json, sys
data = json.load(sys.stdin)
team = data.get('team-${TEAM_ID}', {})
print(f'  URL: {team.get(\"fortigate_url\", \"N/A\")}')
print(f'  User: {team.get(\"admin_user\", \"N/A\")}')
print(f'  Pass: {team.get(\"admin_password\", \"N/A\")}')
"
