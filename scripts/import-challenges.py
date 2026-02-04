#!/usr/bin/env python3
"""
Import CTF challenges into CTFd via REST API.

Usage:
    python import-challenges.py --url http://ctfd-ip --token <admin_token>
    python import-challenges.py --url http://ctfd-ip --token <admin_token> --teams 3

This script:
1. Creates challenge categories (if not exist)
2. Creates all Phase 1 challenges with descriptions, points, hints
3. Creates team accounts
4. Sets up flags (unique per team)
"""

import argparse
import json
import requests
import sys
import hashlib

# ─── Challenge Definitions ───────────────────────────────────────────────

CHALLENGES = [
    {
        "id": "recon",
        "name": "🟢 First Login",
        "category": "Reconnaissance",
        "description": (
            "## Objective\n"
            "Welcome to your FortiGate! Your first mission is simple: **find the system hostname and serial number.**\n\n"
            "## Instructions\n"
            "1. SSH into your FortiGate using the credentials provided\n"
            "2. Explore the CLI — find the hostname and serial number\n"
            "3. The flag format is: `CTF{hostname_serialnumber}`\n\n"
            "## Hint\n"
            "💡 Try `get system status` — but also check the system alias, there might be something extra hidden there.\n\n"
            "## Flag Format\n"
            "`CTF{...}`"
        ),
        "value": 100,
        "type": "standard",
        "state": "visible",
        "max_attempts": 10,
    },
    {
        "id": "open_sesame",
        "name": "🟢 Open Sesame",
        "category": "Firewall Policy",
        "description": (
            "## Objective\n"
            "The DMZ server (connected to **port3**) can't reach the internet! Something is blocking it.\n\n"
            "## Instructions\n"
            "1. Check the current firewall policies\n"
            "2. Find what's blocking DMZ traffic\n"
            "3. Fix the policy so the DMZ can browse the web\n"
            "4. Once fixed, from the DMZ try to reach: `http://<FLAG_SERVER>:8080/secret-page`\n"
            "5. The flag will be displayed on the page!\n\n"
            "## Hint\n"
            "💡 Look at policy ID 2 — what's the action set to?\n"
            "💡 Don't forget about NAT!\n\n"
            "## Flag Format\n"
            "`CTF{...}`"
        ),
        "value": 100,
        "type": "standard",
        "state": "visible",
        "max_attempts": 20,
    },
    {
        "id": "who_goes_there",
        "name": "🟢 Who Goes There?",
        "category": "Address Objects",
        "description": (
            "## Objective\n"
            "Your network is under attack from known malicious IPs! Block them.\n\n"
            "## Instructions\n"
            "1. Create address objects for these malicious IPs:\n"
            "   - `198.51.100.10`\n"
            "   - `198.51.100.20`\n"
            "   - `198.51.100.30`\n"
            "2. Create an address group called **`Malicious-IPs`** containing all three\n"
            "3. Create a **DENY** policy for inbound traffic FROM these IPs\n"
            "4. Once your policy is active, request your flag from:\n"
            "   `http://<FLAG_SERVER>:8080/api/flag/who_goes_there`\n\n"
            "## Hint\n"
            "💡 The traffic generator is constantly sending packets from these IPs.\n"
            "💡 Your deny policy needs to be above the allow policies!\n\n"
            "## Flag Format\n"
            "`CTF{...}`"
        ),
        "value": 100,
        "type": "standard",
        "state": "visible",
        "max_attempts": 20,
    },
    {
        "id": "tunnel_vision",
        "name": "🟡 Tunnel Vision",
        "category": "VPN",
        "description": (
            "## Objective\n"
            "Establish an **IPsec VPN tunnel** to the central server and retrieve the flag from the other side.\n\n"
            "## VPN Parameters\n"
            "| Parameter | Value |\n"
            "|-----------|-------|\n"
            "| IKE Version | **2** |\n"
            "| Pre-Shared Key | **`CTFortinet2026`** |\n"
            "| Remote Gateway | **`<UTILITY_SERVER_IP>`** |\n"
            "| Local Subnet | Your LAN: **`10.x.2.0/24`** |\n"
            "| Remote Subnet | **`172.16.100.0/24`** |\n"
            "| Encryption | AES256 |\n"
            "| Authentication | SHA256 |\n"
            "| DH Group | 14 |\n\n"
            "## Instructions\n"
            "1. Configure Phase 1 (IKE) with the parameters above\n"
            "2. Configure Phase 2 (IPsec) with correct selectors\n"
            "3. Bring the tunnel UP\n"
            "4. From your LAN, access: `http://172.16.100.1/vpn-flag`\n"
            "5. The flag will be in the response!\n\n"
            "## Hint\n"
            "💡 Use `diag vpn ike gateway list` to check Phase 1 status\n"
            "💡 Use `diag vpn tunnel list` to check Phase 2\n"
            "💡 Don't forget to add a firewall policy allowing VPN traffic!\n\n"
            "## Flag Format\n"
            "`CTF{...}`"
        ),
        "value": 200,
        "type": "standard",
        "state": "visible",
        "max_attempts": 20,
    },
    {
        "id": "inspector_gadget",
        "name": "🟡 Inspector Gadget",
        "category": "Security Profiles",
        "description": (
            "## Objective\n"
            "Enable and configure **security inspection** on your FortiGate to detect threats.\n\n"
            "## Instructions\n"
            "1. Create an **AntiVirus profile** named `ctf-av`\n"
            "2. Create an **IPS sensor** named `ctf-ips`\n"
            "   - Enable signature ID **41748**\n"
            "3. Apply **both profiles** to your LAN-to-WAN policy (Policy 1)\n"
            "4. The traffic generator is sending EICAR test files and exploit attempts\n"
            "5. Once configured, request your flag:\n"
            "   `http://<FLAG_SERVER>:8080/api/flag/inspector_gadget`\n\n"
            "## Hint\n"
            "💡 You may need to configure SSL inspection (at least certificate-inspection)\n"
            "💡 Check `Log & Report > Security Events` after enabling profiles\n"
            "💡 The validator checks via SSH that profiles exist AND are applied\n\n"
            "## Flag Format\n"
            "`CTF{...}`"
        ),
        "value": 200,
        "type": "standard",
        "state": "visible",
        "max_attempts": 20,
    },
    {
        "id": "the_insider",
        "name": "🔴 The Insider",
        "category": "Troubleshooting",
        "description": (
            "## Objective\n"
            "⚠️ **ALERT:** Someone sabotaged this FortiGate! Multiple things are broken.\n\n"
            "## Reported Issues\n"
            "Users report the following problems:\n"
            "1. ❌ **Can't reach the internet** from LAN\n"
            "2. ❌ **DNS isn't resolving** any domains\n"
            "3. ❌ **Traffic goes to the wrong place** sometimes\n"
            "4. ❌ **Can't access the GUI** remotely anymore\n\n"
            "## Instructions\n"
            "1. SSH into the FortiGate and investigate\n"
            "2. Find and fix **ALL 4 issues**\n"
            "3. When everything works, from your LAN access:\n"
            "   `http://<FLAG_SERVER>:8080/api/flag/the_insider`\n"
            "4. The validator will check all 4 fixes before revealing the flag\n\n"
            "## Hint\n"
            "💡 `diagnose debug flow` is your best friend\n"
            "💡 `diagnose sniffer` can show you what's happening at packet level\n"
            "💡 Check: static routes, DNS config, NAT settings, interface allowaccess\n\n"
            "## Flag Format\n"
            "`CTF{...}`"
        ),
        "value": 300,
        "type": "standard",
        "state": "visible",
        "max_attempts": 30,
    },
    {
        "id": "zero_trust",
        "name": "🔴 Zero Trust Hero",
        "category": "Advanced Policy",
        "description": (
            "## Objective\n"
            "Implement a **Zero Trust segmentation** policy on your FortiGate.\n\n"
            "## Requirements\n"
            "1. Create **ISDB-based policies** that only allow HTTPS and DNS from LAN to WAN\n"
            "2. **Block ALL traffic** between LAN and DMZ **except SSH** (port 22)\n"
            "3. Enable **Application Control** to block social media applications\n"
            "4. **All denied traffic** must be logged\n\n"
            "## Instructions\n"
            "1. Replace the permissive LAN-to-WAN policy with specific ISDB rules\n"
            "2. Create inter-zone policies for LAN↔DMZ segmentation\n"
            "3. Create and apply an Application Control profile\n"
            "4. Enable implicit deny logging\n"
            "5. Request your flag:\n"
            "   `http://<FLAG_SERVER>:8080/api/flag/zero_trust`\n\n"
            "## Hint\n"
            "💡 Use `internet-service-name` in your policies for ISDB\n"
            "💡 Check `Security Rating` — aim for >60%\n"
            "💡 Application categories: 'Social.Media' for blocking\n\n"
            "## Flag Format\n"
            "`CTF{...}`"
        ),
        "value": 300,
        "type": "standard",
        "state": "visible",
        "max_attempts": 30,
    },
]


