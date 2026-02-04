# 📖 ADMIN GUIDE — CTF Fortinet Fase 2 (FortiAnalyzer)

## 🎯 Guía Completa para Administrador & Preventa

Esta guía te permite **ayudar a los equipos sin spoilear** y conocer todas las flags exactas por adelantado.

---

## 📊 Dashboard de Monitoreo en Vivo

### Comandos para Verificar Estado de Equipos:
```bash
# Ver logs de traffic generator por equipo
tail -f /opt/ctf/logs/team{1-5}_attacks.log

# Verificar flags generadas para cada equipo
curl http://flag-server:8080/admin/flags/{team_id}

# Monitor progress de equipos
curl http://flag-server:8080/admin/progress
```

---

## 🟢 NIVEL BÁSICO — Soluciones y Hints

### Reto 1: "Primera Vista" (100 pts)
**Pregunta:** "¿Cuántos logs de seguridad se generaron en las últimas 24h?"  

**Solución Completa:**
1. Dashboard FortiAnalyzer → Log View
2. Filter: Type = "Security", Time = "Last 24 hours"  
3. Look at "Total Events" counter en la parte superior
4. **Flag exacta:** `{número_total_logs}` (ej: `45721`)

**Hints Progresivos:**
- **Hint 1:** "Busca en el dashboard principal de FortiAnalyzer"
- **Hint 2:** "Necesitas filtrar por tipo de log 'Security'"  
- **Hint 3:** "El número aparece en la esquina superior del log view"

**Comandos Admin para Verificar:**
```bash
# Ver la flag real para team 1
curl http://flag-server:8080/admin/team1/primera_vista
# Output: {"flag": "45721", "generated_at": "2026-01-31T10:30:00Z"}
```

### Reto 2: "El Filtro Maestro" (150 pts)  
**Pregunta:** "¿Cuál es la IP que realizó más intentos de port scan?"

**Solución Completa:**
1. FortiAnalyzer → Log View → Advanced Search
2. Filter query: `attack="Port Scan"` 
3. Group by: `Source IP`
4. Order by: `Count DESC`
5. La primera IP de la lista = flag
6. **Flag exacta:** `{top_scanning_ip}` (ej: `198.51.100.15`)

**Hints Progresivos:**
- **Hint 1:** "Usa Advanced Search en Log View"
- **Hint 2:** "Filtra por eventos de 'Port Scan'"
- **Hint 3:** "Agrupa por IP origen y ordena por frecuencia"

### Reto 3: "Reporte Exprés" (200 pts)
**Pregunta:** "Genera reporte 'Top Attackers' - ¿cuál es la 3era IP en la lista?"

**Solución Completa:**  
1. FortiAnalyzer → Reports → Report Console
2. Pre-defined Reports → Security → "Top Attackers"
3. Time Range: "Last 24 hours"
4. Run Report
5. En la tabla, fila #3, columna "Source IP"
6. **Flag exacta:** `{third_attacker_ip}` (ej: `203.45.67.89`)

**Hints Progresivos:**
- **Hint 1:** "Ve a la sección Reports, no Log View"
- **Hint 2:** "Busca reportes pre-definidos de seguridad"
- **Hint 3:** "Necesitas la tercera fila de la tabla de resultados"

### Reto 4: "Detective Novato" (250 pts)
**Pregunta:** "¿Qué puerto fue el más escaneado en los ataques de reconocimiento?"

**Solución Completa:**
1. Log View → Advanced Search
2. Query: `action="scan" OR attack="Port Scan"`
3. Group by: `Destination Port`  
4. Order by: `Count DESC`
5. Puerto con mayor número de eventos
6. **Flag exacta:** `{most_scanned_port}` (ej: `443`)

---

## 🟡 NIVEL INTERMEDIO — Soluciones Analíticas Avanzadas

### Reto 5: "El Correlador de Eventos" (250 pts)
**Pregunta:** "¿Cuál es el Campaign ID del ataque APT multi-etapa?"

**Contexto Técnico:** El traffic generator ejecuta APT campaigns con IDs únicos del formato: `{session_id}-{team_id}-APT`

**Solución Completa:**
1. Log View → Search por múltiples eventos relacionados
2. Query timeline: Buscar secuencia Recon → Access → Persistence
3. Correlacionar events por Source IP y User-Agent patterns
4. Encontrar comment/metadata field con Campaign ID
5. **Flag exacta:** `{session_id}-{team_id}-APT` (ej: `3071-team1-APT`)

**Hints Progresivos:**
- **Hint 1:** "Busca una secuencia de eventos del mismo atacante"
- **Hint 2:** "El Campaign ID está en metadatos o comments de logs"
- **Hint 3:** "Formato: [números]-team[X]-APT"

**Query SQL para Admins:**
```sql
SELECT DISTINCT(campaign_id) FROM logs 
WHERE srcip IN (
    SELECT srcip FROM logs WHERE attack_stage = 'reconnaissance'
    INTERSECT  
    SELECT srcip FROM logs WHERE attack_stage = 'persistence'
) AND team_id = 'team1';
```

### Reto 6: "Maestro del Timeline" (300 pts)
**Pregunta:** "¿A qué hora exacta (HH:MM) comenzó la exfiltración de datos del APT?"

**Solución Completa:**
1. Identificar la campaña APT (del reto anterior)
2. Log View → Timeline view por Campaign ID o atacante IP
3. Buscar eventos de "data exfiltration" o transferencias grandes  
4. Primer evento de upload/POST con payload > 50KB
5. **Flag exacta:** `{timestamp_HH:MM}` (ej: `14:23`)

