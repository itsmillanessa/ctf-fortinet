#!/usr/bin/env python3
"""
CTF Flag Server v2 — Enhanced for Fortinet CTF Phases 1 & 2

Supports both static flags (Phase 1 - FortiGate) and dynamic analytical flags (Phase 2 - FortiAnalyzer).

PHASE 1: Static flags embedded in configurations
PHASE 2: Dynamic flags computed from real attack data analysis

Admin Features:
- Real-time flag monitoring
- Flag pre-generation
- Team progress tracking
- Hint system management
"""

import json
import os
import logging
import sqlite3
from datetime import datetime, timedelta
from flask import Flask, request, jsonify, abort
from functools import wraps

# Import existing modules
from challenges import CHALLENGES as PHASE1_CHALLENGES, validate_challenge, get_team_from_ip
from dynamic_flags import DynamicFlagGenerator

app = Flask(__name__)
logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)

# ═══════════════════════════════════════════════════════════════════
# Configuration and Initialization
# ═══════════════════════════════════════════════════════════════════

# Load team configs
TEAM_CONFIGS = {}
config_path = '/opt/ctf/team_configs.json'
if os.path.exists(config_path):
    with open(config_path) as f:
        TEAM_CONFIGS = json.load(f)
    logger.info(f"Loaded configs for {len(TEAM_CONFIGS)} teams")
else:
    logger.warning("No team configs found — using test data")
    TEAM_CONFIGS = {
        'team1': {'fgt_wan_ip': '10.0.1.1'},
        'team2': {'fgt_wan_ip': '10.0.2.1'},
        'team3': {'fgt_wan_ip': '10.0.3.1'},
        'team4': {'fgt_wan_ip': '10.0.4.1'},
        'team5': {'fgt_wan_ip': '10.0.5.1'}
    }

# CTF Session Configuration
CTF_SESSION = {
    'session_id': 3071,  # Unique session identifier
    'start_time': datetime.now(),
    'phase': 'both',  # 'phase1', 'phase2', or 'both'
    'admin_token': 'ctf_admin_2026!'
}

# Initialize dynamic flag generator
dynamic_flags = DynamicFlagGenerator(
    session_id=CTF_SESSION['session_id'],
    start_time=CTF_SESSION['start_time'],
    team_configs=TEAM_CONFIGS
)

# ═══════════════════════════════════════════════════════════════════
# Database Setup
# ═══════════════════════════════════════════════════════════════════

DB_PATH = '/opt/ctf/logs/ctf.db'

