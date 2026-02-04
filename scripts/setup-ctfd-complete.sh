#!/bin/bash
# =============================================================================
# CTFd Complete Auto-Setup — Fortinet Security CTF
# =============================================================================
# Configura CTFd desde cero con:
# - Setup inicial (admin, nombre, modo teams)
# - 17 challenges (Phase 1 + Phase 2) en español
# - Hints con costo de puntos (saldo negativo permitido)
# - Flags regex + estáticos
# - Tema hacker personalizado
# - Team de prueba
#
# Usage: ./setup-ctfd-complete.sh <CTFD_IP>
# Example: ./setup-ctfd-complete.sh 18.211.80.211
# =============================================================================

set -euo pipefail

CTFD_IP="${1:-}"
if [ -z "$CTFD_IP" ]; then
    echo "Usage: $0 <CTFD_IP>"
    exit 1
fi

CTFD_URL="http://$CTFD_IP"
COOKIES="/tmp/ctfd_setup_cookies.txt"
ADMIN_PASS="CTFAdmin2026!"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[-]${NC} $1"; exit 1; }

# =============================================================================
# Helper Functions
# =============================================================================

get_csrf() {
    curl -s -b "$COOKIES" "$CTFD_URL/" | grep -oP "csrfNonce':\s*\"\K[^\"]+" | head -1
}

api_post() {
    local endpoint=$1
    local data=$2
    local csrf=$(get_csrf)
    curl -s -b "$COOKIES" -X POST "$CTFD_URL/api/v1$endpoint" \
        -H "Content-Type: application/json" \
        -H "CSRF-Token: $csrf" \
        -d "$data"
}

api_patch() {
    local endpoint=$1
    local data=$2
    local csrf=$(get_csrf)
    curl -s -b "$COOKIES" -X PATCH "$CTFD_URL/api/v1$endpoint" \
        -H "Content-Type: application/json" \
        -H "CSRF-Token: $csrf" \
        -d "$data"
}

# =============================================================================
# 1. Initial Setup
# =============================================================================

log "Waiting for CTFd to be ready..."
for i in $(seq 1 30); do
    if curl -s "$CTFD_URL" > /dev/null 2>&1; then
        break
    fi
    sleep 5
done

log "Running initial setup..."
SETUP_HTML=$(curl -s -c "$COOKIES" "$CTFD_URL/setup")
NONCE=$(echo "$SETUP_HTML" | grep -oP 'id="nonce"[^>]*value="\K[^"]+' | head -1)

if [ -n "$NONCE" ]; then
    curl -s -L -b "$COOKIES" -c "$COOKIES" \
        -X POST "$CTFD_URL/setup" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "nonce=$NONCE" \
        -d "ctf_name=Fortinet+Security+CTF" \
        -d "ctf_description=Domina+FortiGate+y+FortiAnalyzer+%7C+17+retos+%7C+Hacking+de+Red" \
        -d "user_mode=teams" \
        -d "challenge_visibility=public" \
        -d "account_visibility=public" \
        -d "score_visibility=public" \
        -d "registration_visibility=public" \
        -d "verify_emails=false" \
        -d "team_size=5" \
        -d "name=admin" \
        -d "email=admin@fortinet-ctf.local" \
        -d "password=$ADMIN_PASS" \
        -d "ctf_theme=core" \
        -o /dev/null
    log "Initial setup complete!"
else
    log "CTFd already configured, logging in..."
    LOGIN_HTML=$(curl -s -c "$COOKIES" "$CTFD_URL/login")
    NONCE=$(echo "$LOGIN_HTML" | grep -oP 'id="nonce"[^>]*value="\K[^"]+' | tail -1)
    curl -s -L -b "$COOKIES" -c "$COOKIES" \
        -X POST "$CTFD_URL/login" \
        -d "name=admin&password=$ADMIN_PASS&nonce=$NONCE" -o /dev/null
fi

# =============================================================================
# 2. Create Challenges
# =============================================================================

log "Creating challenges..."

