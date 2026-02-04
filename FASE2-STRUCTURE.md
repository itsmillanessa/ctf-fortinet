# 🛡️ CTF FORTINET — FASE 2: FortiAnalyzer Análisis de Logs y Respuesta a Incidentes

## 📋 Estructura General

**Stack:** FortiGate + FortiAnalyzer + Generadores de Datos  
**Participantes:** 5 equipos, 5 personas por equipo  
**Duración:** 4 horas  
**Puntos Totales:** 2,500 puntos  
**Idioma:** Español  

---

## 🟢 NIVEL BÁSICO — Fundamentos de Análisis de Logs (700 puntos)

### Reto 1: "Primera Vista" (100 pts)
**Objetivo:** Familiarizarse con el dashboard de FortiAnalyzer  
**Tarea:** Acceder a FAZ, identificar número total de logs en las últimas 24 horas  
**Habilidades:** Navegación básica, lectura de dashboard  
**Ubicación flag:** En el dashboard principal  
**Datos necesarios:** Logs normales de tráfico  

### Reto 2: "El Filtro Maestro" (150 pts) 
**Objetivo:** Consultas básicas por campos comunes  
**Tarea:** Encontrar todos los logs de una IP específica en ventana de tiempo  
**Habilidades:** Filtrado básico, selección de rango temporal  
**Ubicación flag:** En comentario de log específico  
**Datos necesarios:** Tráfico mixto con IP objetivo plantada  

### Reto 3: "Reporte Exprés" (200 pts)
**Objetivo:** Generar reportes predefinidos  
**Tarea:** Crear reporte "Top IPs de Origen" y identificar el #3 en la lista  
**Habilidades:** Generación de reportes, interpretación de datos  
**Ubicación flag:** La dirección IP se decodificará al flag  
**Datos necesarios:** Tráfico intenso desde múltiples fuentes  

### Reto 4: "Detective Novato" (250 pts)
**Objetivo:** Identificar amenazas evidentes  
**Tarea:** Encontrar intento de escaneo de puertos y determinar IPs involucradas  
**Habilidades:** Reconocimiento de amenazas, identificación de patrones  
**Ubicación flag:** Concatenación de IPs origen + destino  
**Datos necesarios:** Escaneo nmap evidente en logs  

---

## 🟡 NIVEL INTERMEDIO — Correlación y Análisis Avanzado (900 puntos)

### Reto 5: "El Correlador de Eventos" (250 pts)
**Objetivo:** Vincular múltiples eventos del mismo atacante  
**Tarea:** Rastrear un atacante a través de múltiples fases de ataque  
**Habilidades:** Correlación de eventos, análisis multi-etapa  
**Ubicación flag:** En el payload final del atacante  
**Datos necesarios:** Ataque multi-etapa (reconocimiento → explotación → persistencia)  

### Reto 6: "Maestro del Timeline" (300 pts)
**Objetivo:** Reconstruir secuencia completa del incidente  
**Tarea:** Determinar timeline exacto de una fuga de datos  
**Habilidades:** Análisis temporal, reconstrucción de incidentes  
**Ubicación flag:** Timestamp de exfiltración de datos codificado  
**Datos necesarios:** Ataque complejo con múltiples marcas de tiempo  

### Reto 7: "Cazador de Patrones" (350 pts)
**Objetivo:** Detectar patrones de tunelización DNS  
**Tarea:** Identificar dominio utilizado para exfiltración de datos  
**Habilidades:** Reconocimiento avanzado de patrones, análisis DNS  
**Ubicación flag:** En el nombre de dominio de tunelización  
**Datos necesarios:** Tunelización DNS con datos ocultos en consultas  

---

## 🔴 NIVEL AVANZADO — Caza de Amenazas Experto (900 puntos)

### Reto 8: "Analista de Comportamiento" (300 pts)
**Objetivo:** Detectar comportamiento anómalo de usuarios  
**Tarea:** Identificar cuenta de usuario comprometida por patrones de comportamiento  
**Habilidades:** Análisis de comportamiento de usuarios, detección de anomalías  
**Ubicación flag:** Nombre de usuario de la cuenta comprometida  
**Datos necesarios:** Patrones de actividad normal vs anormal de usuarios  

