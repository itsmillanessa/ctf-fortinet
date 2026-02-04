# 🎯 Fortinet CTF Platform

**Capture The Flag platform for Fortinet pre-sales workshops and events.**

## Overview

- **Audience:** Fortinet customers (workshops/events)
- **Capacity:** ~50 participants (10 teams × 5 people)
- **Duration:** 4-hour events
- **Format:** In-person first, hybrid later
- **Infrastructure:** AWS (spot instances for cost optimization)

## Architecture

```
                         Internet
                            │
                    ┌───────┴────────┐
                    │  CTFd Portal   │  ← Scoring & scoreboard
                    │  (t3.medium)   │
                    └───────┬────────┘
                            │
                    ┌───────┴────────┐
                    │ Utility Server │  ← Flag server (Flask) + Traffic gen
                    │  (t3.micro)    │
                    └───────┬────────┘
                            │  VPC Peering
           ┌────────────────┼────────────────┐
           │                │                │
      ┌────┴─────┐    ┌────┴─────┐    ┌────┴─────┐
      │  Team 1  │    │  Team 2  │    │  Team N  │
      │ VPC /16  │    │ VPC /16  │    │ VPC /16  │
      │          │    │          │    │          │
      │ FortiGate│    │ FortiGate│    │ FortiGate│
      │ WAN/LAN/ │    │ WAN/LAN/ │    │ WAN/LAN/ │
      │   DMZ    │    │   DMZ    │    │   DMZ    │
      └──────────┘    └──────────┘    └──────────┘
```

## Components

| Component | Instance | Purpose |
|-----------|----------|---------|
| **FortiGate** (×N) | c5.large spot | Firewall per team — challenges target |
| **CTFd** | t3.medium | Scoring portal, scoreboard, team management |
| **Utility Server** | t3.micro | Flag server (Flask API) + Traffic generator |

## Quick Start

```bash
# 1. Configure credentials
source terraform/environments/dev/aws_creds.env

# 2. Deploy (1 team for testing)
cd terraform/environments/dev
terraform init
terraform apply -var="team_count=1"

# 3. Deploy with broken config (The Insider challenge)
terraform apply -var="team_count=1" -var="challenge_mode=the_insider"

# 4. Full event (10 teams)
terraform apply -var="team_count=10"

# 5. Destroy after event
terraform destroy
```

## Challenges (Phase 1 — FortiGate Only)

| # | Name | Difficulty | Points | Category |
|---|------|-----------|--------|----------|
| 1 | First Login | 🟢 Easy | 100 | Reconnaissance |
| 2 | Open Sesame | 🟢 Easy | 100 | Firewall Policy |
| 3 | Who Goes There? | 🟢 Easy | 100 | Address Objects |
| 4 | Tunnel Vision | 🟡 Medium | 200 | VPN |
| 5 | Inspector Gadget | 🟡 Medium | 200 | Security Profiles |
| 6 | The Insider | 🔴 Hard | 300 | Troubleshooting |
| 7 | Zero Trust Hero | 🔴 Hard | 300 | Advanced Policy |

**Total: 1,300 points** (+ time bonuses)

## Flag Delivery

Flags are **hidden and conditional** — teams must actually solve the problem:

- **Web pages** that appear only when connectivity is fixed
- **API endpoints** that validate FortiGate config via SSH
- **CLI output** hidden in system config
- **Log entries** that appear after proper security profile config

Each team gets **unique flags** (hash-based) — no copying between teams!

## Cost

| Scenario | Estimated Cost |
|----------|---------------|
| 1 team (testing) | ~$1.50/hr |
| 10 teams (full event) | ~$3.50/hr |
| 4-hour event (10 teams) | ~$14 total |

Using spot instances saves ~70% vs on-demand.

## Project Structure

```
ctf-fortinet/
├── terraform/
│   ├── modules/
│   │   ├── network/       # VPC per team (WAN/LAN/DMZ)
│   │   ├── fortigate/     # FortiGate VM + bootstrap config
│   │   ├── ctfd/          # CTFd scoring portal
│   │   └── utility/       # Flag server + traffic generator
│   │       └── files/
│   │           ├── flagserver/   # Flask API (app.py + challenges.py)
│   │           └── trafficgen/   # Traffic generator (generator.py)
│   └── environments/
│       └── dev/           # Dev/testing environment
├── challenges/
│   └── phase1/            # Challenge documentation
├── scripts/               # Deploy/destroy/reset scripts
└── README.md
```

## Phases

### Phase 1 — MVP ✅ (current)
- [x] Network module (isolated VPC per team)
- [x] FortiGate module (VM + bootstrap + broken configs)
- [x] CTFd portal setup
- [x] Utility server (flag server + traffic gen)
- [x] 7 challenges with auto-validation
- [x] VPC peering for cross-VPC communication
- [x] Unique flags per team
- [ ] End-to-end testing
- [ ] CTFd challenge import script

### Phase 2 — Full Stack
- [ ] FortiAnalyzer module
- [ ] FortiManager module
- [ ] FortiFlex API integration
- [ ] 15-20 challenges
- [ ] Team reset capability

### Phase 3 — Polish
- [ ] Fortinet branding
- [ ] Post-event reports
- [ ] Documentation for other SEs
