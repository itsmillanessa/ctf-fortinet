#!/usr/bin/env python3
"""
Challenge definitions and validation logic.

Each challenge defines:
  - Metadata (name, category, points, description)
  - Validation function (checks if the team solved it)
  - Default flag (overridden by team-specific flags)
"""

import ipaddress
import subprocess
import socket
import logging

logger = logging.getLogger(__name__)

# ─── Challenge Definitions ───────────────────────────────────────────────

CHALLENGES = {
    "recon": {
        "name": "First Login",
        "category": "Reconnaissance",
        "points": 100,
        "difficulty": "easy",
        "description": (
            "Welcome to your FortiGate! Your first mission: find the system hostname "
            "and serial number. The flag format is CTF{hostname_serialnumber}. "
            "Hint: 'get system status' might help."
        ),
        "hint": "Check the system alias — there might be something hidden there too.",
        "default_flag": "CTF{FGT_SERIAL}",
        "validation": "manual"  # Player reads it from CLI and submits to CTFd
    },

    "open_sesame": {
        "name": "Open Sesame",
        "category": "Firewall Policy",
        "points": 100,
        "difficulty": "easy",
        "description": (
            "The DMZ server (port3) can't reach the internet! Something is blocking it. "
            "Fix the firewall policy so the DMZ can browse the web. "
            "Once fixed, the DMZ server will be able to reach a secret page with your flag."
        ),
        "hint": "Look at policy ID 2 — is it allow or deny?",
        "default_flag": "CTF{dmz_breakout_success}",
        "validation": "auto"  # Validated by checking connectivity
    },

    "who_goes_there": {
        "name": "Who Goes There?",
        "category": "Address Objects",
        "points": 100,
        "difficulty": "easy",
        "description": (
            "Create address objects to block known malicious IPs. "
            "Create an address group called 'Malicious-IPs' containing: "
            "198.51.100.10, 198.51.100.20, 198.51.100.30. "
            "Then create a DENY policy for traffic FROM these IPs. "
            "Once the policy is active and logging, check the FortiGate logs for your flag."
        ),
        "hint": "The traffic generator is sending packets from these IPs. Block them and check the logs.",
        "default_flag": "CTF{address_objects_blocked}",
        "validation": "auto"
    },

    "tunnel_vision": {
        "name": "Tunnel Vision",
        "category": "VPN",
        "points": 200,
        "difficulty": "medium",
        "description": (
            "Establish an IPsec VPN tunnel to the central server. "
            "Parameters: IKE version 2, PSK: 'CTFortinet2026', "
            "Remote gateway: <UTILITY_SERVER_IP>, "
            "Local subnet: your LAN (10.x.2.0/24), "
            "Remote subnet: 172.16.100.0/24. "
            "Once the tunnel is up, access http://172.16.100.1/vpn-flag for your flag."
        ),
        "hint": "Don't forget Phase 2 selectors — they must match exactly.",
        "default_flag": "CTF{ipsec_tunnel_master}",
        "validation": "auto"
    },

    "inspector_gadget": {
        "name": "Inspector Gadget",
        "category": "Security Profiles",
        "points": 200,
        "difficulty": "medium",
        "description": (
            "Enable security inspection on your FortiGate. "
            "1) Create an AntiVirus profile called 'ctf-av' "
            "2) Create an IPS sensor called 'ctf-ips' with signature ID 41748 enabled "
            "3) Apply both profiles to your LAN-to-WAN policy "
            "4) The traffic generator will send an EICAR test file. "
            "When detected, check FortiGate logs — your flag is in the log message."
        ),
        "hint": "Make sure SSL inspection is configured, or use certificate-inspection at minimum.",
        "default_flag": "CTF{security_profiles_active}",
        "validation": "auto"
    },

    "the_insider": {
        "name": "The Insider",
        "category": "Troubleshooting",
        "points": 300,
        "difficulty": "hard",
        "description": (
            "Something is VERY wrong with this FortiGate. Users report: "
            "1) Can't reach the internet from LAN "
            "2) DNS isn't resolving "
            "3) Some traffic goes to the wrong place "
            "4) The admin can't access the GUI remotely anymore. "
            "Find and fix ALL issues. When everything works, "
            "access http://<UTILITY_SERVER>:8080/api/flag/the_insider from your LAN."
        ),
        "hint": "Use 'diagnose debug flow' and 'diagnose sniffer' — they're your best friends.",
        "default_flag": "CTF{troubleshooting_master}",
        "validation": "auto"
    },

    "zero_trust": {
        "name": "Zero Trust Hero",
        "category": "Advanced Policy",
        "points": 300,
        "difficulty": "hard",
        "description": (
            "Implement Zero Trust segmentation: "
            "1) Create ISDB-based policies to allow ONLY HTTPS and DNS from LAN "
            "2) Block ALL traffic between LAN and DMZ except SSH (port 22) "
            "3) Enable application control to block social media "
            "4) All denied traffic must be logged "
            "Once properly configured, the validator will check your config and reveal the flag."
        ),
        "hint": "Security Rating > 60% is required. Check 'get security rating' for hints.",
        "default_flag": "CTF{zero_trust_implemented}",
        "validation": "auto"
    }
}


