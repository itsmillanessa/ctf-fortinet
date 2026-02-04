# 🔐 FORTINET CTF — ADMIN SOLUTIONS GUIDE
## ⚠️ DOCUMENTO CONFIDENCIAL — SOLO PARA STAFF

---

# FASE 1: FORTIGATE (7 Challenges, 1,400 pts)

---

## Challenge 1: Primer Acceso (100 pts) 🟢

**Objetivo:** Encontrar flag oculta en la configuración del sistema

**Solución:**
```bash
# Conectar al FortiGate via SSH o GUI
# La flag está en el system alias o description

config system global
    set alias "CTF{team1_recon_e50019cd}"
end

# O también puede estar en:
config system admin
    edit "ctfplayer"
        set comments "Flag: CTF{team1_recon_e50019cd}"
    next
end
```

**Flag:** `CTF{team1_recon_e50019cd}`

**Dónde está:** System > Settings > Alias field (GUI) o `show system global` (CLI)

---

## Challenge 2: Ábrete Sésamo (100 pts) 🟢

**Objetivo:** Crear política NAT para que DMZ salga a internet

**Solución:**
```bash
config firewall policy
    edit 0
        set name "DMZ-to-Internet"
        set srcintf "port3"
        set dstintf "port1"
        set srcaddr "all"
        set dstaddr "all"
        set action accept
        set schedule "always"
        set service "ALL"
        set nat enable
    next
end
```

**Validación:** 
- El servidor DMZ hace ping a 8.8.8.8
- El flag server en 52.207.99.102:8080 detecta el ping y devuelve la flag

**Flag:** `CTF{team1_dmz_breakout_c9c8319e}`

**Cómo validar:** `curl http://52.207.99.102:8080/validate/dmz?team=team1`

---

## Challenge 3: ¿Quién Anda Ahí? (100 pts) 🟢

**Objetivo:** Bloquear IPs maliciosas con address object y política deny

**Solución:**
```bash
# 1. Crear address object
config firewall address
    edit "Malicious-IPs"
        set type iprange
        set start-ip 198.51.100.10
        set end-ip 198.51.100.30
        set comment "IPs maliciosas para bloquear"
    next
end

# O crear grupo con IPs individuales:
config firewall address
    edit "Bad-IP-1"
        set subnet 198.51.100.10/32
    next
    edit "Bad-IP-2"
        set subnet 198.51.100.20/32
    next
    edit "Bad-IP-3"
        set subnet 198.51.100.30/32
    next
end

config firewall addrgrp
    edit "Malicious-IPs"
        set member "Bad-IP-1" "Bad-IP-2" "Bad-IP-3"
    next
end

# 2. Crear política de bloqueo (DEBE IR PRIMERO)
config firewall policy
    edit 0
        set name "Block-Malicious"
        set srcintf "port1"
        set dstintf "any"
        set srcaddr "Malicious-IPs"
        set dstaddr "all"
        set action deny
        set schedule "always"
        set service "ALL"
        set logtraffic all
    next
end

# 3. Mover política al inicio
config firewall policy
    move 1 before 2
end
```

**Flag:** `CTF{team1_blocked_0aae4b8f}`

**Cómo aparece:** En el log cuando se bloquea tráfico de esas IPs (el traffic generator las envía)

---

## Challenge 4: Visión de Túnel (200 pts) 🟡

**Objetivo:** Configurar VPN IPsec site-to-site

**Solución:**
```bash
# Phase 1
config vpn ipsec phase1-interface
    edit "CTF-VPN"
        set interface "port1"
        set ike-version 2
        set peertype any
        set net-device disable
        set proposal aes256-sha256
        set dhgrp 14
        set remote-gw 52.207.99.102
        set psksecret "FortiCTF2026VPN!"
    next
end

# Phase 2
config vpn ipsec phase2-interface
    edit "CTF-VPN-P2"
        set phase1name "CTF-VPN"
        set proposal aes256-sha256
        set dhgrp 14
        set src-subnet 10.10.10.0 255.255.255.0
        set dst-subnet 10.99.0.0 255.255.255.0
    next
end

# Ruta estática
config router static
    edit 0
        set dst 10.99.0.0 255.255.255.0
        set device "CTF-VPN"
    next
end

# Política para tráfico VPN
config firewall policy
    edit 0
        set name "LAN-to-VPN"
        set srcintf "port2"
        set dstintf "CTF-VPN"
        set srcaddr "all"
        set dstaddr "all"
        set action accept
        set schedule "always"
        set service "ALL"
    next
end
```

**Validación:**
```bash
diagnose vpn ike gateway list
diagnose vpn tunnel list
# Luego acceder a: http://10.99.0.1:8080/flag
```

**Flag:** `CTF{team1_vpn_master_6d46f38c}`

---

## Challenge 5: Inspector Gadget (200 pts) 🟡

**Objetivo:** Configurar AV + IPS y detectar EICAR