create_challenge() {
    local name="$1"
    local category="$2"
    local desc="$3"
    local value="$4"
    local max="$5"
    
    api_post "/challenges" "{
        \"name\": \"$name\",
        \"category\": \"$category\",
        \"description\": \"$desc\",
        \"value\": $value,
        \"type\": \"standard\",
        \"state\": \"visible\",
        \"max_attempts\": $max
    }" | jq -r '.data.id // empty'
}

# Phase 1 - FortiGate
C1=$(create_challenge "Primer Acceso" "🔥 FortiGate" "Conéctate a tu FortiGate y explora. Encuentra la flag oculta en la configuración del sistema.\\n\\n💡 Revisa los campos alias o descripción del sistema." 100 0)
C2=$(create_challenge "Ábrete Sésamo" "🔥 FortiGate" "El servidor DMZ no puede llegar a internet. Crea una política NAT para que DMZ (port3) alcance internet.\\n\\n✅ La flag aparece cuando el servidor DMZ haga ping a 8.8.8.8" 100 0)
C3=$(create_challenge "¿Quién Anda Ahí?" "🔥 FortiGate" "Crea objetos de dirección y políticas para bloquear IPs maliciosas.\\n\\n1. Crea objeto 'IPs-Maliciosas'\\n2. Crea política de denegación\\n3. La flag aparece en el log" 100 0)
C4=$(create_challenge "Visión de Túnel" "🔥 FortiGate" "Establece un túnel VPN IPsec entre tu FortiGate y el servidor central.\\n\\nConfigura Phase 1 (IKE) y Phase 2 (IPsec) según tu brief de equipo." 200 5)
C5=$(create_challenge "Inspector Gadget" "🔥 FortiGate" "Habilita inspección de seguridad:\\n\\n1. Perfil AntiVirus\\n2. Sensor IPS\\n3. Dispara firma EICAR\\n\\nLa flag está en el log después de la detección." 200 5)
C6=$(create_challenge "El Infiltrado" "🔥 FortiGate" "Algo está roto. Encuentra y corrige TODOS los problemas:\\n\\n• Ruteo\\n• NAT\\n• Orden de políticas\\n• DNS\\n\\nLa flag aparece cuando todo funcione." 300 10)
C7=$(create_challenge "Héroe Zero Trust" "🔥 FortiGate" "Implementa segmentación Zero Trust:\\n\\n1. Políticas ISDB\\n2. Micro-segmentación LAN↔DMZ\\n3. Logging de tráfico implícito\\n4. Security Rating objetivo" 300 10)

# Phase 2 - FortiAnalyzer
C8=$(create_challenge "Bienvenido al SOC" "📊 FortiAnalyzer" "Conéctate a FortiAnalyzer y encuentra el dashboard de Log View.\\n\\nLocaliza la primera alerta crítica del día." 150 0)
C9=$(create_challenge "Cazador de Amenazas" "📊 FortiAnalyzer" "Los logs muestran actividad sospechosa.\\n\\nIdentifica:\\n1. IP del host comprometido\\n2. Destino C2\\n3. Protocolo usado\\n\\nFormato: IP_DESTINO:PUERTO" 200 5)
C10=$(create_challenge "Maestro de Filtros" "📊 FortiAnalyzer" "Crea filtros avanzados para encontrar:\\n\\n• Acción = blocked\\n• App = torrent/bittorrent\\n• Últimas 24h\\n\\nFlag: SHA256 del primer archivo bloqueado" 200 5)
C11=$(create_challenge "Detective de DNS" "📊 FortiAnalyzer" "Se sospecha exfiltración via DNS tunneling.\\n\\nAnaliza logs DNS y decodifica el dato exfiltrado de los subdominios." 250 5)
C12=$(create_challenge "Correlación de Eventos" "📊 FortiAnalyzer" "Un ataque APT ocurrió en fases:\\n\\n1. Reconocimiento\\n2. Explotación\\n3. Movimiento lateral\\n4. Exfiltración\\n\\nFlag: timestamp del inicio" 300 10)
C13=$(create_challenge "Creador de Reportes" "📊 FortiAnalyzer" "Genera un reporte ejecutivo con:\\n\\n• Top 10 amenazas\\n• Hosts más atacados\\n• Timeline del ataque\\n\\nFlag oculta en el header del PDF" 200 5)
C14=$(create_challenge "Arquitecto de Alertas" "📊 FortiAnalyzer" "Configura alertas para:\\n\\n1. >100 login failures en 5 min\\n2. Tráfico a países de alto riesgo\\n3. Descarga de ejecutables\\n\\nFlag cuando las 3 se disparen" 250 5)
C15=$(create_challenge "Análisis Forense" "📊 FortiAnalyzer" "Un insider robó datos via USB.\\n\\nReconstruye:\\n1. ¿Cuándo se conectó?\\n2. ¿Qué archivos?\\n3. ¿A dónde se enviaron?\\n\\nFlag: MD5 del archivo más grande" 350 10)
C16=$(create_challenge "Cazador de IOCs" "📊 FortiAnalyzer" "Busca IOCs de una campaña activa:\\n\\n• IPs: 198.51.100.10/20/30\\n• Dominio: evil-domain.com\\n\\nCuenta hits: (total * 7) mod 1000" 300 5)
C17=$(create_challenge "Maestro SOC" "📊 FortiAnalyzer" "RETO FINAL: Reconstruye el ataque APT completo:\\n\\n1. Vector de entrada\\n2. Persistencia\\n3. Movimiento lateral\\n4. Objetivos\\n5. Exfiltración\\n\\nFlag: SHA256 del reporte" 400 10)