# ─── Team Identification ─────────────────────────────────────────────────

def get_team_from_ip(source_ip, team_configs):
    """Identify which team an IP belongs to based on their subnet ranges."""
    try:
        ip = ipaddress.ip_address(source_ip)
    except ValueError:
        return None

    for team_id, config in team_configs.items():
        for subnet_key in ['lan_subnet', 'dmz_subnet', 'wan_subnet']:
            subnet = config.get(subnet_key)
            if subnet:
                try:
                    if ip in ipaddress.ip_network(subnet, strict=False):
                        return team_id
                except ValueError:
                    continue

    # Fallback: check if IP matches FortiGate WAN IPs
    for team_id, config in team_configs.items():
        if source_ip == config.get('fgt_wan_ip'):
            return team_id

    return None


# ─── Validation Functions ────────────────────────────────────────────────

def validate_challenge(challenge_id, team_id, team_config, source_ip):
    """
    Validate whether a team has solved a challenge.
    Returns: {"solved": bool, "reason": str, "hints": list}
    """
    validators = {
        "recon": validate_recon,
        "open_sesame": validate_open_sesame,
        "who_goes_there": validate_who_goes_there,
        "tunnel_vision": validate_tunnel_vision,
        "inspector_gadget": validate_inspector_gadget,
        "the_insider": validate_the_insider,
        "zero_trust": validate_zero_trust,
    }

    validator = validators.get(challenge_id)
    if not validator:
        return {"solved": False, "reason": "No validator for this challenge"}

    return validator(team_id, team_config, source_ip)


def validate_recon(team_id, team_config, source_ip):
    """Manual validation — player submits flag directly to CTFd."""
    return {
        "solved": True,
        "message": "This is a manual challenge. Find the flag in the FortiGate CLI and submit to CTFd."
    }


def validate_open_sesame(team_id, team_config, source_ip):
    """
    Check if DMZ can reach the internet (i.e., this server).
    If the request came from the DMZ subnet, the challenge is solved.
    """
    dmz_subnet = team_config.get('dmz_subnet', '')

    try:
        ip = ipaddress.ip_address(source_ip)
        if dmz_subnet and ip in ipaddress.ip_network(dmz_subnet, strict=False):
            return {"solved": True, "message": "DMZ connectivity verified!"}
    except ValueError:
        pass

    # Also check if we can reach the DMZ server via the FortiGate
    fgt_wan_ip = team_config.get('fgt_wan_ip', '')
    if fgt_wan_ip:
        # Try to ping through the FortiGate
        try:
            result = subprocess.run(
                ['curl', '-s', '-o', '/dev/null', '-w', '%{http_code}',
                 '--connect-timeout', '3', f'http://{fgt_wan_ip}:8080/test'],
                capture_output=True, text=True, timeout=5
            )
            # If we got any response, connectivity exists
        except Exception:
            pass

    return {
        "solved": False,
        "reason": "DMZ still can't reach the internet.",
        "hints": [
            "Check firewall policy ID 2 — it's currently set to DENY",
            "The DMZ interface is port3",
            "Don't forget to enable NAT on the policy"
        ]
    }