**Solución:**
```bash
# 1. Crear perfil AntiVirus
config antivirus profile
    edit "CTF-AV"
        config http
            set av-scan enable
        end
        config ftp
            set av-scan enable
        end
    next
end

# 2. Crear sensor IPS
config ips sensor
    edit "CTF-IPS"
        config entries
            edit 1
                set rule 29506
                set status enable
                set action block
            next
        end
    next
end

# Nota: Rule 29506 = Eicar.Virus.Test.File
# También pueden buscar por nombre: "Eicar"

# 3. Aplicar a política de internet
config firewall policy
    edit <policy-id-lan-to-wan>
        set av-profile "CTF-AV"
        set ips-sensor "CTF-IPS"
        set utm-status enable
        set inspection-mode proxy
    next
end
```

**Trigger:**
```bash
# Desde un host en LAN, descargar:
wget http://52.207.99.102:8080/eicar.com
# O desde el FortiGate:
diagnose test application wget http://52.207.99.102:8080/eicar.com
```

**Flag:** `CTF{team1_security_pro_ed3ea86b}`

**Dónde aparece:** Log & Report > Security Events > AntiVirus (el campo msg contiene la flag)

---

## Challenge 6: El Infiltrado (300 pts) 🔴

**Objetivo:** Diagnosticar y arreglar múltiples problemas

**Problemas pre-configurados:**
1. **Ruta default eliminada** → No hay salida a internet
2. **NAT deshabilitado** en política LAN→WAN
3. **Política deny** antes de allow
4. **DNS apuntando a IP inexistente**

**Solución:**
```bash
# 1. Restaurar ruta default
config router static
    edit 1
        set gateway <WAN-gateway-IP>
        set device "port1"
    next
end

# 2. Habilitar NAT
config firewall policy
    edit <lan-to-wan-policy>
        set nat enable
    next
end

# 3. Reordenar políticas
config firewall policy
    move <deny-policy> after <allow-policy>
end

# 4. Arreglar DNS
config system dns
    set primary 8.8.8.8
    set secondary 8.8.4.4
end
```

**Validación:** El servidor de utilidades hace health check automático

**Flag:** `CTF{team1_troubleshooter_55bb7e99}`

---

## Challenge 7: Héroe Zero Trust (300 pts) 🔴

**Objetivo:** Implementar Zero Trust con ISDB y micro-segmentación

**Solución:**
```bash
# 1. Política basada en ISDB (Internet Service Database)
config firewall policy
    edit 0
        set name "Allow-Microsoft-Only"
        set srcintf "port2"
        set dstintf "port1"
        set srcaddr "all"
        set internet-service enable
        set internet-service-name "Microsoft-Office365" "Microsoft-Azure"
        set action accept
        set schedule "always"
        set nat enable
        set logtraffic all
    next
end

# 2. Micro-segmentación LAN ↔ DMZ
config firewall policy
    edit 0
        set name "LAN-to-DMZ-Restricted"
        set srcintf "port2"
        set dstintf "port3"
        set srcaddr "all"
        set dstaddr "all"
        set action accept
        set service "HTTP" "HTTPS" "SSH"
        set logtraffic all
    next
end

# 3. Bloquear tráfico implícito con logging
config firewall policy
    edit 0
        set name "Deny-All-Log"
        set srcintf "any"
        set dstintf "any"
        set srcaddr "all"
        set dstaddr "all"
        set action deny
        set schedule "always"
        set service "ALL"
        set logtraffic all
    next
end

# 4. Verificar Security Rating
get system security-rating
# El rating debe ser B o superior
```

**Flag:** `CTF{team1_zero_trust_68ef87d1}`

**Cómo se calcula:** Hash del output de `get system security-rating`

---

# FASE 2: FORTIANALYZER (10 Challenges, 2,500 pts)

---

## Challenge 8: Bienvenido al SOC (150 pts) 🟢

**Objetivo:** Encontrar primera alerta crítica en FortiAnalyzer

**Solución:**
1. Login a FAZ: https://44.219.5.33
2. Ir a: Log View > Security Events
3. Filtrar: `severity=critical`
4. Ordenar por timestamp (ascendente)
5. Ver el campo `msg` de la primera entrada

**Flag:** `CTF{SOC_WELCOME_<hash>}`

---

## Challenge 9: Cazador de Amenazas (200 pts) 🟡

**Objetivo:** Identificar comunicación C2

**Solución:**
1. FortiView > Threats
2. Buscar conexiones a puertos no estándar (4444, 8443)
3. El host comprometido: 10.10.10.50
4. C2 Server: 198.51.100.10:4444

**Flag formato:** `198.51.100.10:4444`

---

## Challenge 10: Maestro de Filtros (200 pts) 🟡

**Objetivo:** Filtrar eventos P2P bloqueados

**Filtro:**
```
action==blocked AND (app=="BitTorrent" OR app_cat=="P2P")
```

**Flag:** SHA256 del primer archivo bloqueado (campo `filehash`)

---

## Challenge 11: Detective de DNS (250 pts) 🔴

**Objetivo:** Encontrar DNS tunneling y decodificar datos

**Solución:**
1. Log View > DNS Logs
2. Filtrar: `query contains "exfil"`
3. Buscar subdominios muy largos
4. Los subdominios son base64 encoded
5. Concatenar y decodificar:

