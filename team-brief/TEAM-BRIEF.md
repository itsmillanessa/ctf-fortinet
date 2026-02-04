# 🔥 FORTINET SECURITY CTF — TEAM BRIEF

## Información General

| Campo | Valor |
|-------|-------|
| **Evento** | Fortinet Security CTF |
| **Duración** | 4 horas |
| **Total Challenges** | 17 (Fase 1 + Fase 2) |
| **Puntos Totales** | 3,900 pts |

---

## 🌐 Recursos del Equipo

### Portal CTF
- **URL:** http://18.211.80.211
- **Usuario:** player1
- **Password:** team1ctf2026

### FortiGate (Tu Firewall)
- **URL:** https://34.193.180.32
- **Usuario:** ctfplayer
- **Password:** CTFPlayer2026!

### FortiAnalyzer (Centro de Logs)
- **URL:** https://44.219.5.33
- **Usuario:** team1-analyst
- **Password:** CTFteam12026!

### Servidor de Utilidades
- **IP:** 52.207.99.102
- **Flag Server:** http://52.207.99.102:8080
- **EICAR Test File:** http://52.207.99.102:8080/eicar.com

---

## 🔧 Arquitectura de Red

```
                    ┌─────────────────┐
                    │    INTERNET     │
                    │   (port1/WAN)   │
                    └────────┬────────┘
                             │
                    ┌────────┴────────┐
                    │   FORTIGATE     │
                    │  34.193.180.32  │
                    └┬───────┬───────┬┘
                     │       │       │
              ┌──────┴──┐ ┌──┴───┐ ┌─┴──────┐
              │  LAN    │ │ DMZ  │ │  WAN   │
              │ port2   │ │port3 │ │ port1  │
              └────┬────┘ └──┬───┘ └────────┘
                   │         │
           10.10.10.0/24  10.10.20.0/24
```

### Interfaces
| Interface | Zona | Subnet | Descripción |
|-----------|------|--------|-------------|
| port1 | WAN | DHCP (Público) | Conexión a Internet |
| port2 | LAN | 10.10.10.1/24 | Red interna de usuarios |
| port3 | DMZ | 10.10.20.1/24 | Zona desmilitarizada (servidores) |

---

## 🔐 Parámetros VPN (Challenge: Visión de Túnel)

### Phase 1 (IKE)
| Parámetro | Valor |
|-----------|-------|
| Versión | IKEv2 |
| Remote Gateway | 52.207.99.102 |
| Interface | port1 |
| Autenticación | Pre-shared Key |
| **PSK** | `FortiCTF2026VPN!` |
| Encryption | AES256 |
| Hash | SHA256 |
| DH Group | 14 |
| Lifetime | 86400 |

### Phase 2 (IPsec)
| Parámetro | Valor |
|-----------|-------|
| Local Subnet | 10.10.10.0/24 |
| Remote Subnet | 10.99.0.0/24 |
| Encryption | AES256 |
| Hash | SHA256 |
| PFS | enable (DH Group 14) |
| Lifetime | 43200 |

---

## 🛡️ IPs Maliciosas (Challenge: ¿Quién Anda Ahí?)

Las siguientes IPs han sido identificadas como maliciosas y deben ser bloqueadas:

```
198.51.100.10
198.51.100.20
198.51.100.30
```

**Nota:** Estas IPs pertenecen al rango de documentación RFC 5737, usadas para este ejercicio.

---

## 🦠 Información de Amenazas

### Archivo de Prueba EICAR
- **Propósito:** Validar que tu AntiVirus/IPS funciona correctamente
- **URL de descarga:** http://52.207.99.102:8080/eicar.com
- **Comportamiento esperado:** Debe ser detectado y bloqueado por tu perfil de seguridad

### IOCs de Campaña APT (Fase 2)
| Tipo | Valor |
|------|-------|
| IP C2 #1 | 198.51.100.10 |
| IP C2 #2 | 198.51.100.20 |
| IP C2 #3 | 198.51.100.30 |
| Dominio | evil-domain.com |
| Subdominio | exfil.evil-domain.com |

### Timeline del Ataque APT (Fase 2)
| Fase | Hora (aprox) | Indicador |
|------|--------------|-----------|
| Reconocimiento | 08:30 | Port scanning |
| Acceso Inicial | 10:15 | Exploit attempt |
| Persistencia | 12:45 | Scheduled task |
| Movimiento Lateral | 13:30 | Credential theft |
| Exfiltración | 14:23 | DNS tunneling |

---

## 📋 Formato de Flags

Todas las flags tienen el formato:
```
CTF{texto_descriptivo_aqui}
```

**Ejemplos válidos:**
- `CTF{mi_primera_flag}`
- `CTF{team1_recon_abc123}`
- `CTF{192.168.1.1:443}`

---

## 🎯 Tips Generales

### FortiGate CLI Útiles
```bash
# Ver configuración actual
show full-configuration

# Ver estado de interfaces
get system interface

# Ver políticas de firewall
show firewall policy

# Ver rutas
get router info routing-table all

# Diagnosticar VPN
diagnose vpn ike gateway list
diagnose vpn tunnel list

# Ver logs en tiempo real
diagnose log test
```

### FortiAnalyzer Tips
- Usa **FortiView** para dashboards visuales
- Usa **Log View** para búsquedas detalladas
- Filtra por `severity=critical` para alertas importantes
- El campo `msg` suele contener información clave

---

## ⚠️ Reglas del CTF

1. **No ataques** a otros equipos ni a la infraestructura del CTF
2. **No compartas** flags o soluciones con otros equipos
3. Las **pistas cuestan puntos** - úsalas sabiamente
4. El **saldo negativo** está permitido
5. **Tiempo límite:** 4 horas

---

## 🆘 Soporte

Si tienes problemas técnicos (no relacionados con los challenges):
- Levanta la mano
- Contacta al staff del evento

**¡Buena suerte!** 🚀
