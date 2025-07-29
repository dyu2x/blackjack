#!/bin/bash

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root." 
   exit 1
fi

# Prompt the user for the full domain (including subdomain)
read -p "Enter your full domain (e.g., headscale.example.com): " FULL_DOMAIN

# Create required directories
mkdir -p headscale/data headscale/configs/headscale headscale/headscale-admin-ui

# Create Docker Compose file
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
      - "traefik.http.routers.headscale.rule=Host(\\\`$FULL_DOMAIN\\\`)"
      - "traefik.http.routers.headscale.tls.certresolver=myresolver"
      - "traefik.http.routers.headscale.entrypoints=websecure"
      - "traefik.http.routers.headscale.tls=true"
      - "traefik.http.services.headscale.loadbalancer.server.port=8080"

  headscale-admin:
    image: 'nginx:alpine'
    container_name: 'headscale-admin'
    restart: 'unless-stopped'
    volumes:
      - ./headscale-admin-ui:/usr/share/nginx/html:ro
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    labels:
      - "traefik.enable=true"
      - "traefik.http.services.headscale-admin.loadbalancer.server.port=80"
      - "traefik.http.routers.headscale-admin.rule=Host(\\\`$FULL_DOMAIN\\\`) && PathPrefix(\\\`/admin\\\`)"
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

# Create Headscale config.yaml
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

# Create login.html
cat <<EOF > headscale/headscale-admin-ui/login.html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Headscale Admin Login</title>
  <style>
    body {
      background: #1e1e2f;
      font-family: sans-serif;
      display: flex;
      align-items: center;
      justify-content: center;
      height: 100vh;
      color: white;
    }
    .login-box {
      background: #2a2a3d;
      padding: 2rem;
      border-radius: 10px;
      box-shadow: 0 0 20px rgba(0,0,0,0.5);
    }
    input {
      display: block;
      width: 100%;
      margin-top: 10px;
      padding: 10px;
      border-radius: 5px;
      border: none;
    }
    button {
      margin-top: 15px;
      padding: 10px;
      width: 100%;
      border: none;
      border-radius: 5px;
      background: #4caf50;
      color: white;
      font-weight: bold;
      cursor: pointer;
    }
  </style>
</head>
<body>
  <div class="login-box">
    <h2>Admin Login</h2>
    <input type="text" id="username" placeholder="Username" />
    <input type="password" id="password" placeholder="Password" />
    <button onclick="login()">Login</button>
  </div>

  <script>
    function login() {
      const user = document.getElementById("username").value;
      const pass = document.getElementById("password").value;
      if (user === "admin" && pass === "changeme") {
        localStorage.setItem("authenticated", "true");
        window.location.href = "/admin";
      } else {
        alert("Invalid credentials");
      }
    }
    if (localStorage.getItem("authenticated") === "true") {
      window.location.href = "/admin";
    }
  </script>
</body>
</html>
EOF

# Create nginx.conf
cat <<EOF > headscale/nginx.conf
events {}

http {
  server {
    listen 80;
    location = /admin {
      try_files /login.html =404;
    }
    location /admin/ {
      root /usr/share/nginx/html;
      index index.html;
    }
    location / {
      root /usr/share/nginx/html;
      index login.html;
    }
  }
}
EOF

# Start Docker containers
docker compose -f headscale/docker-compose.yaml up -d

# Wait for Headscale to start
sleep 10

# Create API key
API_KEY=$(docker exec headscale headscale apikey create)
if [ $? -ne 0 ]; then
    echo "Failed to create API Key. Exiting..."
    exit 1
fi

# Display setup info
echo "API Key generated: $API_KEY"
echo "Visit: https://$FULL_DOMAIN/admin"
echo "Username: admin"
echo "Password: changeme"
echo "API URL: https://$FULL_DOMAIN"
echo "API Key: $API_KEY"