```bash
echo "c2Vuc2l0aXZlX2RhdGFfZXhmaWx0cmF0ZWQ=" | base64 -d
# Output: sensitive_data_exfiltrated
```

**Flag:** `CTF{DNS_DETECTIVE_<decoded_data>}`

---

## Challenge 12: Correlación de Eventos (300 pts) 🔴

**Objetivo:** Encontrar timestamp del inicio del ataque

**Solución:**
1. Buscar port scans: `action==denied AND service==*`
2. Agrupar por `srcip`
3. Encontrar IP con más eventos denegados
4. Ver primer evento de esa IP
5. Timestamp en formato Unix

**Flag:** `CTF{CORRELATOR_<unix_timestamp>}`

Timestamp esperado: `1706925000` (08:30:00 del día del evento)

---

## Challenge 13: Creador de Reportes (200 pts) 🟡

**Objetivo:** Generar reporte ejecutivo

**Solución:**
1. Reports > Report Definitions > Create New
2. Agregar widgets: Top Threats, Top Attacked, Timeline
3. Generate PDF
4. La flag está en el metadata del PDF (usar `pdfinfo` o `exiftool`)

**Flag:** `CTF{REPORT_MASTER_<hash>}`

---

## Challenge 14: Arquitecto de Alertas (250 pts) 🔴

**Objetivo:** Crear 3 alertas personalizadas

**Solución:**
1. System > Alert > Alert Handler > Create
2. Crear alertas:
   - Brute force: `event count > 100 where action==denied AND service==SSH`
   - Geo: `dstcountry IN (RU, CN, KP, IR)`
   - Malware: `filename LIKE "%.exe" OR filename LIKE "%.scr"`
3. Usar traffic generator para triggear

**Flag:** `CTF{ALERT_ARCHITECT_<hash>}`

---

## Challenge 15: Análisis Forense (350 pts) ⚫

**Objetivo:** Investigar insider threat con USB

**Solución:**
1. Buscar logs de endpoint: `devtype==usb`
2. Correlacionar con file events: `action==copy`
3. Buscar transferencias de red después del USB event
4. El archivo más grande: `financial_data_2026.xlsx`
5. MD5 en el campo `filehash`

**Flag:** `CTF{FORENSIC_EXPERT_<md5>}`

---

## Challenge 16: Cazador de IOCs (300 pts) 🔴

**Objetivo:** Contar hits de IOCs

**Solución:**
```
Filtro: srcip IN (198.51.100.10, 198.51.100.20, 198.51.100.30) 
        OR dstip IN (198.51.100.10, 198.51.100.20, 198.51.100.30)
        OR hostname CONTAINS "evil-domain.com"
```

Contar total de hits, aplicar fórmula: `(total * 7) mod 1000`

**Ejemplo:** Si hay 150 hits → (150 * 7) mod 1000 = 1050 mod 1000 = 50

**Flag:** `CTF{IOC_HUNTER_<resultado>}`

---

## Challenge 17: Maestro SOC (400 pts) ⚫

**Objetivo:** Reconstrucción completa del ataque APT

**Reporte esperado debe incluir:**
1. **Vector de entrada:** Phishing email con adjunto malicioso (.docm)
2. **Persistencia:** Scheduled task creado en host comprometido
3. **Movimiento lateral:** Pass-the-hash usando credenciales robadas
4. **Objetivos:** Servidor de base de datos (10.10.20.10)
5. **Exfiltración:** DNS tunneling hacia exfil.evil-domain.com

**Flag:** SHA256 del reporte completo

---

# 📋 RESUMEN DE FLAGS

| # | Challenge | Flag |
|---|-----------|------|
| 1 | Primer Acceso | `CTF{team1_recon_e50019cd}` |
| 2 | Ábrete Sésamo | `CTF{team1_dmz_breakout_c9c8319e}` |
| 3 | ¿Quién Anda Ahí? | `CTF{team1_blocked_0aae4b8f}` |
| 4 | Visión de Túnel | `CTF{team1_vpn_master_6d46f38c}` |
| 5 | Inspector Gadget | `CTF{team1_security_pro_ed3ea86b}` |
| 6 | El Infiltrado | `CTF{team1_troubleshooter_55bb7e99}` |
| 7 | Héroe Zero Trust | `CTF{team1_zero_trust_68ef87d1}` |
| 8-17 | Fase 2 | (Flags dinámicas basadas en logs) |

---

## 🆘 Troubleshooting Común

**"No puedo conectar al FortiGate"**
- Verificar que el security group permite HTTPS (443)
- Probar con IP directa, no DNS

**"VPN no levanta"**
- Verificar PSK exacto (case sensitive)
- Verificar que Phase1 esté up antes de Phase2
- `diagnose vpn ike gateway list`

**"No veo logs en FortiAnalyzer"**
- Verificar que FortiGate está enviando logs
- Check: `diagnose log device-status`
- El ADOM correcto debe estar seleccionado

**"Flag no es aceptada"**
- Verificar formato exacto: `CTF{...}`
- Sin espacios extras
- Case sensitive

---

*Documento generado para staff del evento*
