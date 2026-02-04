#!/usr/bin/env python3
"""
CTF Flag Server — Serves flags to teams that solve challenges.

Each challenge has conditions that must be met before the flag is revealed.
The server identifies teams by source IP (subnet-based).

Endpoints:
  GET  /                          → Server status
  GET  /api/health                → Health check
  GET  /api/flag/<challenge_id>   → Get flag (validates conditions first)
  GET  /api/challenges            → List available challenges
  POST /api/validate/<challenge_id> → Manual validation trigger
"""

import json
import os
import logging
from flask import Flask, request, jsonify
from challenges import CHALLENGES, validate_challenge, get_team_from_ip

app = Flask(__name__)
logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)

# Load team configs
TEAM_CONFIGS = {}
config_path = '/opt/ctf/team_configs.json'
if os.path.exists(config_path):
    with open(config_path) as f:
        TEAM_CONFIGS = json.load(f)
    logger.info(f"Loaded configs for {len(TEAM_CONFIGS)} teams")
else:
    logger.warning("No team configs found — running in dev mode")


# ─── Solved flags tracking ───────────────────────────────────────────────
SOLVED = {}  # {team_id: {challenge_id: timestamp}}
SOLVE_LOG = '/opt/ctf/logs/solves.json'

def load_solves():
    global SOLVED
    if os.path.exists(SOLVE_LOG):
        with open(SOLVE_LOG) as f:
            SOLVED = json.load(f)

def save_solves():
    os.makedirs(os.path.dirname(SOLVE_LOG), exist_ok=True)
    with open(SOLVE_LOG, 'w') as f:
        json.dump(SOLVED, f, indent=2)

load_solves()


# ─── Routes ──────────────────────────────────────────────────────────────

@app.route('/')
def index():
    return jsonify({
        "service": "CTF Flag Server",
        "version": "1.0.0",
        "challenges": len(CHALLENGES),
        "teams": len(TEAM_CONFIGS),
        "status": "running"
    })


@app.route('/api/health')
def health():
    return jsonify({"status": "ok"})


@app.route('/api/challenges')
def list_challenges():
    """List all challenges (without flags)."""
    team_id = get_team_from_ip(request.remote_addr, TEAM_CONFIGS)

    challenges = []
    for cid, challenge in CHALLENGES.items():
        solved = False
        if team_id and team_id in SOLVED and cid in SOLVED[team_id]:
            solved = True

        challenges.append({
            "id": cid,
            "name": challenge["name"],
            "category": challenge["category"],
            "points": challenge["points"],
            "description": challenge["description"],
            "hint": challenge.get("hint", ""),
            "solved": solved
        })

    return jsonify({
        "team": team_id,
        "challenges": sorted(challenges, key=lambda x: x["points"])
    })


@app.route('/api/flag/<challenge_id>')
def get_flag(challenge_id):
    """
    Attempt to get a flag. Validates the challenge conditions first.
    The team is identified by source IP.
    """
    source_ip = request.remote_addr
    team_id = get_team_from_ip(source_ip, TEAM_CONFIGS)

    if not team_id:
        logger.warning(f"Unknown team from IP {source_ip}")
        return jsonify({
            "error": "Unknown team",
            "message": "Your IP doesn't match any registered team.",
            "source_ip": source_ip
        }), 403

    if challenge_id not in CHALLENGES:
        return jsonify({"error": f"Challenge '{challenge_id}' not found"}), 404

    challenge = CHALLENGES[challenge_id]
    team_config = TEAM_CONFIGS.get(team_id, {})

    # Validate the challenge conditions
    logger.info(f"Team {team_id} attempting challenge '{challenge_id}' from {source_ip}")

    try:
        result = validate_challenge(challenge_id, team_id, team_config, source_ip)
    except Exception as e:
        logger.error(f"Validation error for {challenge_id}: {e}")
        return jsonify({
            "error": "Validation failed",
            "message": "Something went wrong checking your solution. Try again.",
            "details": str(e)
        }), 500

    if result["solved"]:
        # Get the team-specific flag
        flag = team_config.get("flags", {}).get(challenge_id, challenge.get("default_flag", "CTF{flag_not_set}"))

        # Record the solve
        if team_id not in SOLVED:
            SOLVED[team_id] = {}
        if challenge_id not in SOLVED[team_id]:
            from datetime import datetime
            SOLVED[team_id][challenge_id] = datetime.utcnow().isoformat()
            save_solves()
            logger.info(f"🏁 Team {team_id} SOLVED '{challenge_id}' — Flag: {flag}")

        return jsonify({
            "solved": True,
            "flag": flag,
            "challenge": challenge["name"],
            "points": challenge["points"],
            "message": result.get("message", "Congratulations! Submit this flag to CTFd.")
        })
    else:
        logger.info(f"Team {team_id} FAILED '{challenge_id}': {result.get('reason', 'unknown')}")
        return jsonify({
            "solved": False,
            "challenge": challenge["name"],
            "reason": result.get("reason", "Challenge conditions not met."),
            "hints": result.get("hints", [])
        })