**Hints Progresivos:**
- **Hint 1:** "Usa el Campaign ID del reto anterior como filtro"
- **Hint 2:** "Busca eventos de transferencia de archivos grandes"
- **Hint 3:** "Necesitas el timestamp del PRIMER evento de exfiltración"

### Reto 7: "Cazador de Patrones" (350 pts)  
**Pregunta:** "¿Cuántos subdominios únicos usó el atacante para DNS tunneling?"

**Contexto Técnico:** El generador crea queries DNS con data encoded: `{chunk}.{seq}.exfil.evil-domain.com`

**Solución Completa:**
1. Log View → Filter por DNS queries
2. Search pattern: `*.exfil.evil-domain.com`
3. Extract subdomain patterns (parte antes de .exfil)
4. Count unique subdomain combinations
5. **Flag exacta:** `{unique_subdomain_count}` (ej: `17`)

**Hints Progresivos:**
- **Hint 1:** "Busca en logs DNS, no en security events"
- **Hint 2:** "Patrón sospechoso: subdominios con datos encoded"  
- **Hint 3:** "Cuenta subdominios únicos, no queries totales"

---

## 🔴 NIVEL AVANZADO — Análisis Forense Experto

### Reto 8: "Analista de Comportamiento" (300 pts)
**Pregunta:** "¿Cuál es el usuario que mostró el comportamiento más anómalo (mayor desviación de patrones normales)?"

**Solución Completa:**
1. User & Device → User Activity Analysis
2. Compare patterns: Normal hours vs Off-hours access  
3. Identify user with highest anomaly score
4. Cross-reference with security events
5. **Flag exacta:** `{anomalous_username}` (ej: `jsmith`)

**Hints Progresivos:**
- **Hint 1:** "Analiza patrones de horario de usuarios"
- **Hint 2:** "Busca acceso fuera de horario laboral"
- **Hint 3:** "Cruza datos de User Activity con Security Events"

### Reto 9: "Comandante de Incidentes" (300 pts)
**Pregunta:** "¿Cuántos IOCs (Indicators of Compromise) únicos detectaste en total?"

**Solución Completa:**
1. Compile complete incident timeline del APT
2. Extract all IOCs: IPs, domains, file hashes, registry keys
3. Cross-reference con threat intelligence feeds  
4. Count unique indicators across all categories
5. **Flag exacta:** `{total_unique_iocs}` (ej: `23`)

**Lista de IOCs para Admin Verification:**
```
IPs Maliciosas: [198.51.100.10, 203.45.67.89, etc.]
Dominios: [evil-domain.com, exfil.evil-domain.com, etc.]  
File Hashes: [MD5s de malware samples]
Registry Keys: [persistence mechanisms]
User Accounts: [compromised accounts]
Total: 23 únicos
```

### Reto 10: "Cazador de APT" (300 pts)
**Pregunta:** "¿Cuál es el mecanismo de persistencia que utilizó el APT? (filename completo)"

**Solución Completa:**
1. Advanced Threat Analysis → Persistence Detection
2. Search for: Registry modifications, scheduled tasks, DLL hijacking
3. Identify persistence mechanism en logs de sistema
4. **Flag exacta:** `{persistence_mechanism}` (ej: `svchost32.exe`)

**Hints Progresivos:**
- **Hint 1:** "Busca modificaciones al registro de Windows"
- **Hint 2:** "El APT dejó un archivo falso en System32"  
- **Hint 3:** "Filename muy similar a un proceso legítimo"

---

## 🎮 Sistema de Hints Progresivos

### Protocolo de Ayuda:
1. **Primer pedido de ayuda:** Hint Level 1
2. **Si siguen atorados (5 min):** Hint Level 2  
3. **Si siguen atorados (10 min):** Hint Level 3
4. **Última instancia:** Query SQL exacta o pasos detallados

### Frases para Dar Hints sin Spoilear:
- "¿Ya intentaste la sección de reportes predefinidos?"
- "Recuerda que el timeline es clave en análisis forense"
- "Los ataques APT dejan rastros en múltiples categorías de logs"
- "¿Estás filtrando por el rango de tiempo correcto?"

---

## 📊 Dashboard de Administrador en Tiempo Real

### URLs de Monitoreo:
```
http://flag-server:8080/admin/dashboard     # Progress general
http://flag-server:8080/admin/teams/1      # Estado team específico  
http://flag-server:8080/admin/flags/live   # Flags generadas en vivo
http://flag-server:8080/admin/hints/used   # Hints consumidos por team
```

### Alertas Automáticas:
- 🟡 **Team stuck >10min:** Sugerir hint automáticamente  
- 🔴 **No progress >20min:** Intervención manual recomendada
- 🟢 **Flag submitted:** Verificar si correcto y actualizar leaderboard

---

## 🔧 Comandos de Emergencia

### Reset Challenge para un Team:
```bash
curl -X POST http://flag-server:8080/admin/reset/team1/challenge5
```

### Regenerar Flags Dinámicas:
```bash  
curl -X POST http://flag-server:8080/admin/regenerate/team2
```

### Ver Logs Detallados:
```bash
tail -f /var/log/ctf/team1_detailed.log | grep -E "(flag|error|stuck)"
```

---

## ✅ Checklist Pre-Competencia

### 2 horas antes:
- [ ] Verificar traffic generator corriendo (`--mode advanced`)
- [ ] Confirmar FortiAnalyzer recibiendo logs  
- [ ] Test admin dashboard funcionando
- [ ] Flags dinámicas generándose correctamente

### 30 min antes:
- [ ] Brief a staff sobre sistema de hints
- [ ] Test all admin URLs responding  
- [ ] Backup de flags por equipo en archivo local
- [ ] Emergency reset procedures ready

**🎯 Con esta guía, puedes ayudar a cualquier equipo sin quebrar la experiencia de aprendizaje!**