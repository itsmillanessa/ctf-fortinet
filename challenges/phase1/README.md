# Phase 1 Challenges — FortiGate Only

## Architecture

```
                    ┌──────────────────┐
                    │   CTFd Portal    │
                    │  (Scoreboard)    │
                    └────────┬─────────┘
                             │
                    ┌────────┴─────────┐
                    │  Utility Server  │
                    │  - Flag Server   │
                    │  - Traffic Gen   │
                    └────────┬─────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
   ┌────┴────┐         ┌────┴────┐         ┌────┴────┐
   │  Team 1  │         │  Team 2  │         │  Team N  │
   │FortiGate │         │FortiGate │         │FortiGate │
   │WAN/LAN/  │         │WAN/LAN/  │         │WAN/LAN/  │
   │   DMZ    │         │   DMZ    │         │   DMZ    │
   └──────────┘         └──────────┘         └──────────┘
```

## Challenge List

### 🟢 Easy (100 pts each)

#### 1. "First Login" — Reconnaissance
- **ID:** `recon`
- **Objective:** Find the system hostname and serial number
- **How to solve:** Run `get system status` on FortiGate CLI
- **Flag:** Found in system alias: `CTF{hostname_serialnumber}`
- **Validation:** Manual — player submits flag to CTFd
- **Skills:** Basic FortiGate CLI navigation

#### 2. "Open Sesame" — Firewall Policy
- **ID:** `open_sesame`
- **Objective:** DMZ server can't reach the internet — fix it!
- **How to solve:** Change policy ID 2 from DENY to ACCEPT, enable NAT
- **Flag:** Hidden on a web page only reachable from DMZ (`/secret-page`)
- **Validation:** Auto — flag server checks if request comes from DMZ subnet
- **Traffic:** Utility server provides target page at port 8080
- **Skills:** Firewall policies, NAT, interfaces

#### 3. "Who Goes There?" — Address Objects
- **ID:** `who_goes_there`
- **Objective:** Block known malicious IPs
- **How to solve:**
  1. Create address objects for 198.51.100.10, .20, .30
  2. Create address group "Malicious-IPs"
  3. Create DENY policy for inbound traffic from these IPs
- **Flag:** Revealed via `/api/flag/who_goes_there` after SSH validation
- **Validation:** Auto — SSH into FGT, check address group + deny policy exist
- **Traffic:** Traffic generator sends spoofed packets from malicious IPs
- **Skills:** Address objects, address groups, security policies

---

### 🟡 Medium (200 pts each)

#### 4. "Tunnel Vision" — VPN Configuration
- **ID:** `tunnel_vision`
- **Objective:** Establish IPsec VPN to central server
- **How to solve:**
  1. Configure Phase 1: IKEv2, PSK: `CTFortinet2026`, Remote: utility server IP
  2. Configure Phase 2: Local 10.x.2.0/24, Remote 172.16.100.0/24
  3. Bring tunnel up, access flag through tunnel
- **Flag:** On `/vpn-flag` endpoint (only via VPN)
- **Validation:** Auto — request must come from team's LAN subnet via tunnel
- **Skills:** IPsec VPN, Phase 1/2, routing

#### 5. "Inspector Gadget" — Security Profiles
- **ID:** `inspector_gadget`
- **Objective:** Configure and apply security inspection
- **How to solve:**
  1. Create AV profile named `ctf-av`
  2. Create IPS sensor named `ctf-ips` (signature 41748)
  3. Apply both to LAN-to-WAN policy (policy 1)
- **Flag:** Revealed after SSH validation confirms profiles exist + applied
- **Validation:** Auto — SSH checks AV profile, IPS sensor, policy config
- **Traffic:** EICAR test files + exploit payloads sent through FortiGate
- **Skills:** UTM profiles, AV, IPS, SSL inspection

---

### 🔴 Hard (300 pts each)

#### 6. "The Insider" — Troubleshooting
- **ID:** `the_insider`
- **Objective:** Someone sabotaged the FortiGate — fix everything!
- **Pre-broken config (4 issues):**
  1. ❌ Wrong default route → 10.x.1.99 (doesn't exist)
  2. ❌ DNS servers → 192.0.2.1/2 (unreachable RFC 5737)
  3. ❌ NAT disabled on LAN-to-WAN policy
  4. ❌ HTTPS removed from WAN interface (no GUI access remotely)
- **How to solve:** Find and fix all 4 issues
- **Flag:** Access `/api/flag/the_insider` from LAN when all checks pass
- **Validation:** Auto — SSH checks DNS, routes, NAT, interface config
- **Skills:** Troubleshooting, debug flow, sniffer, systematic diagnosis

#### 7. "Zero Trust Hero" — Advanced Policy
- **ID:** `zero_trust`
- **Objective:** Implement Zero Trust segmentation
- **How to solve:**
  1. ISDB-based policies (only HTTPS + DNS from LAN)
  2. Block LAN↔DMZ except SSH
  3. Application control blocking social media
  4. All denied traffic logged
- **Flag:** Revealed after SSH config validation
- **Validation:** Auto — checks ISDB policies, app control, logging, deny rules
- **Skills:** ISDB, application control, micro-segmentation

---

## Scoring

| Difficulty | Points | Time Bonus |
|-----------|--------|------------|
| Easy      | 100    | +50 if solved in <10min |
| Medium    | 200    | +100 if solved in <20min |
| Hard      | 300    | +150 if solved in <30min |

## Flag Delivery Methods

| Method | Challenges | How it works |
|--------|-----------|--------------|
| **Manual** | recon | Player reads flag from CLI, submits to CTFd |
| **Web page** | open_sesame, tunnel_vision | Flag appears on web page when accessible |
| **API validation** | who_goes_there, inspector_gadget, the_insider, zero_trust | Flag server SSHs into FGT, validates config, returns flag |

## Traffic Generator Patterns

| Pattern | Challenges | What it does |
|---------|-----------|--------------|
| Legitimate | all | HTTP/HTTPS/DNS to common targets |
| Malicious IPs | who_goes_there | Spoofed packets from 198.51.100.x |
| EICAR | inspector_gadget | AV test files through HTTP |
| Exploits | inspector_gadget | SQL injection, XSS, shellshock payloads |
