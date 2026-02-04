#!/bin/bash
# =============================================================================
# CTFd Auto-Provisioner
# =============================================================================
# Reads Terraform outputs and configures CTFd with:
# - Teams (one per FortiGate stack)
# - Challenges (Phase 1: 7 challenges)
# - Flags (unique per team, from Terraform)
# - Categories
# - Scoring
#
# Usage: ./provision-ctfd.sh [terraform_dir]
# =============================================================================

set -euo pipefail

TERRAFORM_DIR="${1:-../terraform/environments/dev}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[-]${NC} $1"; }
info() { echo -e "${BLUE}[*]${NC} $1"; }

# =============================================================================
# 1. Read Terraform Outputs
# =============================================================================

log "Reading Terraform outputs..."
cd "$TERRAFORM_DIR"

CTFD_URL=$(terraform output -json | jq -r '.ctfd_url.value // empty')
CTFD_IP=$(terraform output -json | jq -r '.ctfd_public_ip.value // empty')
TEAM_ACCESS=$(terraform output -json | jq -r '.team_access.value // empty')
ADMIN_ACCESS=$(terraform output -json -no-color 2>/dev/null | jq -r '.admin_access.value // empty' 2>/dev/null || echo "{}")

if [ -z "$CTFD_URL" ]; then
    err "No CTFd URL found in Terraform outputs. Did you deploy the ctfd module?"
    exit 1
fi

log "CTFd URL: $CTFD_URL"

# Wait for CTFd to be accessible
info "Waiting for CTFd to be ready..."
for i in $(seq 1 60); do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$CTFD_URL" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
        log "CTFd is responding! (HTTP $HTTP_CODE)"
        break
    fi
    echo -n "."
    sleep 10
done
echo ""

# =============================================================================
# 2. Get API Token
# =============================================================================

ADMIN_PASS="${CTFD_ADMIN_PASSWORD:-CTFAdmin2026!}"

log "Authenticating with CTFd..."

# Login to get session
SESSION_FILE=$(mktemp)
NONCE=$(curl -s -c "$SESSION_FILE" "$CTFD_URL/login" | grep -oP 'name="nonce" value="\K[^"]+' || echo "")

curl -s -b "$SESSION_FILE" -c "$SESSION_FILE" \
    -X POST "$CTFD_URL/login" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "name=admin&password=$ADMIN_PASS&nonce=$NONCE" \
    -o /dev/null

# Generate API token
TOKEN_RESPONSE=$(curl -s -b "$SESSION_FILE" -c "$SESSION_FILE" \
    -X POST "$CTFD_URL/api/v1/tokens" \
    -H "Content-Type: application/json" \
    -d '{"description": "provisioner", "expiration": "2027-01-01T00:00:00"}')

API_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.data.value // empty')

if [ -z "$API_TOKEN" ]; then
    err "Failed to get API token. Response: $TOKEN_RESPONSE"
    exit 1
fi

log "API token acquired!"

# Helper: CTFd API call
ctfd_api() {
    local method=$1
    local endpoint=$2
    local data=${3:-}
    
    if [ -n "$data" ]; then
        curl -s -X "$method" "$CTFD_URL/api/v1$endpoint" \
            -H "Authorization: Token $API_TOKEN" \
            -H "Content-Type: application/json" \
            -d "$data"
    else
        curl -s -X "$method" "$CTFD_URL/api/v1$endpoint" \
            -H "Authorization: Token $API_TOKEN" \
            -H "Content-Type: application/json"
    fi
}

# =============================================================================
# 3. Create Challenge Categories (via tags, CTFd doesn't have native categories)
# =============================================================================

log "Creating challenges..."

# Challenge definitions
declare -A CHALLENGES
# Format: "name|category|description|value|type|max_attempts"

CHALLENGES[1]="First Login|Reconnaissance|Connect to your FortiGate and explore. Find the hidden flag in the system configuration.\n\nHint: Check the system alias or description fields.|100|standard|0"
CHALLENGES[2]="Open Sesame|Firewall Policies|The DMZ server can't reach the internet. Your job: create or modify a firewall policy to allow DMZ (port3) to reach the internet through NAT.\n\nValidation: The flag will appear when the DMZ server can successfully ping 8.8.8.8.|100|standard|0"
CHALLENGES[3]="Who Goes There?|Address Objects|Create proper address objects and security policies:\n1. Create address object 'Malicious-IPs' with the IPs listed in your challenge brief\n2. Create a deny policy for traffic from these IPs\n3. The flag appears in the log output after blocking|100|standard|0"
CHALLENGES[4]="Tunnel Vision|VPN|Establish an IPsec VPN tunnel between your FortiGate and the central server.\n\nConfigure Phase 1 (IKE) and Phase 2 (IPsec) with the parameters in your team brief. Bring up the tunnel and access the flag server on the other side.|200|standard|5"
CHALLENGES[5]="Inspector Gadget|Security Profiles|Enable and configure security inspection:\n1. Create an AntiVirus profile\n2. Create an IPS sensor with specific signatures\n3. Apply profiles to existing policies\n4. Trigger a test signature (EICAR) to prove detection works\n\nThe flag is in the IPS/AV log after detection.|200|standard|5"
CHALLENGES[6]="The Insider|Troubleshooting|Something is broken. The network was working, but someone made changes.\n\nFind and fix ALL issues:\n- Routing problems\n- NAT misconfiguration\n- Policy ordering issues\n- DNS failures\n\nThe flag appears when all connectivity tests pass.|300|standard|10"
CHALLENGES[7]="Zero Trust Hero|Advanced Policy|Implement a Zero Trust segmentation policy:\n1. Create ISDB-based policies (allow only specific apps)\n2. Micro-segmentation between LAN and DMZ\n3. Block all implicit traffic with logging\n4. Achieve the target Security Rating score\n\nThe flag is calculated from your Security Rating output.|300|standard|10"