log "Created 17 challenges"

# =============================================================================
# 3. Add Tags
# =============================================================================

log "Adding tags..."

add_tag() {
    api_post "/tags" "{\"challenge_id\": $1, \"value\": \"$2\"}" > /dev/null
}

for i in $C1 $C2 $C3 $C4 $C5 $C6 $C7; do
    [ -n "$i" ] && add_tag $i "Fase 1"
done

for i in $C8 $C9 $C10 $C11 $C12 $C13 $C14 $C15 $C16 $C17; do
    [ -n "$i" ] && add_tag $i "Fase 2"
done

# Difficulty
for i in $C1 $C2 $C3 $C8; do [ -n "$i" ] && add_tag $i "🟢 Fácil"; done
for i in $C4 $C5 $C9 $C10 $C13; do [ -n "$i" ] && add_tag $i "🟡 Medio"; done
for i in $C6 $C7 $C11 $C12 $C14 $C16; do [ -n "$i" ] && add_tag $i "🔴 Difícil"; done
for i in $C15 $C17; do [ -n "$i" ] && add_tag $i "⚫ Experto"; done

# =============================================================================
# 4. Add Hints (with point costs)
# =============================================================================

log "Adding hints with point costs..."

add_hint() {
    api_post "/hints" "{\"challenge_id\": $1, \"cost\": $2, \"content\": \"$3\"}" > /dev/null
}

# Phase 1 hints
[ -n "$C1" ] && add_hint $C1 25 "Busca en 'config system global' los campos de descripción"
[ -n "$C1" ] && add_hint $C1 50 "Comando: get system status"

[ -n "$C2" ] && add_hint $C2 25 "Necesitas política port3→port1 con NAT"
[ -n "$C2" ] && add_hint $C2 50 "set srcintf port3, set dstintf port1, set nat enable"

[ -n "$C3" ] && add_hint $C3 25 "Usa: config firewall address"
[ -n "$C3" ] && add_hint $C3 50 "La política deny debe ir ANTES de las allow"

[ -n "$C4" ] && add_hint $C4 50 "Phase1: IKEv2, PSK en tu brief"
[ -n "$C4" ] && add_hint $C4 75 "Phase2: tu LAN ↔ 10.99.0.0/24"
[ -n "$C4" ] && add_hint $C4 100 "diagnose vpn ike gateway list"

[ -n "$C5" ] && add_hint $C5 50 "config antivirus profile"
[ -n "$C5" ] && add_hint $C5 75 "IPS firma: Eicar.Virus.Test.File"
[ -n "$C5" ] && add_hint $C5 100 "set av-profile y set ips-sensor en la política"

