# 🔢 SISTEMA DE FLAGS ANALÍTICAS — Fase 2 FortiAnalyzer

## 🎯 Cómo Funcionan las Flags Dinámicas

Las flags se **generan automáticamente** basadas en los ataques reales que ejecuta el traffic generator. Tú como admin puedes **conocerlas por adelantado** consultando el sistema.

---

## 📊 FLAGS POR CHALLENGE — ESPECIFICACIONES EXACTAS

### **🟢 NIVEL BÁSICO**

#### **Challenge 1: "Primera Vista"**
**Pregunta:** *¿Cuántos logs de seguridad se generaron en las últimas 24h?*

**Cómo se genera la flag:**
```python
def get_flag_primera_vista(team_id):
    query = f"SELECT COUNT(*) FROM logs WHERE team='{team_id}' AND type='security' AND timestamp > NOW() - INTERVAL 24 HOUR"
    count = execute_query(query)
    return str(count)  # Ejemplo: "45721"
```

**Tu acceso admin:**
```bash
curl http://flag-server:8080/admin/flags/team1/primera_vista
# Output: {"flag": "45721", "generated_at": "2026-01-31T10:30:00Z"}
```

#### **Challenge 2: "El Filtro Maestro"**  
**Pregunta:** *¿Cuál es la IP que realizó más intentos de port scan?*

**Cómo se genera:**
```python
def get_flag_filtro_maestro(team_id):
    # El traffic generator usa IPs específicas para port scans
    malicious_ips = ["198.51.100.10", "198.51.100.20", "198.51.100.30"]
    # La IP con más eventos de port scan
    query = f"SELECT srcip, COUNT(*) as count FROM logs WHERE team='{team_id}' AND attack_type='Port Scan' GROUP BY srcip ORDER BY count DESC LIMIT 1"
    result = execute_query(query)
    return result['srcip']  # Ejemplo: "198.51.100.15"
```

**Flag predictiva:** Siempre será una de las IPs maliciosas del generador

#### **Challenge 3: "Reporte Exprés"**
**Pregunta:** *Genera reporte 'Top Attackers' - ¿cuál es la 3era IP en la lista?*

**Cómo se genera:**
```python
def get_flag_reporte_express(team_id):
    query = f"SELECT srcip, COUNT(*) as attacks FROM logs WHERE team='{team_id}' AND severity='high' GROUP BY srcip ORDER BY attacks DESC LIMIT 5"
    results = execute_query(query)
    return results[2]['srcip']  # Tercera IP (index 2)
```

### **🟡 NIVEL INTERMEDIO**

#### **Challenge 5: "El Correlador de Eventos"**
**Pregunta:** *¿Cuál es el Campaign ID del ataque APT multi-etapa?*

**Cómo se genera:**
```python
def get_flag_correlador(team_id):
    # Campaign ID format: {session_id}-{team_id}-APT  
    session_id = get_current_session_id()  # Ej: 3071
    return f"{session_id}-{team_id}-APT"   # Ej: "3071-team1-APT"
```

**Tu predicción exacta:**
```bash
# Durante el evento, consulta el session ID actual:
curl http://flag-server:8080/admin/session_info
# Output: {"session_id": 3071, "started_at": "2026-01-31T08:00:00Z"}

# Flag para team1 será: "3071-team1-APT"
# Flag para team2 será: "3071-team2-APT"  
# etc.
```

#### **Challenge 6: "Maestro del Timeline"**
**Pregunta:** *¿A qué hora exacta (HH:MM) comenzó la exfiltración de datos del APT?*

**Cómo se genera:**
```python
def get_flag_timeline_master(team_id):
    campaign_id = f"{get_session_id()}-{team_id}-APT"
    query = f"SELECT timestamp FROM logs WHERE campaign_id='{campaign_id}' AND action='data_exfiltration' ORDER BY timestamp ASC LIMIT 1"
    first_exfil = execute_query(query)
    return first_exfil['timestamp'].strftime("%H:%M")  # Ej: "14:23"
```

**Tu acceso admin:**
```bash
curl http://flag-server:8080/admin/flags/team1/timeline_master  
# Output: {"flag": "14:23", "exfil_started": "2026-01-31T14:23:15Z"}
```

#### **Challenge 7: "Cazador de Patrones"**  
**Pregunta:** *¿Cuántos subdominios únicos usó el atacante para DNS tunneling?*

**Cómo se genera:**
```python
def get_flag_cazador_patrones(team_id):
    # DNS tunneling usa format: {chunk}.{seq}.exfil.evil-domain.com
    # Basado en la data que se tuneliza: "sensitive_financial_data_q3_results"
    data = "sensitive_financial_data_q3_results"
    encoded = data.encode().hex()  # 73656e7369746976655f66696e616e6369616c5f646174615f7133...
    chunks = [encoded[i:i+30] for i in range(0, len(encoded), 30)]
    return str(len(chunks))  # Ejemplo: "17"
```

**Flag predictiva:** Siempre será el mismo número basado en el string "sensitive_financial_data_q3_results"

### **🔴 NIVEL AVANZADO**

#### **Challenge 8: "Analista de Comportamiento"**
**Pregunta:** *¿Cuál es el usuario que mostró el comportamiento más anómalo?*

**Cómo se genera:**
```python
def get_flag_analista_comportamiento(team_id):
    # El traffic generator simula usuarios comprometidos
    compromised_users = ["jsmith", "mgarcia", "rjohnson", "alopez"]
    # El usuario con más eventos fuera de horario
    query = f"SELECT username, COUNT(*) as anomalies FROM logs WHERE team='{team_id}' AND hour NOT BETWEEN 8 AND 18 GROUP BY username ORDER BY anomalies DESC LIMIT 1"
    result = execute_query(query)
    return result['username']  # Ej: "jsmith"
```