def validate_who_goes_there(team_id, team_config, source_ip):
    """
    Check if the FortiGate has address objects and deny policy configured.
    We verify by SSH-ing to the FortiGate and checking config.
    """
    fgt_wan_ip = team_config.get('fgt_wan_ip', '')
    if not fgt_wan_ip:
        return {"solved": False, "reason": "FortiGate IP not configured"}

    try:
        import paramiko
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(fgt_wan_ip, username='ctfplayer', password='CTFPlayer2026!', timeout=5)

        # Check for address group
        stdin, stdout, stderr = ssh.exec_command('config firewall addrgrp\nshow\nend')
        addrgrp_output = stdout.read().decode()

        # Check for deny policy
        stdin, stdout, stderr = ssh.exec_command('show firewall policy')
        policy_output = stdout.read().decode()

        ssh.close()

        has_addrgrp = 'Malicious-IPs' in addrgrp_output or 'malicious' in addrgrp_output.lower()
        has_deny = 'deny' in policy_output.lower() and ('198.51.100' in policy_output or 'Malicious' in policy_output)

        if has_addrgrp and has_deny:
            return {"solved": True, "message": "Malicious IPs successfully blocked!"}
        else:
            hints = []
            if not has_addrgrp:
                hints.append("Address group 'Malicious-IPs' not found. Create it with the 3 IPs.")
            if not has_deny:
                hints.append("No deny policy found referencing the malicious addresses.")
            return {"solved": False, "reason": "Configuration incomplete.", "hints": hints}

    except Exception as e:
        logger.error(f"SSH validation failed for {team_id}: {e}")
        return {
            "solved": False,
            "reason": "Could not connect to your FortiGate for validation.",
            "hints": ["Make sure SSH is enabled on the WAN interface (port1)"]
        }


def validate_tunnel_vision(team_id, team_config, source_ip):
    """
    Check if VPN tunnel is established by seeing if request comes through VPN.
    """
    # If the request source is from the team's LAN and routed through VPN
    try:
        ip = ipaddress.ip_address(source_ip)
        lan_subnet = team_config.get('lan_subnet', '')
        if lan_subnet and ip in ipaddress.ip_network(lan_subnet, strict=False):
            return {"solved": True, "message": "IPsec tunnel verified! Traffic flowing through VPN."}
    except ValueError:
        pass

    return {
        "solved": False,
        "reason": "VPN tunnel not detected.",
        "hints": [
            "Make sure Phase 1 uses IKEv2 with PSK 'CTFortinet2026'",
            "Phase 2 selectors: local=10.x.2.0/24, remote=172.16.100.0/24",
            "Bring the tunnel up with 'diag vpn ike gateway list'"
        ]
    }


def validate_inspector_gadget(team_id, team_config, source_ip):
    """
    Check if security profiles are configured on the FortiGate.
    """
    fgt_wan_ip = team_config.get('fgt_wan_ip', '')
    if not fgt_wan_ip:
        return {"solved": False, "reason": "FortiGate IP not configured"}

    try:
        import paramiko
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(fgt_wan_ip, username='ctfplayer', password='CTFPlayer2026!', timeout=5)

        # Check AV profile
        stdin, stdout, stderr = ssh.exec_command('show antivirus profile ctf-av')
        av_output = stdout.read().decode()

        # Check IPS sensor
        stdin, stdout, stderr = ssh.exec_command('show ips sensor ctf-ips')
        ips_output = stdout.read().decode()

        # Check if applied to policy
        stdin, stdout, stderr = ssh.exec_command('show firewall policy 1')
        policy_output = stdout.read().decode()

        ssh.close()

        has_av = 'ctf-av' in av_output and 'config' in av_output
        has_ips = 'ctf-ips' in ips_output and 'config' in ips_output
        profiles_applied = 'av-profile' in policy_output and 'ips-sensor' in policy_output

        if has_av and has_ips and profiles_applied:
            return {"solved": True, "message": "Security profiles configured and applied!"}
        else:
            hints = []
            if not has_av:
                hints.append("AntiVirus profile 'ctf-av' not found.")
            if not has_ips:
                hints.append("IPS sensor 'ctf-ips' not found.")
            if not profiles_applied:
                hints.append("Profiles not applied to the LAN-to-WAN policy (policy 1).")
            return {"solved": False, "reason": "Security profiles incomplete.", "hints": hints}

    except Exception as e:
        logger.error(f"SSH validation failed for {team_id}: {e}")
        return {
            "solved": False,
            "reason": "Could not connect to your FortiGate.",
            "hints": ["Make sure SSH is enabled on WAN interface"]
        }


