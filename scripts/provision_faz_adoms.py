#!/usr/bin/env python3
"""
FortiAnalyzer ADOM Provisioning Script

Provisions ADOMs and team users for CTF multi-team setup.
Run this after manually accepting the EULA and setting admin password.

Usage:
    python provision_faz_adoms.py --faz-ip 54.163.46.16 --password FortiCTF2026! --teams 5
    python provision_faz_adoms.py --config adom_config.json
"""

import argparse
import json
import requests
import sys
import time
import urllib3

# Disable SSL warnings for self-signed certs
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


class FortiAnalyzerAPI:
    """FortiAnalyzer JSON-RPC API client."""
    
    def __init__(self, host, username="admin", password=""):
        self.host = host
        self.username = username
        self.password = password
        self.session = None
        self.base_url = f"https://{host}/jsonrpc"
    
    def login(self):
        """Login and get session token."""
        payload = {
            "method": "exec",
            "params": [{
                "url": "/sys/login/user",
                "data": {
                    "user": self.username,
                    "passwd": self.password
                }
            }],
            "id": 1
        }
        
        resp = requests.post(self.base_url, json=payload, verify=False)
        result = resp.json()
        
        if result.get("result", [{}])[0].get("status", {}).get("code") == 0:
            self.session = result.get("session")
            print(f"✅ Logged in to FortiAnalyzer {self.host}")
            return True
        else:
            error = result.get("result", [{}])[0].get("status", {}).get("message", "Unknown error")
            print(f"❌ Login failed: {error}")
            return False
    
    def logout(self):
        """Logout and invalidate session."""
        if not self.session:
            return
        
        payload = {
            "method": "exec",
            "params": [{"url": "/sys/logout"}],
            "session": self.session,
            "id": 999
        }
        requests.post(self.base_url, json=payload, verify=False)
        self.session = None
    
    def _request(self, method, url, data=None):
        """Make authenticated API request."""
        if not self.session:
            raise Exception("Not logged in")
        
        payload = {
            "method": method,
            "params": [{"url": url}],
            "session": self.session,
            "id": int(time.time())
        }
        
        if data:
            payload["params"][0]["data"] = data
        
        resp = requests.post(self.base_url, json=payload, verify=False)
        return resp.json()
    
    def enable_adoms(self):
        """Enable ADOM mode."""
        print("Enabling ADOM mode...")
        result = self._request("set", "/cli/global/system/global", {
            "adom-status": "enable"
        })
        
        if result.get("result", [{}])[0].get("status", {}).get("code") == 0:
            print("✅ ADOM mode enabled")
            return True
        else:
            print(f"⚠️ ADOM mode may already be enabled or requires reboot")
            return False
    
    def create_adom(self, name, description="CTF Team ADOM"):
        """Create a new ADOM."""
        print(f"Creating ADOM: {name}")
        result = self._request("add", "/dvmdb/adom", {
            "name": name,
            "desc": description,
            "flags": ["no_vpn_console"],
            "state": 1
        })
        
        status = result.get("result", [{}])[0].get("status", {})
        if status.get("code") == 0:
            print(f"✅ ADOM '{name}' created")
            return True
        elif "already exists" in status.get("message", "").lower():
            print(f"ℹ️ ADOM '{name}' already exists")
            return True
        else:
            print(f"❌ Failed to create ADOM: {status.get('message')}")
            return False
    
    def create_user(self, username, password, adom_name, profile="Standard_User"):
        """Create an admin user with access to specific ADOM."""
        print(f"Creating user: {username} for ADOM: {adom_name}")
        result = self._request("add", "/cli/global/system/admin/user", {
            "userid": username,
            "password": password,
            "profileid": profile,
            "adom": [{"adom-name": adom_name}],
            "rpc-permit": "read-write",
            "description": f"CTF analyst for {adom_name}"
        })
        
        status = result.get("result", [{}])[0].get("status", {})
        if status.get("code") == 0:
            print(f"✅ User '{username}' created")
            return True
        elif "already exists" in status.get("message", "").lower():
            print(f"ℹ️ User '{username}' already exists")
            return True
        else:
            print(f"❌ Failed to create user: {status.get('message')}")
            return False
    
    def get_adoms(self):
        """List all ADOMs."""
        result = self._request("get", "/dvmdb/adom")
        return result.get("result", [{}])[0].get("data", [])
    
    def get_system_status(self):
        """Get system status."""
        result = self._request("get", "/cli/global/system/status")
        return result.get("result", [{}])[0].get("data", {})


def provision_ctf_adoms(faz_ip, password, team_count=1, team_prefix="team"):
    """Provision ADOMs for CTF teams."""
    
    faz = FortiAnalyzerAPI(faz_ip, password=password)
    
    if not faz.login():
        return False
    
    try:
        # Enable ADOMs
        faz.enable_adoms()
        
        # Create ADOMs and users for each team
        for i in range(1, team_count + 1):
            team_id = f"{team_prefix}-{i}"
            adom_name = f"ADOM-{team_id}"
            analyst_user = f"{team_id}-analyst"
            analyst_pass = f"CTF{team_id}2026!"
            
            # Create ADOM
            faz.create_adom(adom_name, f"CTF Team {i} Administrative Domain")
            
            # Create analyst user
            faz.create_user(analyst_user, analyst_pass, adom_name)
            
            print(f"  Team {i}: ADOM={adom_name}, User={analyst_user}, Pass={analyst_pass}")
        
        # List created ADOMs
        print("\n📋 Current ADOMs:")
        for adom in faz.get_adoms():
            print(f"  - {adom.get('name')}")
        
        print("\n✅ ADOM provisioning complete!")
        return True
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return False
    finally:
        faz.logout()


def main():
    parser = argparse.ArgumentParser(description="FortiAnalyzer ADOM Provisioning")
    parser.add_argument("--faz-ip", required=True, help="FortiAnalyzer IP address")
    parser.add_argument("--password", default="FortiCTF2026!", help="Admin password")
    parser.add_argument("--teams", type=int, default=1, help="Number of teams to provision")
    parser.add_argument("--team-prefix", default="team", help="Team name prefix")
    parser.add_argument("--config", help="JSON config file (alternative to CLI args)")
    
    args = parser.parse_args()
    
    if args.config:
        with open(args.config) as f:
            config = json.load(f)
        faz_ip = config.get("faz_ip", args.faz_ip)
        password = config.get("admin_password", args.password)
        teams = len(config.get("teams", {})) or args.teams
    else:
        faz_ip = args.faz_ip
        password = args.password
        teams = args.teams
    
    print(f"🔧 Provisioning {teams} team(s) on FortiAnalyzer {faz_ip}")
    print("=" * 50)
    
    success = provision_ctf_adoms(faz_ip, password, teams, args.team_prefix)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