# Category mapping for tags
declare -A CATEGORIES
CATEGORIES["Reconnaissance"]="🟢 Easy"
CATEGORIES["Firewall Policies"]="🟢 Easy"
CATEGORIES["Address Objects"]="🟢 Easy"
CATEGORIES["VPN"]="🟡 Medium"
CATEGORIES["Security Profiles"]="🟡 Medium"
CATEGORIES["Troubleshooting"]="🔴 Hard"
CATEGORIES["Advanced Policy"]="🔴 Hard"

CHALLENGE_IDS=()

for i in $(seq 1 7); do
    IFS='|' read -r name category description value type max_attempts <<< "${CHALLENGES[$i]}"
    
    # Create challenge
    RESPONSE=$(ctfd_api POST /challenges "{
        \"name\": \"$name\",
        \"category\": \"$category\",
        \"description\": \"$(echo -e "$description" | sed 's/"/\\"/g' | tr '\n' ' ')\",
        \"value\": $value,
        \"type\": \"$type\",
        \"state\": \"visible\",
        \"max_attempts\": $max_attempts
    }")
    
    CHALLENGE_ID=$(echo "$RESPONSE" | jq -r '.data.id // empty')
    
    if [ -n "$CHALLENGE_ID" ]; then
        log "  Challenge #$i: '$name' (${value}pts) → ID $CHALLENGE_ID"
        CHALLENGE_IDS+=("$CHALLENGE_ID")
        
        # Add difficulty tag
        DIFFICULTY="${CATEGORIES[$category]}"
        ctfd_api POST /tags "{\"challenge_id\": $CHALLENGE_ID, \"value\": \"$DIFFICULTY\"}" > /dev/null
        ctfd_api POST /tags "{\"challenge_id\": $CHALLENGE_ID, \"value\": \"Phase 1\"}" > /dev/null
    else
        warn "  Failed to create challenge #$i: $RESPONSE"
    fi
done

# =============================================================================
# 4. Create Teams + Assign Flags
# =============================================================================

log "Creating teams and assigning flags..."

# Parse admin_access for flags (sensitive output)
ADMIN_JSON=$(cd "$TERRAFORM_DIR" && terraform output -json admin_access 2>/dev/null || echo "{}")

# Get team count from team_access
TEAM_COUNT=$(echo "$TEAM_ACCESS" | jq 'length')
log "Teams to create: $TEAM_COUNT"

# Flag-to-challenge mapping
declare -A FLAG_CHALLENGE_MAP
FLAG_CHALLENGE_MAP["FLAG_HIDDEN_POLICY"]=1    # First Login → Challenge 1
FLAG_CHALLENGE_MAP["FLAG_LOG_HUNTER"]=3        # Who Goes There → Challenge 3
FLAG_CHALLENGE_MAP["FLAG_VPN_WARRIOR"]=4       # Tunnel Vision → Challenge 4
FLAG_CHALLENGE_MAP["FLAG_TROUBLESHOOTER"]=6    # The Insider → Challenge 6
FLAG_CHALLENGE_MAP["FLAG_BONUS"]=7             # Zero Trust Hero → Challenge 7