def validate_the_insider(team_id, team_config, source_ip):
    """
    The Insider: Multiple things are broken. Check if they're all fixed.
    If the request reaches us from the LAN, most things are working.
    """
    lan_subnet = team_config.get('lan_subnet', '')
    fgt_wan_ip = team_config.get('fgt_wan_ip', '')

    checks = {
        "lan_connectivity": False,
        "dns_working": False,
        "correct_routing": False,
        "gui_access": False
    }

    # Check 1: LAN can reach us (if source is from LAN)
    try:
        ip = ipaddress.ip_address(source_ip)
        if lan_subnet and ip in ipaddress.ip_network(lan_subnet, strict=False):
            checks["lan_connectivity"] = True
    except ValueError:
        pass

    # Check 2-4: SSH into FortiGate and verify config
    if fgt_wan_ip:
        try:
            import paramiko
            ssh = paramiko.SSHClient()
            ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            ssh.connect(fgt_wan_ip, username='ctfplayer', password='CTFPlayer2026!', timeout=5)

            # Check DNS
            stdin, stdout, stderr = ssh.exec_command('diag test application dnsproxy 1')
            dns_output = stdout.read().decode()
            checks["dns_working"] = '8.8.8.8' in dns_output or '8.8.4.4' in dns_output

            # Check routing
            stdin, stdout, stderr = ssh.exec_command('get router info routing-table static')
            route_output = stdout.read().decode()
            checks["correct_routing"] = '0.0.0.0' in route_output

            # Check GUI access
            stdin, stdout, stderr = ssh.exec_command('show system interface port1')
            iface_output = stdout.read().decode()
            checks["gui_access"] = 'https' in iface_output

            ssh.close()
        except Exception as e:
            logger.error(f"SSH check failed for {team_id}: {e}")

    all_passed = all(checks.values())
    failed = [k for k, v in checks.items() if not v]

    if all_passed:
        return {"solved": True, "message": "All issues fixed! You're a troubleshooting master!"}
    else:
        hints = []
        if not checks["lan_connectivity"]:
            hints.append("LAN still can't reach the internet — check the default route and NAT")
        if not checks["dns_working"]:
            hints.append("DNS is misconfigured — check 'config system dns'")
        if not checks["correct_routing"]:
            hints.append("Routing table looks wrong — check static routes")
        if not checks["gui_access"]:
            hints.append("HTTPS not enabled on WAN interface for GUI access")

        return {
            "solved": False,
            "reason": f"{len(failed)}/{len(checks)} issues remain.",
            "hints": hints,
            "checks": checks
        }


def validate_zero_trust(team_id, team_config, source_ip):
    """
    Zero Trust: Check for ISDB policies, micro-segmentation, app control.
    """
    fgt_wan_ip = team_config.get('fgt_wan_ip', '')
    if not fgt_wan_ip:
        return {"solved": False, "reason": "FortiGate IP not configured"}

    try:
        import paramiko
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(fgt_wan_ip, username='ctfplayer', password='CTFPlayer2026!', timeout=5)

        # Check for ISDB-based policies
        stdin, stdout, stderr = ssh.exec_command('show firewall policy')
        policy_output = stdout.read().decode()

        # Check for application control
        stdin, stdout, stderr = ssh.exec_command('show application list')
        appctrl_output = stdout.read().decode()

        # Check implicit deny logging
        stdin, stdout, stderr = ssh.exec_command('show log setting')
        log_output = stdout.read().decode()

        ssh.close()

        has_isdb = 'internet-service-id' in policy_output or 'internet-service-name' in policy_output
        has_appctrl = 'social' in appctrl_output.lower() or 'block' in appctrl_output.lower()
        has_logging = 'fwpolicy-implicit-log' in log_output and 'enable' in log_output
        has_segmentation = policy_output.count('set action deny') >= 2  # At least 2 deny rules

        all_good = has_isdb and has_appctrl and has_logging and has_segmentation

        if all_good:
            return {"solved": True, "message": "Zero Trust architecture implemented! Impressive."}
        else:
            hints = []
            if not has_isdb:
                hints.append("No ISDB-based policies found. Use 'internet-service-name' in your policies.")
            if not has_appctrl:
                hints.append("Application control not blocking social media.")
            if not has_logging:
                hints.append("Implicit deny logging not enabled.")
            if not has_segmentation:
                hints.append("Need more segmentation policies between zones.")

            return {"solved": False, "reason": "Zero Trust configuration incomplete.", "hints": hints}

    except Exception as e:
        logger.error(f"SSH validation failed for {team_id}: {e}")
        return {
            "solved": False,
            "reason": "Could not validate your FortiGate config.",
            "hints": ["Ensure SSH is accessible on the WAN interface"]
        }
