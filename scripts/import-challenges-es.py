#!/usr/bin/env python3
"""Import CTF challenges into CTFd — Spanish version with paid hints."""

import argparse
import json
import requests
import sys
import hashlib

CHALLENGES = [
    {
        "id": "recon",
        "name": "🟢 Primer Contacto",
        "category": "Reconocimiento",
        "description": (
            "## Objetivo\n"
            "¡Bienvenido a tu FortiGate! Tu primera misión es simple: **encuentra el hostname y número de serie del equipo.**\n\n"
            "## Instrucciones\n"
            "1. Conéctate por SSH a tu FortiGate con las credenciales proporcionadas\n"
            "2. Explora el CLI — encuentra el hostname y número de serie\n"
            "3. El formato de la flag es: `hostname_numeroserie`\n\n"
            "## Ejemplo\n"
            "Si el hostname es `MiFGT` y el serial es `FGT123ABC`, la flag sería:\n"
            "`MiFGT_FGT123ABC`\n"
        ),
        "value": 100,
        "hints": [
            {"content": "💡 Prueba el comando `get system status` — ahí está todo lo que necesitas.", "cost": 25},
        ],
    },
    {
        "id": "open_sesame",
        "name": "🟢 Ábrete Sésamo",
        "category": "Políticas de Firewall",
        "description": (
            "## Objetivo\n"
            "El servidor en la DMZ (conectado al **port3**) no puede salir a internet. ¡Algo lo está bloqueando!\n\n"
            "## Instrucciones\n"
            "1. Revisa las políticas de firewall actuales\n"
            "2. Encuentra qué está bloqueando el tráfico de la DMZ\n"
            "3. Arregla la política para que la DMZ pueda navegar\n"
            "4. Una vez arreglado, desde la DMZ accede a: `http://<FLAG_SERVER>:8080/secret-page`\n"
            "5. ¡La flag estará en la página!\n\n"
        ),
        "value": 100,
        "hints": [
            {"content": "💡 Revisa la política ID 2 — ¿cuál es la acción configurada?", "cost": 25},
            {"content": "💡 ¡No olvides habilitar NAT en la política!", "cost": 25},
        ],
    },
    {
        "id": "who_goes_there",
        "name": "🟢 ¿Quién Anda Ahí?",
        "category": "Objetos de Dirección",
        "description": (
            "## Objetivo\n"
            "¡Tu red está bajo ataque desde IPs maliciosas conocidas! Bloquéalas.\n\n"
            "## Instrucciones\n"
            "1. Crea objetos de dirección para estas IPs maliciosas:\n"
            "   - `198.51.100.10`\n"
            "   - `198.51.100.20`\n"
            "   - `198.51.100.30`\n"
            "2. Crea un grupo de direcciones llamado **`Malicious-IPs`** con las tres\n"
            "3. Crea una política **DENY** para tráfico entrante DESDE estas IPs\n"
            "4. Una vez activa tu política, solicita tu flag en:\n"
            "   `http://<FLAG_SERVER>:8080/api/flag/who_goes_there`\n\n"
        ),
        "value": 100,
        "hints": [
            {"content": "💡 El generador de tráfico está enviando paquetes constantemente desde esas IPs.", "cost": 25},
            {"content": "💡 Tu política deny debe estar ARRIBA de las políticas allow.", "cost": 25},
        ],
    },
    {
        "id": "tunnel_vision",
        "name": "🟡 Visión de Túnel",
        "category": "VPN",
        "description": (
            "## Objetivo\n"
            "Establece un **túnel VPN IPsec** hacia el servidor central y obtén la flag del otro lado.\n\n"
            "## Parámetros de VPN\n"
            "| Parámetro | Valor |\n"
            "|-----------|-------|\n"
            "| Versión IKE | **2** |\n"
            "| Pre-Shared Key | **`CTFortinet2026`** |\n"
            "| Gateway Remoto | **`<UTILITY_SERVER_IP>`** |\n"
            "| Subred Local | Tu LAN: **`10.x.2.0/24`** |\n"
            "| Subred Remota | **`172.16.100.0/24`** |\n"
            "| Cifrado | AES256 |\n"
            "| Autenticación | SHA256 |\n"
            "| Grupo DH | 14 |\n\n"
            "## Instrucciones\n"
            "1. Configura Fase 1 (IKE) con los parámetros de arriba\n"
            "2. Configura Fase 2 (IPsec) con los selectores correctos\n"
            "3. Levanta el túnel\n"
            "4. Desde tu LAN, accede a: `http://172.16.100.1/vpn-flag`\n"
            "5. ¡La flag estará en la respuesta!\n\n"
        ),
        "value": 200,
        "hints": [
            {"content": "💡 Usa `diag vpn ike gateway list` para verificar Fase 1", "cost": 50},
            {"content": "💡 Usa `diag vpn tunnel list` para verificar Fase 2", "cost": 50},
            {"content": "💡 ¡No olvides crear una política de firewall que permita tráfico por la VPN!", "cost": 50},
        ],
    },
    {
        "id": "inspector_gadget",
        "name": "🟡 Inspector Gadget",
        "category": "Perfiles de Seguridad",
        "description": (
            "## Objetivo\n"
            "Habilita y configura la **inspección de seguridad** en tu FortiGate para detectar amenazas.\n\n"
            "## Instrucciones\n"
            "1. Crea un perfil de **AntiVirus** llamado `ctf-av`\n"
            "2. Crea un sensor **IPS** llamado `ctf-ips`\n"
            "   - Habilita la firma con ID **41748**\n"
            "3. Aplica **ambos perfiles** a tu política LAN-to-WAN (Política 1)\n"
            "4. El generador de tráfico está enviando archivos EICAR y exploits\n"
            "5. Una vez configurado, solicita tu flag:\n"
            "   `http://<FLAG_SERVER>:8080/api/flag/inspector_gadget`\n\n"
        ),
        "value": 200,
        "hints": [
            {"content": "💡 Puede que necesites configurar SSL inspection (al menos certificate-inspection)", "cost": 50},
            {"content": "💡 Revisa `Log & Report > Security Events` después de habilitar los perfiles", "cost": 50},
            {"content": "💡 El validador verifica por SSH que los perfiles existan Y estén aplicados", "cost": 50},
        ],
    },
    {
        "id": "the_insider",
        "name": "🔴 El Infiltrado",
        "category": "Troubleshooting",
        "description": (
            "## Objetivo\n"
            "⚠️ **ALERTA:** ¡Alguien saboteó este FortiGate! Hay múltiples cosas rotas.\n\n"
            "## Problemas Reportados\n"
            "Los usuarios reportan los siguientes problemas:\n"
            "1. ❌ **No pueden acceder a internet** desde la LAN\n"
            "2. ❌ **DNS no resuelve** ningún dominio\n"
            "3. ❌ **El tráfico se va al lugar equivocado** a veces\n"
            "4. ❌ **No se puede acceder al GUI** remotamente\n\n"
            "## Instrucciones\n"
            "1. Conéctate por SSH al FortiGate e investiga\n"
            "2. Encuentra y arregla **LOS 4 PROBLEMAS**\n"
            "3. Cuando todo funcione, desde tu LAN accede a:\n"
            "   `http://<FLAG_SERVER>:8080/api/flag/the_insider`\n"
            "4. El validador verificará las 4 correcciones antes de entregar la flag\n\n"
        ),
        "value": 300,
        "hints": [
            {"content": "💡 `diagnose debug flow` es tu mejor amigo para ver qué pasa con los paquetes", "cost": 75},
            {"content": "💡 `diagnose sniffer` te muestra qué está pasando a nivel de paquete", "cost": 75},
            {"content": "💡 Revisa: rutas estáticas, configuración DNS, NAT, y allowaccess en interfaces", "cost": 75},
        ],
    },
    {
        "id": "zero_trust",
        "name": "🔴 Héroe Zero Trust",
        "category": "Política Avanzada",
        "description": (
            "## Objetivo\n"
            "Implementa una arquitectura de **segmentación Zero Trust** en tu FortiGate.\n\n"
            "## Requisitos\n"
            "1. Crea **políticas basadas en ISDB** que solo permitan HTTPS y DNS desde LAN hacia WAN\n"
            "2. **Bloquea TODO el tráfico** entre LAN y DMZ **excepto SSH** (puerto 22)\n"
            "3. Habilita **Application Control** para bloquear redes sociales\n"
            "4. **Todo el tráfico denegado** debe ser registrado en logs\n\n"
            "## Instrucciones\n"
            "1. Reemplaza la política permisiva LAN-to-WAN con reglas ISDB específicas\n"
            "2. Crea políticas inter-zona para segmentación LAN↔DMZ\n"
            "3. Crea y aplica un perfil de Application Control\n"
            "4. Habilita logging de deny implícito\n"
            "5. Solicita tu flag:\n"
            "   `http://<FLAG_SERVER>:8080/api/flag/zero_trust`\n\n"
        ),
        "value": 300,
        "hints": [
            {"content": "💡 Usa `internet-service-name` en tus políticas para ISDB", "cost": 75},
            {"content": "💡 Revisa el `Security Rating` — apunta a >60%", "cost": 75},
            {"content": "💡 Categorías de aplicación: 'Social.Media' para bloquear redes sociales", "cost": 75},
        ],
    },
]