@app.route('/api/validate/<challenge_id>', methods=['POST'])
def manual_validate(challenge_id):
    """Admin endpoint to manually trigger validation for a team."""
    data = request.get_json() or {}
    team_id = data.get("team_id")
    admin_key = data.get("admin_key")

    # Simple admin auth
    if admin_key != os.environ.get("CTF_ADMIN_KEY", "FortineCTFAdmin2026!"):
        return jsonify({"error": "Unauthorized"}), 401

    if not team_id or challenge_id not in CHALLENGES:
        return jsonify({"error": "Invalid team_id or challenge_id"}), 400

    team_config = TEAM_CONFIGS.get(team_id, {})
    result = validate_challenge(challenge_id, team_id, team_config, "admin")

    return jsonify(result)


@app.route('/api/scoreboard')
def scoreboard():
    """Simple scoreboard endpoint."""
    scores = {}
    for team_id, solves in SOLVED.items():
        total = 0
        for cid in solves:
            if cid in CHALLENGES:
                total += CHALLENGES[cid]["points"]
        scores[team_id] = {
            "total_points": total,
            "challenges_solved": len(solves),
            "solves": list(solves.keys())
        }

    ranked = sorted(scores.items(), key=lambda x: x[1]["total_points"], reverse=True)
    return jsonify({
        "scoreboard": [{"rank": i+1, "team": t, **s} for i, (t, s) in enumerate(ranked)]
    })


# ─── Special endpoints for challenge-specific services ───────────────────

@app.route('/secret-page')
def secret_page():
    """
    Challenge 2 (Open Sesame): This page is only reachable from DMZ.
    If you can reach it, you solved the challenge!
    """
    source_ip = request.remote_addr
    team_id = get_team_from_ip(source_ip, TEAM_CONFIGS)

    if team_id:
        flag = TEAM_CONFIGS.get(team_id, {}).get("flags", {}).get("open_sesame", "CTF{dmz_to_internet_unlocked}")
        return f"""
        <html>
        <body style="background:#1a1a2e;color:#0f0;font-family:monospace;padding:40px;">
            <h1>🏁 ACCESS GRANTED</h1>
            <p>You've successfully configured DMZ internet access!</p>
            <h2>Your flag: <code style="color:#ff0;font-size:24px;">{flag}</code></h2>
            <p>Submit this flag to CTFd to earn your points.</p>
            <p style="color:#666;">Team: {team_id} | Source: {source_ip}</p>
        </body>
        </html>
        """
    return "Access Denied", 403


@app.route('/vpn-flag')
def vpn_flag():
    """
    Challenge 4 (Tunnel Vision): Only reachable through IPsec tunnel.
    """
    source_ip = request.remote_addr
    team_id = get_team_from_ip(source_ip, TEAM_CONFIGS)

    if team_id:
        flag = TEAM_CONFIGS.get(team_id, {}).get("flags", {}).get("tunnel_vision", "CTF{ipsec_tunnel_established}")
        return jsonify({"flag": flag, "message": "VPN tunnel verified! Great job."})
    return jsonify({"error": "Not reachable via VPN"}), 403


if __name__ == '__main__':
    port = int(os.environ.get('FLAG_SERVER_PORT', 8080))
    logger.info(f"Starting CTF Flag Server on port {port}")
    app.run(host='0.0.0.0', port=port, debug=False)