# ─── CTFd API Helper ─────────────────────────────────────────────────────

class CTFdAPI:
    def __init__(self, url, token):
        self.url = url.rstrip('/')
        self.session = requests.Session()
        self.session.headers.update({
            'Authorization': f'Token {token}',
            'Content-Type': 'application/json'
        })

    def get(self, endpoint):
        r = self.session.get(f'{self.url}/api/v1{endpoint}')
        r.raise_for_status()
        return r.json()

    def post(self, endpoint, data):
        r = self.session.post(f'{self.url}/api/v1{endpoint}', json=data)
        if r.status_code not in [200, 201]:
            print(f"  ❌ POST {endpoint} failed: {r.status_code} {r.text}")
            return None
        return r.json()

    def patch(self, endpoint, data):
        r = self.session.patch(f'{self.url}/api/v1{endpoint}', json=data)
        r.raise_for_status()
        return r.json()


# ─── Import Functions ────────────────────────────────────────────────────

def generate_team_flag(challenge_id, team_num, event_name="fortinet-ctf"):
    """Generate deterministic flag for a team+challenge (matches Terraform)."""
    hash_val = hashlib.md5(f"{challenge_id}-{team_num}-{event_name}".encode()).hexdigest()[:8]
    name_map = {
        "recon": "recon",
        "open_sesame": "dmz_breakout",
        "who_goes_there": "blocked",
        "tunnel_vision": "vpn_master",
        "inspector_gadget": "security_pro",
        "the_insider": "troubleshooter",
        "zero_trust": "zero_trust",
    }
    name = name_map.get(challenge_id, challenge_id)
    return f"CTF{{team{team_num}_{name}_{hash_val}}}"