class CTFdAPI:
    def __init__(self, url, token):
        self.url = url.rstrip('/')
        self.session = requests.Session()
        self.session.headers.update({
            'Authorization': f'Token {token}',
            'Content-Type': 'application/json'
        })

    def get(self, endpoint):
        r = self.session.get(f'{self.url}/api/v1{endpoint}')
        r.raise_for_status()
        return r.json()

    def post(self, endpoint, data):
        r = self.session.post(f'{self.url}/api/v1{endpoint}', json=data)
        if r.status_code not in [200, 201]:
            print(f"  ❌ POST {endpoint} failed: {r.status_code} {r.text}")
            return None
        return r.json()

    def patch(self, endpoint, data):
        r = self.session.patch(f'{self.url}/api/v1{endpoint}', json=data)
        r.raise_for_status()
        return r.json()


def generate_team_flag(challenge_id, team_num, event_name="fortinet-ctf"):
    hash_val = hashlib.md5(f"{challenge_id}-{team_num}-{event_name}".encode()).hexdigest()[:8]
    name_map = {
        "recon": "recon",
        "open_sesame": "dmz_breakout",
        "who_goes_there": "blocked",
        "tunnel_vision": "vpn_master",
        "inspector_gadget": "security_pro",
        "the_insider": "troubleshooter",
        "zero_trust": "zero_trust",
    }
    name = name_map.get(challenge_id, challenge_id)
    return f"CTF{{team{team_num}_{name}_{hash_val}}}"


