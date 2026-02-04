#!/usr/bin/env python3
"""
Phase 2 Challenge Definitions — FortiAnalyzer Log Analysis & Incident Response

These challenges require teams to analyze real attack data in FortiAnalyzer logs
and submit findings based on their analysis. Flags are dynamically generated
based on actual attack patterns and data.
"""

# ═══════════════════════════════════════════════════════════════════
# PHASE 2 CHALLENGES — FortiAnalyzer Analysis
# ═══════════════════════════════════════════════════════════════════

PHASE2_CHALLENGES = {
    
    # ───────────────────────────────────────────────────────────────
    # NIVEL BÁSICO — Fundamentos de Análisis de Logs
    # ───────────────────────────────────────────────────────────────
    
    "primera_vista": {
        "name": "Primera Vista",
        "category": "Log Analysis Básico",
        "points": 100,
        "difficulty": "easy",
        "level": "básico",
        "description": (
            "¡Bienvenidos a FortiAnalyzer! Su primera misión es familiarizarse con el dashboard. "
            "Durante las últimas 24 horas, el sistema ha estado registrando eventos de seguridad. "
            "\n\n"
            "**Pregunta:** ¿Cuántos logs de seguridad se generaron en total en las últimas 24 horas?\n"
            "\n"
            "**Instrucciones:**\n"
            "1. Accede al dashboard principal de FortiAnalyzer\n"
            "2. Filtra por eventos de tipo 'Security'\n" 
            "3. Ajusta el rango temporal a 'Last 24 hours'\n"
            "4. Observa el contador total de eventos\n"
            "\n"
            "**Formato de flag:** Solo el número (ej: 45721)"
        ),
        "hint_level_1": "Busca en el dashboard principal de FortiAnalyzer",
        "hint_level_2": "Necesitas filtrar por tipo de log 'Security'",
        "hint_level_3": "El número aparece en la esquina superior del log view",
        "learning_objectives": [
            "Navegación básica en FortiAnalyzer",
            "Uso de filtros temporales",
            "Interpretación de dashboards de seguridad"
        ]
    },
    
    "filtro_maestro": {
        "name": "El Filtro Maestro", 
        "category": "Log Analysis Básico",
        "points": 150,
        "difficulty": "easy",
        "level": "básico",
        "description": (
            "Los atacantes han estado realizando escaneos de puertos contra nuestra infraestructura. "
            "Es hora de identificar al principal responsable.\n"
            "\n"
            "**Pregunta:** ¿Cuál es la dirección IP que realizó la mayor cantidad de intentos de port scan?\n"
            "\n"
            "**Instrucciones:**\n"
            "1. Ve a Log View → Advanced Search\n"
            "2. Filtra por eventos de tipo 'Port Scan' o attack='Port Scan'\n"
            "3. Agrupa los resultados por 'Source IP'\n"
            "4. Ordena por cantidad de eventos (descendente)\n"
            "5. La IP con más eventos es tu respuesta\n"
            "\n"
            "**Formato de flag:** Dirección IP completa (ej: 198.51.100.15)"
        ),
        "hint_level_1": "Usa Advanced Search en Log View",
        "hint_level_2": "Filtra por eventos de 'Port Scan'", 
        "hint_level_3": "Agrupa por IP origen y ordena por frecuencia",
        "learning_objectives": [
            "Uso de filtros avanzados",
            "Agrupación y ordenamiento de datos",
            "Identificación de atacantes principales"
        ]
    },
    
    "reporte_express": {
        "name": "Reporte Exprés",
        "category": "Reporting",
        "points": 200, 
        "difficulty": "medium",
        "level": "básico",
        "description": (
            "El equipo de seguridad necesita un reporte rápido de los principales atacantes. "
            "FortiAnalyzer tiene reportes predefinidos que facilitan esta tarea.\n"
            "\n"
            "**Pregunta:** Genera el reporte 'Top Attackers' para las últimas 24 horas. "
            "¿Cuál es la tercera IP en la lista?\n"
            "\n"
            "**Instrucciones:**\n"
            "1. Ve a Reports → Report Console\n"
            "2. Busca en Pre-defined Reports → Security\n"
            "3. Selecciona 'Top Attackers' o 'Top Sources'\n" 
            "4. Configura Time Range: 'Last 24 hours'\n"
            "5. Ejecuta el reporte\n"
            "6. En la tabla de resultados, encuentra la tercera fila\n"
            "\n"
            "**Formato de flag:** Dirección IP de la tercera posición (ej: 203.45.67.89)"
        ),
        "hint_level_1": "Ve a la sección Reports, no Log View",
        "hint_level_2": "Busca reportes pre-definidos de seguridad",
        "hint_level_3": "Necesitas la tercera fila de la tabla de resultados",
        "learning_objectives": [
            "Generación de reportes predefinidos",
            "Interpretación de tablas de datos",
            "Uso de herramientas de reporting"
        ]
    },
    
    "detective_novato": {
        "name": "Detective Novato",
        "category": "Threat Detection",
        "points": 250,
        "difficulty": "medium", 
        "level": "básico",
        "description": (
            "Los atacantes realizaron reconocimiento de nuestra red mediante escaneos de puertos. "
            "Un buen analista puede identificar patrones en estos ataques.\n"
            "\n"
            "**Pregunta:** Durante los ataques de reconocimiento, ¿qué puerto fue el más escaneado?\n"
            "\n"
            "**Instrucciones:**\n"
            "1. En Log View, filtra eventos relacionados con port scanning\n"
            "2. Usa query: action='scan' OR attack='Port Scan'\n"
            "3. Agrupa los resultados por 'Destination Port'\n"
            "4. Ordena por cantidad de eventos (descendente)\n"
            "5. El puerto con más eventos de escaneo es tu respuesta\n"
            "\n"
            "**Formato de flag:** Solo el número de puerto (ej: 443)"
        ),
        "hint_level_1": "Filtra por eventos de port scanning",
        "hint_level_2": "Agrupa por puerto destino, no por IP", 
        "hint_level_3": "Busca el puerto más frecuentemente escaneado",
        "learning_objectives": [
            "Análisis de patrones de ataque",
            "Comprensión de técnicas de reconocimiento",
            "Identificación de servicios objetivo"
        ]
    },
    
    # ───────────────────────────────────────────────────────────────
    # NIVEL INTERMEDIO — Correlación y Análisis Avanzado 
    # ───────────────────────────────────────────────────────────────
    
    "correlador_eventos": {
        "name": "El Correlador de Eventos", 
        "category": "Incident Response",
        "points": 250,
        "difficulty": "medium",
        "level": "intermedio",
        "description": (
            "Un atacante sofisticado ha ejecutado una campaña APT (Amenaza Persistente Avanzada) "
            "contra nuestra infraestructura. Los eventos están dispersos en el tiempo, "
            "pero todos forman parte de la misma operación.\n"
            "\n"
            "**Pregunta:** ¿Cuál es el Campaign ID que correlaciona todos los eventos de este ataque APT?\n"
            "\n"
            "**Instrucciones:**\n"
            "1. Busca una secuencia de eventos del mismo atacante\n"
            "2. Identifica fases: Reconnaissance → Initial Access → Persistence → Exfiltration\n"
            "3. Correlaciona eventos por Source IP y patrones temporales\n"
            "4. Busca en metadatos, comments o custom fields el Campaign ID\n"
            "5. El formato será algo como: [números]-[team]-APT\n"
            "\n"
            "**Formato de flag:** Campaign ID completo (ej: 3071-team1-APT)"
        ),
        "hint_level_1": "Busca una secuencia de eventos del mismo atacante",
        "hint_level_2": "El Campaign ID está en metadatos o comments de logs",
        "hint_level_3": "Formato: [números]-team[X]-APT",
        "learning_objectives": [
            "Correlación de eventos multi-etapa",
            "Identificación de campañas APT",
            "Análisis temporal de ataques"
        ]
    },
    
    "timeline_master": {
        "name": "Maestro del Timeline",
        "category": "Forensics", 
        "points": 300,
        "difficulty": "hard",
        "level": "intermedio",
        "description": (
            "Después de identificar la campaña APT, es crucial reconstruir la línea temporal "
            "del ataque para entender cómo progresó la amenaza.\n"
            "\n"
            "**Pregunta:** ¿A qué hora exacta (formato HH:MM) comenzó la exfiltración de datos de la campaña APT?\n"
            "\n"
            "**Instrucciones:**\n"
            "1. Usa el Campaign ID del challenge anterior como filtro\n"
            "2. Crea una vista timeline de todos los eventos relacionados\n"
            "3. Busca eventos de 'data exfiltration', 'file upload', o transferencias grandes\n"
            "4. Identifica el PRIMER evento de exfiltración en la secuencia\n"
            "5. Extrae el timestamp exacto (hora y minutos)\n"
            "\n"
            "**Formato de flag:** HH:MM en formato 24 horas (ej: 14:23)"
        ),
        "hint_level_1": "Usa el Campaign ID del reto anterior como filtro",
        "hint_level_2": "Busca eventos de transferencia de archivos grandes",
        "hint_level_3": "Necesitas el timestamp del PRIMER evento de exfiltración",
        "learning_objectives": [
            "Reconstrucción de timelines de incidentes",
            "Análisis forense temporal",
            "Identificación de fases de ataques"
        ]
    },
    
    "cazador_patrones": {
        "name": "Cazador de Patrones",
        "category": "Advanced Analysis",
        "points": 350,
        "difficulty": "hard", 
        "level": "intermedio",
        "description": (
            "Los atacantes están utilizando técnicas avanzadas de exfiltración de datos. "
            "Han implementado DNS tunneling para sacar información de forma sigilosa.\n"
            "\n"
            "**Pregunta:** En la técnica de DNS tunneling detectada, "
            "¿cuántos subdominios únicos utilizó el atacante para exfiltrar datos?\n"
            "\n"
            "**Instrucciones:**\n"
            "1. Examina los logs DNS (no security events)\n"
            "2. Busca queries DNS con patrones sospechosos\n"
            "3. Identifica dominios con subdominios que parecen datos encoded\n"
            "4. Busca el patrón: [data].exfil.[domain].com\n"
            "5. Cuenta los subdominios ÚNICOS utilizados para exfiltración\n"
            "\n"
            "**Formato de flag:** Número de subdominios únicos (ej: 17)"
        ),
        "hint_level_1": "Busca en logs DNS, no en security events",
        "hint_level_2": "Patrón sospechoso: subdominios con datos encoded",
        "hint_level_3": "Cuenta subdominios únicos, no queries totales",
        "learning_objectives": [
            "Detección de DNS tunneling",
            "Análisis de patrones de exfiltración",
            "Investigación de técnicas steganográficas"
        ]
    },
    
    # ───────────────────────────────────────────────────────────────
    # NIVEL AVANZADO — Caza de Amenazas Experto
    # ───────────────────────────────────────────────────────────────
    
    "analista_comportamiento": {
        "name": "Analista de Comportamiento",
        "category": "Behavioral Analysis", 
        "points": 300,
        "difficulty": "hard",
        "level": "avanzado",
        "description": (
            "Las técnicas modernas de ataque incluyen el compromiso de cuentas de usuario. "
            "Un analista experto puede detectar comportamientos anómalos que indican compromiso.\n"
            "\n"
            "**Pregunta:** ¿Cuál es el nombre de usuario que mostró el comportamiento más anómalo "
            "(mayor desviación de sus patrones normales de actividad)?\n"
            "\n"
            "**Instrucciones:**\n"
            "1. Ve a User & Device → User Activity Analysis\n"
            "2. Analiza patrones de horario: horario laboral vs fuera de horario\n"
            "3. Busca usuarios con acceso en horarios inusuales (noches/fines de semana)\n"
            "4. Cruza datos con security events del mismo usuario\n"
            "5. Identifica el usuario con más anomalías comportamentales\n"
            "\n"
            "**Formato de flag:** Username exacto (ej: jsmith)"
        ),
        "hint_level_1": "Analiza patrones de horario de usuarios",
        "hint_level_2": "Busca acceso fuera de horario laboral",
        "hint_level_3": "Cruza datos de User Activity con Security Events",
        "learning_objectives": [
            "Análisis de comportamiento de usuarios",
            "Detección de cuentas comprometidas",
            "Correlación de actividad y eventos de seguridad"
        ]
    },
    
    "comandante_incidentes": {
        "name": "Comandante de Incidentes",
        "category": "Incident Response",
        "points": 300,
        "difficulty": "hard",
        "level": "avanzado",
        "description": (
            "Como comandante del equipo de respuesta a incidentes, debes compilar todos los "
            "indicadores de compromiso (IOCs) para documentar completamente el incidente.\n"
            "\n"
            "**Pregunta:** ¿Cuántos IOCs (Indicators of Compromise) únicos identificaste en total "
            "durante todo el análisis de la campaña APT?\n"
            "\n"
            "**Instrucciones:**\n"
            "1. Compila todos los IOCs encontrados en challenges anteriores\n"
            "2. Categorías: IPs maliciosas, dominios, file hashes, registry keys, usernames comprometidos\n"
            "3. Cuenta SOLO indicadores únicos (no duplicados)\n"
            "4. Incluye todos los elementos que confirman compromiso\n" 
            "5. El total debe abarcar todo el alcance del incidente\n"
            "\n"
            "**Formato de flag:** Número total de IOCs únicos (ej: 11)"
        ),
        "hint_level_1": "Incluye IOCs de todos los challenges anteriores",
        "hint_level_2": "Categorías: IPs, dominios, archivos, registry, usuarios",
        "hint_level_3": "Cuenta elementos únicos, no duplicados",
        "learning_objectives": [
            "Gestión integral de incidentes",
            "Compilación de IOCs",
            "Documentación de evidencias"
        ]
    },
    
    "cazador_apt": {
        "name": "Cazador de APT",
        "category": "Advanced Threats",
        "points": 300,
        "difficulty": "expert",
        "level": "avanzado", 
        "description": (
            "Los grupos APT utilizan técnicas sofisticadas de persistencia para mantener "
            "acceso prolongado a los sistemas. El análisis final requiere identificar "
            "exactamente cómo el atacante mantuvo persistencia.\n"
            "\n"
            "**Pregunta:** ¿Cuál es el nombre exacto del archivo que el APT utilizó "
            "como mecanismo de persistencia en el sistema?\n"
            "\n"
            "**Instrucciones:**\n"
            "1. Examina logs de sistema para modificaciones de persistencia\n"
            "2. Busca: registry modifications, scheduled tasks, service installs\n"
            "3. Identifica archivos con nombres similares a procesos legítimos\n"
            "4. El atacante dejó un archivo falso en System32\n"
            "5. Encuentra el filename exacto del mecanismo de persistencia\n"
            "\n"
            "**Formato de flag:** Filename completo con extensión (ej: svchost32.exe)"
        ),
        "hint_level_1": "Busca modificaciones al registro de Windows",
        "hint_level_2": "El APT dejó un archivo falso en System32", 
        "hint_level_3": "Filename muy similar a un proceso legítimo",
        "learning_objectives": [
            "Identificación de mecanismos de persistencia",
            "Análisis de técnicas APT avanzadas",
            "Detección de archivos maliciosos camuflados"
        ]
    }
}