def import_challenges(api, team_count, event_name, flag_server_ip=""):
    """Import all challenges into CTFd."""
    print(f"\n🎯 Importing {len(CHALLENGES)} challenges into CTFd...")
    print(f"   Teams: {team_count} | Event: {event_name}\n")

    for ch in CHALLENGES:
        # Replace placeholder with actual flag server IP
        description = ch["description"]
        if flag_server_ip:
            description = description.replace("<FLAG_SERVER>", flag_server_ip)
            description = description.replace("<UTILITY_SERVER_IP>", flag_server_ip)

        # Create challenge
        data = {
            "name": ch["name"],
            "category": ch["category"],
            "description": description,
            "value": ch["value"],
            "type": ch["type"],
            "state": ch["state"],
            "max_attempts": ch.get("max_attempts", 0),
        }

        result = api.post('/challenges', data)
        if result and result.get('success'):
            challenge_db_id = result['data']['id']
            print(f"  ✅ {ch['name']} (ID: {challenge_db_id}, {ch['value']} pts)")

            # Add flags for each team
            for team_num in range(1, team_count + 1):
                flag = generate_team_flag(ch["id"], team_num, event_name)
                flag_data = {
                    "challenge_id": challenge_db_id,
                    "content": flag,
                    "type": "static",
                    "data": f"team-{team_num}"
                }
                api.post('/flags', flag_data)

            print(f"      → {team_count} team flags added")

            # Add hint if available
            if "hint" in ch.get("description", ""):
                hint_data = {
                    "challenge_id": challenge_db_id,
                    "content": f"Check the challenge description for hints!",
                    "cost": 0,
                    "type": "standard"
                }
                api.post('/hints', hint_data)
        else:
            print(f"  ❌ Failed to create: {ch['name']}")

    print(f"\n✅ Challenge import complete!")


def create_teams(api, team_count):
    """Create team accounts in CTFd."""
    print(f"\n👥 Creating {team_count} teams...")

    for i in range(1, team_count + 1):
        team_data = {
            "name": f"Team {i}",
            "email": f"team{i}@ctf.local",
            "password": f"team{i}ctf2026",
            "type": "user",
            "verified": True,
            "hidden": False,
            "banned": False,
        }

        result = api.post('/users', team_data)
        if result and result.get('success'):
            print(f"  ✅ Team {i} (user: team{i}@ctf.local, pass: team{i}ctf2026)")
        else:
            print(f"  ⚠️  Team {i} might already exist")

    print(f"\n✅ Team creation complete!")


# ─── Main ────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description='Import challenges into CTFd')
    parser.add_argument('--url', required=True, help='CTFd URL (e.g., http://1.2.3.4)')
    parser.add_argument('--token', required=True, help='CTFd admin API token')
    parser.add_argument('--teams', type=int, default=1, help='Number of teams')
    parser.add_argument('--event', default='fortinet-ctf', help='Event name')
    parser.add_argument('--flag-server', default='', help='Flag server IP')
    parser.add_argument('--skip-teams', action='store_true', help='Skip team creation')
    args = parser.parse_args()

    api = CTFdAPI(args.url, args.token)

    # Test connection
    try:
        api.get('/challenges')
        print(f"✅ Connected to CTFd at {args.url}")
    except Exception as e:
        print(f"❌ Cannot connect to CTFd: {e}")
        sys.exit(1)

    # Import challenges
    import_challenges(api, args.teams, args.event, args.flag_server)

    # Create teams
    if not args.skip_teams:
        create_teams(api, args.teams)

    print(f"\n🏁 Setup complete! CTFd is ready at {args.url}")
    print(f"   Admin: Check admin panel for challenge management")
    print(f"   Teams: Share credentials from 'terraform output team_access'")


if __name__ == '__main__':
    main()