### Reto 9: "Comandante de Incidentes" (300 pts)
**Objetivo:** Flujo completo de respuesta a incidentes  
**Tarea:** Documentar respuesta completa a incidente siguiendo playbook  
**Habilidades:** Gestión de incidentes, documentación, contención  
**Ubicación flag:** En combinación de IOCs encontrados  
**Datos necesarios:** Ataque complejo multi-vector que requiere contención  

### Reto 10: "Cazador de APT" (300 pts)
**Objetivo:** Detectar Amenaza Persistente Avanzada  
**Tarea:** Encontrar mecanismo de persistencia de compromiso de largo plazo  
**Habilidades:** Detección avanzada de amenazas, análisis de persistencia  
**Ubicación flag:** En clave/archivo de persistencia del registry  
**Datos necesarios:** APT sutil con técnicas living-off-the-land  

---

## 🎯 Estrategia de Generación de Datos

### Tipos de Tráfico Necesarios:
1. **Tráfico Normal Base** (80%)
   - Navegación HTTP/HTTPS  
   - Consultas DNS normales  
   - Tráfico de email  
   - Actualizaciones de software  

2. **Tráfico de Ataque** (15%)
   - Escaneos de puertos (nmap, masscan)  
   - Exploits web (SQLi, XSS, RCE)  
   - Descargas de malware  
   - Movimiento lateral  
   - Exfiltración de datos  

3. **Ruido/Señuelos** (5%)
   - Falsos positivos  
   - Eventos distractor  
   - Anomalías benignas  

### Escenarios de Ataque:
- **Escenario A:** Reconocimiento externo → explotación → persistencia  
- **Escenario B:** Amenaza interna → escalación de privilegios → robo de datos  
- **Escenario C:** APT → compromiso a largo plazo → exfiltración sigilosa  
- **Escenario D:** Ransomware → propagación lateral → destrucción de backups  

---

## 🏗️ Requerimientos Técnicos

### Configuración FortiAnalyzer:
- **Instancia:** m5.large (2 vCPU, 8GB RAM, 100GB almacenamiento)  
- **Retención de logs:** 7 días mínimo  
- **Tasa de logs:** 1000-2000 logs/hora por equipo  
- **Datasets:** Pre-cargados con 48-72 horas de datos  

### Puntos de Integración:
- **Logs FortiGate:** Eventos de seguridad, tráfico, sistema  
- **Logs personalizados:** Logs de aplicación vía syslog  
- **Feeds externos:** Integración de threat intelligence  

### Distribución de Retos:
- **FortiAnalyzer por equipo** con datasets idénticos  
- **Elementos aleatorios** (IPs, timestamps) para prevenir copia  
- **Verificación automática de flags** vía llamadas API  

---

## 📊 Scoring Matrix

| Nivel | Retos | Puntos Base | Bonus Posible | Total Máx |
|-------|-------|-------------|---------------|-----------|
| Básico | 4 | 700 | 100 | 800 |
| Intermedio | 3 | 900 | 150 | 1,050 |
| Avanzado | 3 | 900 | 200 | 1,100 |
| **TOTAL** | **10** | **2,500** | **450** | **2,950** |

### Categorías de Bonus:
- **Bonus Velocidad:** Primeros 3 equipos en completar nivel  
- **Bonus Estilo:** Mejor documentación/metodología  
- **Bonus Descubrimiento:** Encontrar IOCs adicionales no incluidos en retos principales  

---

## 🎮 Flujo de Competencia

### Pre-Competencia (1 hora):
- Equipos reciben credenciales de FortiAnalyzer  
- Sesión breve de orientación  
- Reto de práctica (sin puntos)  

### Competencia (4 horas):
- **Hora 1:** Nivel Básico (calentamiento)  
- **Hora 2-3:** Nivel Intermedio (reto principal)  
- **Hora 4:** Nivel Avanzado (nivel experto) + empuje final  

### Post-Competencia (30 min):
- Recorrido de soluciones  
- Discusión de mejores prácticas  
- Recomendaciones de herramientas  

---

## 🛡️ Seguridad y Aislamiento

### Aislamiento de Red:
- VPC dedicada por evento  
- Sin acceso a internet excepto feeds controlados  
- Subredes aisladas por equipo  

### Seguridad de Datos:
- Solo datos de ataque sintéticos  
- Sin información corporativa real  
- Datos dummy compatibles con GDPR  

### Limpieza:
- Destrucción automatizada de recursos  
- Cero persistencia de datos post-evento  
- Optimización de costos vía instancias spot  