def import_challenges(api, team_count, event_name, flag_server_ip=""):
    print(f"\n🎯 Importando {len(CHALLENGES)} retos a CTFd...")
    print(f"   Equipos: {team_count} | Evento: {event_name}\n")

    for ch in CHALLENGES:
        description = ch["description"]
        if flag_server_ip:
            description = description.replace("<FLAG_SERVER>", flag_server_ip)
            description = description.replace("<UTILITY_SERVER_IP>", flag_server_ip)

        data = {
            "name": ch["name"],
            "category": ch["category"],
            "description": description,
            "value": ch["value"],
            "type": "standard",
            "state": "visible",
            "max_attempts": 0,  # unlimited
        }

        result = api.post('/challenges', data)
        if result and result.get('success'):
            cid = result['data']['id']
            print(f"  ✅ {ch['name']} (ID: {cid}, {ch['value']} pts)")

            # Add flags per team
            for team_num in range(1, team_count + 1):
                flag = generate_team_flag(ch["id"], team_num, event_name)
                api.post('/flags', {
                    "challenge_id": cid,
                    "content": flag,
                    "type": "static",
                    "data": f"team-{team_num}"
                })

            # For recon: also accept hostname_serial format
            if ch["id"] == "recon":
                for team_num in range(1, team_count + 1):
                    # Accept with and without CTF{} wrapper
                    api.post('/flags', {
                        "challenge_id": cid,
                        "content": f"CTF-TEAM-{team_num}-FGT_.*",
                        "type": "regex",
                        "data": f"team-{team_num}-hostname"
                    })

            print(f"      → {team_count} flags de equipo agregadas")

            # Add paid hints
            for hint in ch.get("hints", []):
                api.post('/hints', {
                    "challenge_id": cid,
                    "content": hint["content"],
                    "cost": hint["cost"],
                    "type": "standard"
                })
                print(f"      → Hint agregado (costo: {hint['cost']} pts)")
        else:
            print(f"  ❌ Falló al crear: {ch['name']}")

    print(f"\n✅ ¡Importación de retos completa!")


def create_teams(api, team_count):
    print(f"\n👥 Creando {team_count} equipos...")
    for i in range(1, team_count + 1):
        result = api.post('/users', {
            "name": f"Equipo {i}",
            "email": f"team{i}@ctf.local",
            "password": f"team{i}ctf2026",
            "type": "user",
            "verified": True,
            "hidden": False,
            "banned": False,
        })
        if result and result.get('success'):
            print(f"  ✅ Equipo {i} (user: team{i}@ctf.local, pass: team{i}ctf2026)")
        else:
            print(f"  ⚠️  Equipo {i} ya existe o error")
    print(f"\n✅ ¡Equipos creados!")


def main():
    parser = argparse.ArgumentParser(description='Importar retos a CTFd (español)')
    parser.add_argument('--url', required=True)
    parser.add_argument('--token', required=True)
    parser.add_argument('--teams', type=int, default=1)
    parser.add_argument('--event', default='fortinet-ctf')
    parser.add_argument('--flag-server', default='')
    parser.add_argument('--skip-teams', action='store_true')
    args = parser.parse_args()

    api = CTFdAPI(args.url, args.token)

    try:
        api.get('/challenges')
        print(f"✅ Conectado a CTFd en {args.url}")
    except Exception as e:
        print(f"❌ No se puede conectar a CTFd: {e}")
        sys.exit(1)

    import_challenges(api, args.teams, args.event, args.flag_server)

    if not args.skip_teams:
        create_teams(api, args.teams)

    print(f"\n🏁 ¡Listo! CTFd preparado en {args.url}")


if __name__ == '__main__':
    main()