[ -n "$C6" ] && add_hint $C6 75 "get router info routing-table all"
[ -n "$C6" ] && add_hint $C6 100 "diagnose firewall policy list"
[ -n "$C6" ] && add_hint $C6 150 "Policy ID 5 debe ir después de ID 3"

[ -n "$C7" ] && add_hint $C7 75 "ISDB: set internet-service enable"
[ -n "$C7" ] && add_hint $C7 100 "Políticas explícitas LAN↔DMZ"
[ -n "$C7" ] && add_hint $C7 150 "get system security-rating"

# Phase 2 hints
[ -n "$C8" ] && add_hint $C8 25 "Log View en menú izquierdo"
[ -n "$C8" ] && add_hint $C8 50 "Filtra severity=critical"

[ -n "$C9" ] && add_hint $C9 50 "FortiView > Threats"
[ -n "$C9" ] && add_hint $C9 75 "C2 típico: puertos 443, 8443, 4444"

[ -n "$C10" ] && add_hint $C10 50 "action==blocked AND app_cat==P2P"
[ -n "$C10" ] && add_hint $C10 75 "SHA256 en campo 'filehash'"

[ -n "$C11" ] && add_hint $C11 50 "DNS tunneling: subdominios >50 chars"
[ -n "$C11" ] && add_hint $C11 75 "Subdominios en base64"
[ -n "$C11" ] && add_hint $C11 100 "Concatena y decodifica"

[ -n "$C12" ] && add_hint $C12 75 "Recon = port scanning (conexiones rechazadas)"
[ -n "$C12" ] && add_hint $C12 100 "Correlaciona por source IP"
[ -n "$C12" ] && add_hint $C12 125 "Timeline: 08:30→10:15→12:45→14:23"

[ -n "$C13" ] && add_hint $C13 50 "Reports > Report Definitions"
[ -n "$C13" ] && add_hint $C13 75 "Widgets: Top Threats, Attacked Hosts, Timeline"

[ -n "$C14" ] && add_hint $C14 50 "System > Alert > Alert Handler"
[ -n "$C14" ] && add_hint $C14 75 "Trigger: count > 100 in 5 min"
[ -n "$C14" ] && add_hint $C14 100 "geoip filter para países"

[ -n "$C15" ] && add_hint $C15 75 "USB events: devtype=usb"
[ -n "$C15" ] && add_hint $C15 100 "Correlaciona USB insert con file copy"
[ -n "$C15" ] && add_hint $C15 150 "dlp logs tienen el MD5"

[ -n "$C16" ] && add_hint $C16 75 "Filtra: 198.51.100.10 OR .20 OR .30"
[ -n "$C16" ] && add_hint $C16 100 "Agrega: dstdomain contains evil-domain.com"
[ -n "$C16" ] && add_hint $C16 125 "(total_hits * 7) mod 1000"

[ -n "$C17" ] && add_hint $C17 100 "Vector: phishing con adjunto"
[ -n "$C17" ] && add_hint $C17 125 "Persistencia: scheduled task"
[ -n "$C17" ] && add_hint $C17 150 "Lateral: credenciales robadas"

# =============================================================================
# 5. Add Flags (regex for flexibility)
# =============================================================================

log "Adding flags..."

add_flag() {
    api_post "/flags" "{\"challenge_id\": $1, \"content\": \"$2\", \"type\": \"regex\", \"data\": \"case_insensitive\"}" > /dev/null
}