def init_database():
    """Initialize SQLite database for tracking solves and submissions."""
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Solves table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS solves (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            team_id TEXT NOT NULL,
            challenge_id TEXT NOT NULL,
            flag_submitted TEXT NOT NULL,
            is_correct BOOLEAN NOT NULL,
            submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            phase TEXT NOT NULL,
            points INTEGER DEFAULT 0,
            UNIQUE(team_id, challenge_id)
        )
    ''')
    
    # Admin actions table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS admin_actions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            action TEXT NOT NULL,
            team_id TEXT,
            challenge_id TEXT,
            details TEXT,
            admin_ip TEXT,
            timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Hints given table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS hints_given (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            team_id TEXT NOT NULL,
            challenge_id TEXT NOT NULL,
            hint_level INTEGER NOT NULL,
            hint_text TEXT,
            given_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    conn.commit()
    conn.close()

# Initialize database on startup
init_database()

# ═══════════════════════════════════════════════════════════════════
# Authentication and Utilities
# ═══════════════════════════════════════════════════════════════════

def admin_required(f):
    """Decorator to require admin authentication."""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        token = request.headers.get('Authorization')
        if not token or token != f"Bearer {CTF_SESSION['admin_token']}":
            abort(401, description="Admin authentication required")
        return f(*args, **kwargs)
    return decorated_function

def log_admin_action(action: str, team_id: str = None, challenge_id: str = None, details: str = None):
    """Log admin actions for audit trail."""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute('''
        INSERT INTO admin_actions (action, team_id, challenge_id, details, admin_ip)
        VALUES (?, ?, ?, ?, ?)
    ''', (action, team_id, challenge_id, details, request.remote_addr))
    
    conn.commit()
    conn.close()

def get_team_progress(team_id: str) -> dict:
    """Get current progress for a team."""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute('''
        SELECT challenge_id, phase, points, submitted_at
        FROM solves 
        WHERE team_id = ? AND is_correct = 1
        ORDER BY submitted_at
    ''', (team_id,))
    
    solves = []
    total_points = 0
    
    for row in cursor.fetchall():
        solve = {
            'challenge_id': row[0],
            'phase': row[1],
            'points': row[2],
            'solved_at': row[3]
        }
        solves.append(solve)
        total_points += row[2]
    
    conn.close()
    
    return {
        'team_id': team_id,
        'total_points': total_points,
        'challenges_solved': len(solves),
        'solves': solves,
        'last_activity': solves[-1]['solved_at'] if solves else None
    }

# ═══════════════════════════════════════════════════════════════════
# Public API Endpoints (Team-Facing)
# ═══════════════════════════════════════════════════════════════════

@app.route('/')
def index():
    """Server status page."""
    return {
        'status': 'online',
        'server': 'CTF Fortinet Flag Server v2',
        'session_id': CTF_SESSION['session_id'],
        'phase': CTF_SESSION['phase'],
        'teams_configured': len(TEAM_CONFIGS),
        'uptime': str(datetime.now() - CTF_SESSION['start_time'])
    }

@app.route('/api/health')
def health():
    """Health check endpoint."""
    return {'status': 'healthy', 'timestamp': datetime.now().isoformat()}

@app.route('/api/challenges')
def list_challenges():
    """List available challenges for current phase."""
    challenges = {}
    
    if CTF_SESSION['phase'] in ['phase1', 'both']:
        # Phase 1 challenges (static flags)
        for challenge_id, challenge_data in PHASE1_CHALLENGES.items():
            challenges[challenge_id] = {
                'name': challenge_data['name'],
                'category': challenge_data['category'],
                'points': challenge_data['points'],
                'difficulty': challenge_data['difficulty'],
                'description': challenge_data['description'],
                'phase': 'phase1'
            }
    
    if CTF_SESSION['phase'] in ['phase2', 'both']:
        # Phase 2 challenges (dynamic flags)
        phase2_challenges = {
            'primera_vista': {'name': 'Primera Vista', 'category': 'Log Analysis', 'points': 100, 'difficulty': 'easy'},
            'filtro_maestro': {'name': 'El Filtro Maestro', 'category': 'Log Analysis', 'points': 150, 'difficulty': 'easy'},
            'reporte_express': {'name': 'Reporte Exprés', 'category': 'Reporting', 'points': 200, 'difficulty': 'medium'},
            'detective_novato': {'name': 'Detective Novato', 'category': 'Threat Detection', 'points': 250, 'difficulty': 'medium'},
            'correlador_eventos': {'name': 'El Correlador de Eventos', 'category': 'Incident Response', 'points': 250, 'difficulty': 'medium'},
            'timeline_master': {'name': 'Maestro del Timeline', 'category': 'Forensics', 'points': 300, 'difficulty': 'hard'},
            'cazador_patrones': {'name': 'Cazador de Patrones', 'category': 'Advanced Analysis', 'points': 350, 'difficulty': 'hard'},
            'analista_comportamiento': {'name': 'Analista de Comportamiento', 'category': 'Behavioral Analysis', 'points': 300, 'difficulty': 'hard'},
            'comandante_incidentes': {'name': 'Comandante de Incidentes', 'category': 'Incident Response', 'points': 300, 'difficulty': 'hard'},
            'cazador_apt': {'name': 'Cazador de APT', 'category': 'Advanced Threats', 'points': 300, 'difficulty': 'expert'}
        }
        
        for challenge_id, challenge_data in phase2_challenges.items():
            challenge_data['phase'] = 'phase2'
            challenges[challenge_id] = challenge_data
    
    return {'challenges': challenges}

@app.route('/api/flag/<challenge_id>', methods=['POST'])
def submit_flag(challenge_id):
    """Submit a flag for validation."""
    data = request.get_json()
    if not data or 'flag' not in data:
        return jsonify({'error': 'Flag submission required'}), 400
    
    submitted_flag = data['flag'].strip()
    team_id = data.get('team_id') or get_team_from_ip(request.remote_addr, TEAM_CONFIGS)
    
    if not team_id:
        return jsonify({'error': 'Team identification failed'}), 400
    
    # Determine which phase this challenge belongs to
    is_phase1 = challenge_id in PHASE1_CHALLENGES
    is_phase2 = challenge_id in ['primera_vista', 'filtro_maestro', 'reporte_express', 'detective_novato',
                                 'correlador_eventos', 'timeline_master', 'cazador_patrones', 
                                 'analista_comportamiento', 'comandante_incidentes', 'cazador_apt']
    
    if not (is_phase1 or is_phase2):
        return jsonify({'error': 'Unknown challenge'}), 404
    
    # Validate flag
    is_correct = False
    points = 0
    phase = ''
    
    if is_phase1:
        # Phase 1: Static flag validation
        phase = 'phase1'
        is_correct = validate_challenge(challenge_id, team_id, TEAM_CONFIGS)
        points = PHASE1_CHALLENGES[challenge_id]['points']
    
    elif is_phase2:
        # Phase 2: Dynamic flag validation
        phase = 'phase2'
        validation_result = dynamic_flags.validate_flag_submission(challenge_id, submitted_flag, team_id)
        is_correct = validation_result['valid']
        
        # Points based on difficulty
        points_map = {
            'primera_vista': 100, 'filtro_maestro': 150, 'reporte_express': 200, 'detective_novato': 250,
            'correlador_eventos': 250, 'timeline_master': 300, 'cazador_patrones': 350,
            'analista_comportamiento': 300, 'comandante_incidentes': 300, 'cazador_apt': 300
        }
        points = points_map.get(challenge_id, 100)
    
    # Record submission
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    try:
        cursor.execute('''
            INSERT OR REPLACE INTO solves 
            (team_id, challenge_id, flag_submitted, is_correct, phase, points)
            VALUES (?, ?, ?, ?, ?, ?)
        ''', (team_id, challenge_id, submitted_flag, is_correct, phase, points))
        
        conn.commit()
    except sqlite3.Error as e:
        logger.error(f"Database error: {e}")
        return jsonify({'error': 'Database error'}), 500
    finally:
        conn.close()
    
    # Response
    response = {
        'correct': is_correct,
        'challenge_id': challenge_id,
        'team_id': team_id,
        'points': points if is_correct else 0
    }
    
    if is_correct:
        response['message'] = '¡Flag correcto! Challenge resuelto.'
        logger.info(f"Team {team_id} solved {challenge_id} ({phase})")
    else:
        response['message'] = 'Flag incorrecto. Intenta de nuevo.'
        if is_phase2:
            response['hint'] = validation_result.get('hint', 'Verifica tu análisis')
    
    return jsonify(response)

# ═══════════════════════════════════════════════════════════════════
# Admin API Endpoints
# ═══════════════════════════════════════════════════════════════════

@app.route('/admin/status')
@admin_required
def admin_status():
    """Get overall CTF status."""
    log_admin_action('status_check')
    
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Get stats
    cursor.execute('SELECT COUNT(*) FROM solves WHERE is_correct = 1')
    total_solves = cursor.fetchone()[0]
    
    cursor.execute('SELECT phase, COUNT(*) FROM solves WHERE is_correct = 1 GROUP BY phase')
    solves_by_phase = dict(cursor.fetchall())
    
    cursor.execute('SELECT team_id, COUNT(*) as count FROM solves WHERE is_correct = 1 GROUP BY team_id ORDER BY count DESC')
    team_standings = [{'team_id': row[0], 'solves': row[1]} for row in cursor.fetchall()]
    
    conn.close()
    
    return {
        'session_id': CTF_SESSION['session_id'],
        'start_time': CTF_SESSION['start_time'].isoformat(),
        'uptime': str(datetime.now() - CTF_SESSION['start_time']),
        'phase': CTF_SESSION['phase'],
        'total_teams': len(TEAM_CONFIGS),
        'total_solves': total_solves,
        'solves_by_phase': solves_by_phase,
        'team_standings': team_standings
    }

@app.route('/admin/teams/<team_id>/progress')
@admin_required
def admin_team_progress(team_id):
    """Get detailed progress for a specific team."""
    log_admin_action('team_progress_check', team_id=team_id)
    
    if team_id not in TEAM_CONFIGS:
        return jsonify({'error': 'Team not found'}), 404
    
    progress = get_team_progress(team_id)
    return jsonify(progress)

@app.route('/admin/flags/<team_id>/all')
@admin_required
def admin_get_all_flags(team_id):
    """Get all flags for a team (for admin reference)."""
    log_admin_action('flags_query', team_id=team_id, details='all_flags')
    
    if team_id not in TEAM_CONFIGS:
        return jsonify({'error': 'Team not found'}), 404
    
    # Phase 1 flags (static)
    phase1_flags = {}
    for challenge_id in PHASE1_CHALLENGES:
        # Get static flag from challenge definition
        phase1_flags[challenge_id] = PHASE1_CHALLENGES[challenge_id].get('default_flag', 'CTF{unknown}')
    
    # Phase 2 flags (dynamic)
    phase2_flags = dynamic_flags.generate_all_flags(team_id)
    
    return {
        'team_id': team_id,
        'session_id': CTF_SESSION['session_id'],
        'generated_at': datetime.now().isoformat(),
        'phase1_flags': phase1_flags,
        'phase2_flags': phase2_flags
    }

@app.route('/admin/flags/<team_id>/<challenge_id>')
@admin_required
def admin_get_specific_flag(team_id, challenge_id):
    """Get specific flag with metadata."""
    log_admin_action('flag_query', team_id=team_id, challenge_id=challenge_id)
    
    if team_id not in TEAM_CONFIGS:
        return jsonify({'error': 'Team not found'}), 404
    
    # Check if it's a Phase 2 challenge
    if challenge_id in ['primera_vista', 'filtro_maestro', 'reporte_express', 'detective_novato',
                        'correlador_eventos', 'timeline_master', 'cazador_patrones', 
                        'analista_comportamiento', 'comandante_incidentes', 'cazador_apt']:
        
        flags = dynamic_flags.generate_all_flags(team_id)
        flag = flags.get(challenge_id)
        metadata = dynamic_flags.get_flag_metadata(challenge_id, team_id)
        
        return {
            'flag': flag,
            'metadata': metadata
        }
    
    # Phase 1 challenge
    elif challenge_id in PHASE1_CHALLENGES:
        return {
            'flag': PHASE1_CHALLENGES[challenge_id].get('default_flag', 'CTF{unknown}'),
            'metadata': {
                'challenge_id': challenge_id,
                'team_id': team_id,
                'flag_type': 'static',
                'phase': 'phase1'
            }
        }
    
    else:
        return jsonify({'error': 'Challenge not found'}), 404

@app.route('/admin/session/info')
@admin_required
def admin_session_info():
    """Get session information."""
    log_admin_action('session_info_query')
    
    return {
        'session_id': CTF_SESSION['session_id'],
        'start_time': CTF_SESSION['start_time'].isoformat(),
        'phase': CTF_SESSION['phase'],
        'teams': list(TEAM_CONFIGS.keys()),
        'total_teams': len(TEAM_CONFIGS)
    }

@app.route('/admin/pre_generate_flags', methods=['POST'])
@admin_required
def admin_pre_generate_flags():
    """Pre-generate all flags for all teams (useful for testing/preparation)."""
    log_admin_action('pre_generate_flags', details='all_teams')
    
    all_flags = {}
    
    for team_id in TEAM_CONFIGS:
        all_flags[team_id] = dynamic_flags.generate_all_flags(team_id)
    
    # Save to file for reference
    output_file = '/opt/ctf/logs/pre_generated_flags.json'
    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    
    with open(output_file, 'w') as f:
        json.dump(all_flags, f, indent=2)
    
    return {
        'status': 'success',
        'teams_processed': len(TEAM_CONFIGS),
        'flags_generated': sum(len(flags) for flags in all_flags.values()),
        'output_file': output_file,
        'session_id': CTF_SESSION['session_id']
    }

@app.route('/admin/submissions/live')
@admin_required
def admin_live_submissions():
    """Get recent flag submissions in real-time."""
    log_admin_action('live_submissions_query')
    
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute('''
        SELECT team_id, challenge_id, flag_submitted, is_correct, submitted_at, phase, points
        FROM solves 
        ORDER BY submitted_at DESC 
        LIMIT 50
    ''')
    
    submissions = []
    for row in cursor.fetchall():
        submissions.append({
            'team_id': row[0],
            'challenge_id': row[1],
            'flag_submitted': row[2],
            'is_correct': bool(row[3]),
            'submitted_at': row[4],
            'phase': row[5],
            'points': row[6]
        })
    
    conn.close()
    
    return {'submissions': submissions}

# ═══════════════════════════════════════════════════════════════════
# Error Handlers
# ═══════════════════════════════════════════════════════════════════

@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Endpoint not found'}), 404

@app.errorhandler(401)
def unauthorized(error):
    return jsonify({'error': 'Authentication required', 'description': str(error.description)}), 401

@app.errorhandler(500)
def internal_error(error):
    logger.error(f"Internal server error: {error}")
    return jsonify({'error': 'Internal server error'}), 500

# ═══════════════════════════════════════════════════════════════════
# Main Application
# ═══════════════════════════════════════════════════════════════════

if __name__ == '__main__':
    logger.info("Starting CTF Flag Server v2")
    logger.info(f"Session ID: {CTF_SESSION['session_id']}")
    logger.info(f"Phase: {CTF_SESSION['phase']}")
    logger.info(f"Teams configured: {len(TEAM_CONFIGS)}")
    
    # Test flag generation
    if TEAM_CONFIGS:
        test_team = list(TEAM_CONFIGS.keys())[0]
        test_flags = dynamic_flags.generate_all_flags(test_team)
        logger.info(f"Dynamic flags test successful: {len(test_flags)} flags generated for {test_team}")
    
    app.run(host='0.0.0.0', port=8080, debug=False)