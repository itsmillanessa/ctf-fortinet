#!/bin/bash
set -e

# =============================================================================
# CTFd Auto-Deploy Script
# Installs Docker + CTFd + Nginx reverse proxy
# =============================================================================

export DEBIAN_FRONTEND=noninteractive

# --- System setup ---
apt-get update -y
apt-get install -y docker.io docker-compose-v2 nginx certbot python3-certbot-nginx jq curl

systemctl enable docker
systemctl start docker

# --- Create CTFd directory ---
mkdir -p /opt/ctfd
cd /opt/ctfd

# --- Docker Compose for CTFd ---
cat > docker-compose.yml <<'COMPOSE'
version: '3.8'

services:
  ctfd:
    image: ctfd/ctfd:latest
    container_name: ctfd
    restart: always
    ports:
      - "8000:8000"
    environment:
      - WORKERS=4
      - SECRET_KEY=${event_name}-secret-key-2026
      - DATABASE_URL=mysql+pymysql://ctfd:ctfd_password@db/ctfd
      - REDIS_URL=redis://cache:6379
      - LOG_FOLDER=/var/log/CTFd
      - UPLOAD_FOLDER=/var/uploads
      - REVERSE_PROXY=true
    volumes:
      - ctfd-logs:/var/log/CTFd
      - ctfd-uploads:/var/uploads
    depends_on:
      - db
      - cache
    networks:
      - ctfd-net

  db:
    image: mariadb:10.11
    container_name: ctfd-db
    restart: always
    environment:
      - MYSQL_ROOT_PASSWORD=ctfd_root_2026
      - MYSQL_USER=ctfd
      - MYSQL_PASSWORD=ctfd_password
      - MYSQL_DATABASE=ctfd
    volumes:
      - ctfd-db:/var/lib/mysql
    networks:
      - ctfd-net
    command: [mysqld, --character-set-server=utf8mb4, --collation-server=utf8mb4_unicode_ci, --wait_timeout=28800, --log-warnings=0]

  cache:
    image: redis:7-alpine
    container_name: ctfd-cache
    restart: always
    volumes:
      - ctfd-redis:/data
    networks:
      - ctfd-net

volumes:
  ctfd-db:
  ctfd-redis:
  ctfd-logs:
  ctfd-uploads:

networks:
  ctfd-net:
COMPOSE

# --- Start CTFd ---
docker compose up -d

# --- Nginx reverse proxy ---
cat > /etc/nginx/sites-available/ctfd <<'NGINX'
server {
    listen 80 default_server;
    server_name _;

    client_max_body_size 100M;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket support (for live scoreboard)
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
NGINX

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/ctfd /etc/nginx/sites-enabled/ctfd
systemctl restart nginx

# --- Wait for CTFd to be ready ---
echo "Waiting for CTFd to start..."
for i in $(seq 1 60); do
    if curl -s -o /dev/null -w "%%{http_code}" http://localhost:8000/setup | grep -q "200\|302"; then
        echo "CTFd is ready!"
        break
    fi
    sleep 5
done

# --- Auto-setup CTFd via API ---
# Initial setup (creates admin user + configures CTF)
curl -s -X POST http://localhost:8000/setup \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "ctf_name=Fortinet+Security+CTF" \
  -d "ctf_description=Fortinet+Network+Security+Challenge+-+Test+your+FortiGate+skills!" \
  -d "user_mode=teams" \
  -d "name=admin" \
  -d "email=admin@fortinet-ctf.local" \
  -d "password=${admin_password}" \
  -d "ctf_theme=core" \
  -d "start=" \
  -d "end=" \
  -d "nonce=" || true

echo "CTFd setup complete!" > /tmp/ctfd-ready

# --- Save metadata for provisioning script ---
cat > /opt/ctfd/metadata.json <<METADATA
{
  "event_name": "${event_name}",
  "team_count": ${team_count},
  "admin_password": "${admin_password}",
  "status": "ready"
}
METADATA

echo "=== CTFd deployment finished ==="