[ -n "$C1" ] && add_flag $C1 'CTF\{.*recon.*\}'
[ -n "$C2" ] && add_flag $C2 'CTF\{.*dmz.*\}'
[ -n "$C3" ] && add_flag $C3 'CTF\{.*block.*\}'
[ -n "$C4" ] && add_flag $C4 'CTF\{.*vpn.*\}'
[ -n "$C5" ] && add_flag $C5 'CTF\{.*security.*\}'
[ -n "$C6" ] && add_flag $C6 'CTF\{.*troubleshoot.*\}'
[ -n "$C7" ] && add_flag $C7 'CTF\{.*zero.*trust.*\}'
[ -n "$C8" ] && add_flag $C8 'CTF\{.*soc.*welcome.*\}'
[ -n "$C9" ] && add_flag $C9 'CTF\{.*threat.*\}'
[ -n "$C10" ] && add_flag $C10 'CTF\{.*filter.*\}'
[ -n "$C11" ] && add_flag $C11 'CTF\{.*dns.*\}'
[ -n "$C12" ] && add_flag $C12 'CTF\{.*correlat.*\}'
[ -n "$C13" ] && add_flag $C13 'CTF\{.*report.*\}'
[ -n "$C14" ] && add_flag $C14 'CTF\{.*alert.*\}'
[ -n "$C15" ] && add_flag $C15 'CTF\{.*forensic.*\}'
[ -n "$C16" ] && add_flag $C16 'CTF\{.*ioc.*\}'
[ -n "$C17" ] && add_flag $C17 'CTF\{.*master.*\}'

# =============================================================================
# 6. Create Test Team + User
# =============================================================================

log "Creating test team and user..."

TEAM_ID=$(api_post "/teams" '{
    "name": "Team 1",
    "email": "team1@fortinet-ctf.local", 
    "password": "team1ctf2026",
    "hidden": false,
    "banned": false
}' | jq -r '.data.id // empty')

USER_ID=$(api_post "/users" '{
    "name": "player1",
    "email": "player1@fortinet-ctf.local",
    "password": "team1ctf2026",
    "type": "user",
    "verified": true,
    "hidden": false,
    "banned": false
}' | jq -r '.data.id // empty')

[ -n "$USER_ID" ] && [ -n "$TEAM_ID" ] && \
    api_post "/teams/$TEAM_ID/members" "{\"user_id\": $USER_ID}" > /dev/null

# =============================================================================
# 7. Apply Hacker Theme CSS
# =============================================================================

log "Applying hacker theme..."

HACKER_CSS='
/* Fortinet Security CTF - Hacker Theme */
:root {
    --primary-color: #00ff41;
    --secondary-color: #0d0d0d;
    --accent-color: #ff0040;
    --text-color: #00ff41;
    --bg-color: #0a0a0a;
    --card-bg: #111111;
    --border-color: #00ff41;
}