for team_num in $(seq 1 "$TEAM_COUNT"); do
    TEAM_KEY="team-$team_num"
    TEAM_NAME="Team $team_num"
    TEAM_PASS="team${team_num}ctf2026"
    TEAM_EMAIL="team${team_num}@fortinet-ctf.local"
    
    # Get FortiGate IP for this team
    FGT_IP=$(echo "$TEAM_ACCESS" | jq -r ".[\"$TEAM_KEY\"].fortigate_ip // \"unknown\"")
    
    info "Creating $TEAM_NAME (FortiGate: $FGT_IP)..."
    
    # Create team (CTFd user in team mode)
    TEAM_RESPONSE=$(ctfd_api POST /teams "{
        \"name\": \"$TEAM_NAME\",
        \"email\": \"$TEAM_EMAIL\",
        \"password\": \"$TEAM_PASS\",
        \"hidden\": false,
        \"banned\": false
    }")
    
    TEAM_ID=$(echo "$TEAM_RESPONSE" | jq -r '.data.id // empty')
    
    if [ -n "$TEAM_ID" ]; then
        log "  $TEAM_NAME → ID $TEAM_ID (pass: $TEAM_PASS)"
    else
        warn "  Failed to create $TEAM_NAME: $TEAM_RESPONSE"
        continue
    fi
    
    # Get flags for this team from Terraform
    TEAM_FLAGS=$(echo "$ADMIN_JSON" | jq -r ".[\"$TEAM_KEY\"].flags // empty")
    
    if [ -n "$TEAM_FLAGS" ] && [ "$TEAM_FLAGS" != "null" ]; then
        for FLAG_NAME in "${!FLAG_CHALLENGE_MAP[@]}"; do
            FLAG_VALUE=$(echo "$TEAM_FLAGS" | jq -r ".[\"$FLAG_NAME\"] // empty")
            CHALLENGE_IDX=${FLAG_CHALLENGE_MAP[$FLAG_NAME]}
            CHALLENGE_ID=${CHALLENGE_IDS[$((CHALLENGE_IDX - 1))]}
            
            if [ -n "$FLAG_VALUE" ] && [ -n "$CHALLENGE_ID" ]; then
                # Add flag to challenge (CTFd supports multiple flags per challenge)
                ctfd_api POST /flags "{
                    \"challenge_id\": $CHALLENGE_ID,
                    \"content\": \"$FLAG_VALUE\",
                    \"type\": \"static\",
                    \"data\": \"\"
                }" > /dev/null
            fi
        done
        log "  Flags assigned for $TEAM_NAME ✓"
    else
        warn "  No flags found for $TEAM_NAME in Terraform outputs"
    fi
done

# =============================================================================
# 5. Configure CTF Settings
# =============================================================================

log "Configuring CTF settings..."

# Set theme and branding
ctfd_api PATCH /configs "{ 
    \"ctf_name\": \"Fortinet Security CTF\",
    \"ctf_description\": \"Network Security Challenge — Test your FortiGate skills!\",
    \"ctf_theme\": \"core\",
    \"user_mode\": \"teams\",
    \"challenge_visibility\": \"public\",
    \"score_visibility\": \"public\",
    \"registration_visibility\": \"private\",
    \"team_size\": 5
}" > /dev/null 2>&1 || true

# =============================================================================
# 6. Generate Access Sheet
# =============================================================================

ACCESS_FILE="/opt/ctfd-access-sheet.md"
log "Generating access sheet..."

cat > "$ACCESS_FILE" <<SHEET
# 🏁 Fortinet Security CTF — Access Sheet
## Event: ${event_name:-fortinet-ctf}
## Generated: $(date -u +"%Y-%m-%d %H:%M UTC")

---

## 🌐 CTF Portal
- **URL:** $CTFD_URL
- **Admin:** admin / $ADMIN_PASS

---

## 👥 Teams

SHEET

for team_num in $(seq 1 "$TEAM_COUNT"); do
    TEAM_KEY="team-$team_num"
    FGT_IP=$(echo "$TEAM_ACCESS" | jq -r ".[\"$TEAM_KEY\"].fortigate_ip // \"unknown\"")
    FGT_USER=$(echo "$TEAM_ACCESS" | jq -r ".[\"$TEAM_KEY\"].admin_user // \"ctfplayer\"")
    FGT_PASS=$(echo "$TEAM_ACCESS" | jq -r ".[\"$TEAM_KEY\"].admin_password // \"unknown\"")
    
    cat >> "$ACCESS_FILE" <<TEAM
### Team $team_num
| Resource | Value |
|----------|-------|
| CTFd Login | team${team_num} / team${team_num}ctf2026 |
| FortiGate URL | https://$FGT_IP |
| FortiGate User | $FGT_USER / $FGT_PASS |

TEAM
done

cat >> "$ACCESS_FILE" <<FOOTER

---

## 📋 Challenges (Phase 1)
| # | Name | Category | Points | Difficulty |
|---|------|----------|--------|------------|
| 1 | First Login | Reconnaissance | 100 | 🟢 Easy |
| 2 | Open Sesame | Firewall Policies | 100 | 🟢 Easy |
| 3 | Who Goes There? | Address Objects | 100 | 🟢 Easy |
| 4 | Tunnel Vision | VPN | 200 | 🟡 Medium |
| 5 | Inspector Gadget | Security Profiles | 200 | 🟡 Medium |
| 6 | The Insider | Troubleshooting | 300 | 🔴 Hard |
| 7 | Zero Trust Hero | Advanced Policy | 300 | 🔴 Hard |

**Total: 1,400 points + time bonuses**

---
*Auto-generated by CTF provisioner*
FOOTER

log "Access sheet saved to: $ACCESS_FILE"

# =============================================================================
# DONE
# =============================================================================

echo ""
echo "============================================="
echo "  🏁 CTFd PROVISIONING COMPLETE"
echo "============================================="
echo "  Portal:     $CTFD_URL"
echo "  Admin:      admin / $ADMIN_PASS"
echo "  Teams:      $TEAM_COUNT"
echo "  Challenges: ${#CHALLENGE_IDS[@]}"
echo "  Access:     $ACCESS_FILE"
echo "============================================="

rm -f "$SESSION_FILE"