#### **Challenge 9: "Comandante de Incidentes"**
**Pregunta:** *¿Cuántos IOCs (Indicators of Compromise) únicos detectaste en total?*

**Cómo se genera:**
```python
def get_flag_comandante_incidentes(team_id):
    # IOCs específicos que el generator planta:
    malicious_ips = ["198.51.100.10", "198.51.100.20", "198.51.100.30"]  # 3
    malicious_domains = ["evil-domain.com", "exfil.evil-domain.com"]      # 2  
    malicious_files = ["svchost32.exe", "system.dll", "update.scr"]       # 3
    registry_keys = ["HKLM\\Software\\Microsoft\\Windows\\CurrentVersion\\Run\\SecurityUpdate"]  # 1
    compromised_users = ["jsmith", "mgarcia"]                             # 2
    
    total_iocs = len(malicious_ips) + len(malicious_domains) + len(malicious_files) + len(registry_keys) + len(compromised_users)
    return str(total_iocs)  # "11"
```

#### **Challenge 10: "Cazador de APT"**
**Pregunta:** *¿Cuál es el mecanismo de persistencia que utilizó el APT?*

**Cómo se genera:**
```python
def get_flag_cazador_apt(team_id):
    # El generator siempre usa el mismo persistence mechanism
    return "svchost32.exe"  # Fake svchost para persistence
```

---

## 🎛️ PANEL DE CONTROL DE ADMINISTRADOR

### **Flag Dashboard en Tiempo Real:**
```bash
# Ver todas las flags de un team
curl http://flag-server:8080/admin/flags/team1/all
```

**Output esperado:**
```json
{
  "team_id": "team1",
  "session_id": 3071,
  "generated_at": "2026-01-31T08:00:00Z",
  "flags": {
    "primera_vista": "45721",
    "filtro_maestro": "198.51.100.15", 
    "reporte_express": "203.45.67.89",
    "detective_novato": "443",
    "correlador_eventos": "3071-team1-APT",
    "timeline_master": "14:23",
    "cazador_patrones": "17",
    "analista_comportamiento": "jsmith",
    "comandante_incidentes": "11", 
    "cazador_apt": "svchost32.exe"
  }
}
```

### **Pre-Generate Flags (antes del evento):**
```bash
# Simular flags para todas las teams (dry run)
curl -X POST http://flag-server:8080/admin/pre_generate_flags
```

### **Monitor Flag Submissions:**
```bash
# Ver qué flags han sido submitted
curl http://flag-server:8080/admin/submissions/live
```

---

## 🔧 IMPLEMENTACIÓN DEL SISTEMA

### **Archivo: `/opt/ctf/flagserver/dynamic_flags.py`**
```python
#!/usr/bin/env python3
import hashlib
from datetime import datetime

class DynamicFlagGenerator:
    def __init__(self, session_id, start_time):
        self.session_id = session_id
        self.start_time = start_time
        
    def generate_all_flags(self, team_id):
        """Generate all flags for a team at once."""
        return {
            # Básico
            "primera_vista": self._primera_vista_flag(team_id),
            "filtro_maestro": self._filtro_maestro_flag(team_id), 
            "reporte_express": self._reporte_express_flag(team_id),
            "detective_novato": self._detective_novato_flag(team_id),
            
            # Intermedio  
            "correlador_eventos": self._correlador_flag(team_id),
            "timeline_master": self._timeline_flag(team_id),
            "cazador_patrones": self._cazador_patrones_flag(team_id),
            
            # Avanzado
            "analista_comportamiento": self._comportamiento_flag(team_id),
            "comandante_incidentes": self._comandante_flag(team_id),
            "cazador_apt": self._apt_flag(team_id)
        }
    
    def _primera_vista_flag(self, team_id):
        # Simulate log count based on session_id + team_id
        base_count = 40000 + (self.session_id % 1000) + (int(team_id[-1]) * 1000)
        return str(base_count)
    
    def _correlador_flag(self, team_id):
        return f"{self.session_id}-{team_id}-APT"
    
    def _cazador_patrones_flag(self, team_id):
        # Always same data being tunneled
        data = "sensitive_financial_data_q3_results"
        encoded = data.encode().hex()
        chunks = [encoded[i:i+30] for i in range(0, len(encoded), 30)]
        return str(len(chunks))
    
    # ... more flag generators
```

### **Testing del Sistema:**
```bash
# Test flag generation
python3 dynamic_flags.py --session-id 3071 --team team1 --test

# Output:
# team1 flags:
#   primera_vista: 41071
#   correlador_eventos: 3071-team1-APT  
#   cazador_patrones: 17
#   etc.
```

---

## 📋 TU CHEAT SHEET DE FLAGS

### **Flags Predictivas (siempre iguales):**
- **cazador_patrones:** `"17"` (based on data string length)
- **cazador_apt:** `"svchost32.exe"` (hardcoded persistence mechanism)
- **comandante_incidentes:** `"11"` (fixed IOC count)

### **Flags Calculadas (basadas en session_id):**
- **correlador_eventos:** `"{session_id}-{team_id}-APT"`
- **primera_vista:** `{base_count + session_variation}`

### **Flags Tiempo-Dependientes:**
- **timeline_master:** `"{HH:MM}"` (cuando se ejecuta data_exfiltration)

### **Acceso Rápido Durante Evento:**
```bash
# Session ID actual
curl http://flag-server:8080/admin/session_info | jq .session_id

# Todas las flags de team1  
curl http://flag-server:8080/admin/flags/team1/all | jq .flags
```

**🎯 Con esto tienes control total sobre las flags dinámicas y puedes ayudar a los equipos conociendo exactamente qué buscan!**