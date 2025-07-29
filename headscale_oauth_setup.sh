#!/bin/bash

# === Simple Login/Logout Authentication ===

USERS_FILE="users.txt"
SESSION_FILE=".session"

function hash_password() {
  echo -n "$1" | sha256sum | awk '{print $1}'
}

function create_user() {
  echo "No user found. Let's create an admin user."
  read -p "Create a username: " USERNAME
  read -s -p "Create a password: " PASSWORD
  echo
  HASHED_PASS=$(hash_password "$PASSWORD")
  echo "$USERNAME:$HASHED_PASS" >> "$USERS_FILE"
  echo "User '$USERNAME' created."
}

function login() {
  read -p "Username: " USERNAME
  read -s -p "Password: " PASSWORD
  echo
  HASHED_PASS=$(hash_password "$PASSWORD")

  if grep -q "^$USERNAME:$HASHED_PASS$" "$USERS_FILE"; then
    echo "$USERNAME" > "$SESSION_FILE"
    echo "Login successful. Welcome, $USERNAME."
  else
    echo "Invalid credentials."
    exit 1
  fi
}

function logout() {
  rm -f "$SESSION_FILE"
  echo "Logged out successfully."
  exit 0
}

# === Handle logout flag ===
if [[ "$1" == "logout" ]]; then
  logout
fi

# === Setup users if not exists ===
if [ ! -f "$USERS_FILE" ]; then
  create_user
fi

# === Session check ===
if [ ! -f "$SESSION_FILE" ]; then
  echo "Please log in:"
  login
else
  USER=$(cat "$SESSION_FILE")
  echo "Welcome back, $USER."
fi

# === Root check ===
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root."
  exit 1
fi

# === Domain prompt ===
read -p "Enter your full domain (e.g., headscale.example.com): " FULL_DOMAIN

# === Create directories ===
mkdir -p headscale/data headscale/configs/headscale

# === Create docker-compose.yaml ===
cat <<EOF > headscale/docker-compose.yaml
services:
  headscale:
    image: 'headscale/headscale:latest'
    container_name: 'headscale'
    restart: 'unless-stopped'
    command: 'serve'
    volumes:
      - './data:/var/lib/headscale'
      - './configs/headscale:/etc/headscale'
    environment:
      TZ: 'America/New_York'
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.headscale.rule=Host(\`$FULL_DOMAIN\`)"
      - "traefik.http.routers.headscale.tls.certresolver=myresolver"
      - "traefik.http.routers.headscale.entrypoints=websecure"
      - "traefik.http.routers.headscale.tls=true"
      - "traefik.http.services.headscale.loadbalancer.server.port=8080"

  headscale-admin:
    image: 'goodieshq/headscale-admin:latest'
    container_name: 'headscale-admin'
    restart: 'unless-stopped'
    labels:
      - "traefik.enable=true"
      - "traefik.http.services.headscale-admin.loadbalancer.server.port=80"
      - "traefik.http.routers.headscale-admin.rule=Host(\`$FULL_DOMAIN\`) && PathPrefix(\`/admin\`)"
      - "traefik.http.routers.headscale-admin.entrypoints=websecure"
      - "traefik.http.routers.headscale-admin.tls=true"

  traefik:
    image: "traefik:latest"
    container_name: "traefik"
    command:
      - "--api.insecure=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entryPoints.web.address=:80"
      - "--entrypoints.web.http.redirections.entrypoint.to=websecure"
      - "--entrypoints.web.http.redirections.entrypoint.scheme=https"
      - "--entryPoints.websecure.address=:443"
      - "--certificatesresolvers.myresolver.acme.httpchallenge=true"
      - "--certificatesresolvers.myresolver.acme.httpchallenge.entrypoint=web"
      - "--certificatesresolvers.myresolver.acme.email=you@yourdomain.com"
      - "--certificatesresolvers.myresolver.acme.storage=/letsencrypt/acme.json"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - "./letsencrypt:/letsencrypt"
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
EOF

# === Create config.yaml for Headscale ===
cat <<EOF > headscale/configs/headscale/config.yaml
server_url: https://$FULL_DOMAIN
listen_addr: 0.0.0.0:8080
metrics_listen_addr: 127.0.0.1:9090
grpc_listen_addr: 127.0.0.1:50443
grpc_allow_insecure: false
noise:
  private_key_path: /var/lib/headscale/noise_private.key
prefixes:
  v4: 100.64.0.0/10
  v6: fd7a:115c:a1e0::/48
  allocation: sequential
derp:
  server:
    enabled: true
    region_id: 999
    region_code: "headscale"
    region_name: "Headscale Embedded DERP"
    stun_listen_addr: "0.0.0.0:3478"
    private_key_path: /var/lib/headscale/derp_server_private.key
    automatically_add_embedded_derp_region: true
    ipv4: 1.2.3.4
    ipv6: 2001:db8::1
  urls:
    - https://controlplane.tailscale.com/derpmap/default
  paths: []
  auto_update_enabled: true
  update_frequency: 24h
disable_check_updates: false
ephemeral_node_inactivity_timeout: 30m
database:
  type: sqlite
  debug: false
  gorm:
    prepare_stmt: true
    parameterized_queries: true
    skip_err_record_not_found: true
    slow_threshold: 1000
  sqlite:
    path: /var/lib/headscale/db.sqlite
    write_ahead_log: true
    wal_autocheckpoint: 1000
acme_url: https://acme-v02.api.letsencrypt.org/directory
acme_email: ""
tls_letsencrypt_hostname: ""
tls_letsencrypt_cache_dir: /var/lib/headscale/cache
tls_letsencrypt_challenge_type: HTTP-01
tls_letsencrypt_listen: ":http"
tls_cert_path: ""
tls_key_path: ""
log:
  format: text
  level: info
policy:
  mode: database
  path: ""
dns:
  magic_dns: true
  base_domain: example.com
  nameservers:
    global:
      - 1.1.1.1
      - 1.0.0.1
      - 2606:4700:4700::1111
      - 2606:4700:4700::1001
    split: {}
  search_domains: []
  extra_records: []
unix_socket: /var/run/headscale/headscale.sock
unix_socket_permission: "0770"
logtail:
  enabled: false
randomize_client_port: false
EOF

# === Start Docker containers ===
echo "Starting Docker containers..."
if ! docker compose -f headscale/docker-compose.yaml up -d; then
  echo "Docker startup failed."
  exit 1
fi

sleep 10

# === Generate API Key ===
API_KEY=$(docker exec headscale headscale apikey create)
if [ $? -ne 0 ]; then
  echo "Failed to create API Key. Exiting..."
  exit 1
fi

# === Final Output ===
echo "==========================================="
echo "✅ API Key generated: $API_KEY"
echo "🔧 Admin UI: https://$FULL_DOMAIN/admin/settings"
echo "Set:"
echo "API URL: https://$FULL_DOMAIN"
echo "API Key: $API_KEY"
echo "==========================================="