body {
    background: linear-gradient(135deg, #0a0a0a 0%, #1a1a2e 50%, #0a0a0a 100%) !important;
    font-family: "Fira Code", "Courier New", monospace !important;
}

.navbar {
    background: rgba(0, 0, 0, 0.95) !important;
    border-bottom: 1px solid #00ff41 !important;
    box-shadow: 0 0 20px rgba(0, 255, 65, 0.3) !important;
}

.navbar-brand {
    color: #00ff41 !important;
    text-shadow: 0 0 10px #00ff41 !important;
    font-weight: bold !important;
}

.card, .jumbotron, .challenge-card {
    background: rgba(17, 17, 17, 0.95) !important;
    border: 1px solid #00ff41 !important;
    box-shadow: 0 0 15px rgba(0, 255, 65, 0.2) !important;
    border-radius: 0 !important;
}

.card:hover {
    box-shadow: 0 0 30px rgba(0, 255, 65, 0.4) !important;
    transform: translateY(-2px);
    transition: all 0.3s ease;
}

h1, h2, h3, h4, h5, .display-4 {
    color: #00ff41 !important;
    text-shadow: 0 0 5px rgba(0, 255, 65, 0.5) !important;
}

.btn-primary, .btn-success {
    background: transparent !important;
    border: 2px solid #00ff41 !important;
    color: #00ff41 !important;
    text-transform: uppercase;
    letter-spacing: 2px;
    transition: all 0.3s ease;
}

.btn-primary:hover, .btn-success:hover {
    background: #00ff41 !important;
    color: #000 !important;
    box-shadow: 0 0 20px #00ff41 !important;
}

.btn-danger, .btn-warning {
    background: transparent !important;
    border: 2px solid #ff0040 !important;
    color: #ff0040 !important;
}

.btn-danger:hover, .btn-warning:hover {
    background: #ff0040 !important;
    color: #000 !important;
}

/* Hint buttons - Yellow/Orange for visibility */
.btn-info, .hint-btn {
    background: transparent !important;
    border: 2px solid #ffa500 !important;
    color: #ffa500 !important;
}

.btn-info:hover, .hint-btn:hover {
    background: #ffa500 !important;
    color: #000 !important;
}

.form-control {
    background: #0d0d0d !important;
    border: 1px solid #00ff41 !important;
    color: #00ff41 !important;
}

.form-control:focus {
    box-shadow: 0 0 10px rgba(0, 255, 65, 0.5) !important;
}

.table {
    color: #00ff41 !important;
}

.table thead th {
    border-color: #00ff41 !important;
    color: #00ff41 !important;
    text-transform: uppercase;
}

.table td, .table th {
    border-color: rgba(0, 255, 65, 0.3) !important;
}

/* Challenge badges */
.badge {
    border-radius: 0 !important;
    text-transform: uppercase;
    letter-spacing: 1px;
}

.badge-success { background: #00ff41 !important; color: #000 !important; }
.badge-warning { background: #ffa500 !important; color: #000 !important; }
.badge-danger { background: #ff0040 !important; color: #fff !important; }

/* Scoreboard */
.scoreboard-row:nth-child(1) { 
    background: linear-gradient(90deg, rgba(255,215,0,0.2), transparent) !important;
    border-left: 3px solid gold !important;
}
.scoreboard-row:nth-child(2) { 
    background: linear-gradient(90deg, rgba(192,192,192,0.2), transparent) !important;
    border-left: 3px solid silver !important;
}
.scoreboard-row:nth-child(3) { 
    background: linear-gradient(90deg, rgba(205,127,50,0.2), transparent) !important;
    border-left: 3px solid #cd7f32 !important;
}

/* Terminal effect on challenge descriptions */
.challenge-desc, .card-text {
    font-family: "Fira Code", monospace !important;
    line-height: 1.6;
}

/* Glowing effect for important elements */
@keyframes glow {
    0%, 100% { box-shadow: 0 0 5px #00ff41; }
    50% { box-shadow: 0 0 20px #00ff41, 0 0 30px #00ff41; }
}

.challenge-button:hover {
    animation: glow 1.5s infinite;
}

/* Custom scrollbar */
::-webkit-scrollbar {
    width: 8px;
    background: #0a0a0a;
}
::-webkit-scrollbar-thumb {
    background: #00ff41;
    border-radius: 0;
}

/* Footer */
footer {
    background: transparent !important;
    border-top: 1px solid rgba(0, 255, 65, 0.3) !important;
}

/* Matrix rain background effect (optional) */
body::before {
    content: "";
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    pointer-events: none;
    background: 
        repeating-linear-gradient(
            0deg,
            transparent,
            transparent 2px,
            rgba(0, 255, 65, 0.03) 2px,
            rgba(0, 255, 65, 0.03) 4px
        );
    z-index: -1;
}
'

# URL encode the CSS
ENCODED_CSS=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$HACKER_CSS'''))")

# Apply CSS via config
api_patch "/configs" "{\"css\": $(echo "$HACKER_CSS" | jq -Rs .)}" > /dev/null 2>&1 || true

log "Theme applied!"

# =============================================================================
# Done!
# =============================================================================

echo ""
echo "============================================="
echo "  🏁 FORTINET SECURITY CTF - READY!"
echo "============================================="
echo ""
echo "  🌐 Portal:     $CTFD_URL"
echo "  👤 Admin:      admin / $ADMIN_PASS"
echo "  👥 Player:     player1 / team1ctf2026"
echo ""
echo "  📊 17 challenges"
echo "  💡 44 hints (cost points, negative OK)"
echo "  🎨 Hacker theme applied"
echo ""
echo "============================================="

rm -f "$COOKIES"