# ═══════════════════════════════════════════════════════════════════
# Metadata and Utilities
# ═══════════════════════════════════════════════════════════════════

DIFFICULTY_POINTS = {
    "easy": 100,
    "medium": 200,
    "hard": 300,
    "expert": 400
}

LEVEL_ORDER = ["básico", "intermedio", "avanzado"]

def get_challenges_by_level(level: str):
    """Get all challenges for a specific level."""
    return {
        challenge_id: challenge_data
        for challenge_id, challenge_data in PHASE2_CHALLENGES.items()
        if challenge_data["level"] == level
    }

def get_challenge_hints(challenge_id: str, level: int = 1):
    """Get hint for a specific challenge and level."""
    challenge = PHASE2_CHALLENGES.get(challenge_id)
    if not challenge:
        return None
    
    hint_key = f"hint_level_{level}"
    return challenge.get(hint_key)

def get_total_points():
    """Calculate total points available in Phase 2."""
    return sum(challenge["points"] for challenge in PHASE2_CHALLENGES.values())

# Statistics
TOTAL_CHALLENGES = len(PHASE2_CHALLENGES)
TOTAL_POINTS = get_total_points()
CHALLENGES_BY_LEVEL = {
    level: len(get_challenges_by_level(level))
    for level in LEVEL_ORDER
}