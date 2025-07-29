#!/bin/bash

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root." 
   exit 1
fi

# Prompt the user for the full domain (including subdomain)
read -p "Enter your full domain (e.g., headscale.example.com): " FULL_DOMAIN

# Prompt for OAuth client info
read -p "Enter your OAuth2 Client ID: " OAUTH_CLIENT_ID
read -p "Enter your OAuth2 Client Secret: " OAUTH_CLIENT_SECRET
read -p "Enter your OAuth2 Provider (e.g. google, github): " OAUTH_PROVIDER
read -p "Enter the email/domain to allow (e.g. your@email.com or @yourdomain.com): " OAUTH_ALLOWED_EMAIL

# Generate a secure cookie secret
COOKIE_SECRET=$(openssl rand -hex 16)

# Create the directory structure
mkdir -p headscale/data headscale/configs/headscale headscale/letsencrypt

# Create the docker-compose.yaml file
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
      - "traefik.http.routers.headscale-admin.rule=Host(\`$FULL_DOMAIN\`) && PathPrefix(\`/admin\`)"
      - "traefik.http.routers.headscale-admin.entrypoints=websecure"
      - "traefik.http.routers.headscale-admin.tls=true"
      - "traefik.http.routers.headscale-admin.middlewares=oauth-auth"
      - "traefik.http.middlewares.oauth-auth.forwardauth.address=https://$FULL_DOMAIN/oauth2/auth"
      - "traefik.http.middlewares.oauth-auth.forwardauth.trustforwardheader=true"
      - "traefik.http.middlewares.oauth-auth.forwardauth.authresponseheaders=X-Auth-Request-User,X-Auth-Request-Email"
      - "traefik.http.services.headscale-admin.loadbalancer.server.port=80"

  oauth2-proxy:
    image: quay.io/oauth2-proxy/oauth2-proxy:latest
    container_name: oauth2-proxy
    restart: unless-stopped
    environment:
      - OAUTH2_PROXY_PROVIDER=$OAUTH_PROVIDER
      - OAUTH2_PROXY_CLIENT_ID=$OAUTH_CLIENT_ID
      - OAUTH2_PROXY_CLIENT_SECRET=$OAUTH_CLIENT_SECRET
      - OAUTH2_PROXY_COOKIE_SECRET=$COOKIE_SECRET
      - OAUTH2_PROXY_EMAIL_DOMAINS=$OAUTH_ALLOWED_EMAIL
      - OAUTH2_PROXY_HTTP_ADDRESS=0.0.0.0:4180
      - OAUTH2_PROXY_REDIRECT_URL=https://$FULL_DOMAIN/oauth2/callback
      - OAUTH2_PROXY_UPSTREAMS=static://202
      - OAUTH2_PROXY_SKIP_PROVIDER_BUTTON=true
      - OAUTH2_PROXY_SIGN_OUT_REDIRECT=https://$FULL_DOMAIN/oauth2/start
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.oauth2.rule=Host(\`$FULL_DOMAIN\`) && PathPrefix(\`/oauth2\`)"
      - "traefik.http.routers.oauth2.entrypoints=websecure"
      - "traefik.http.routers.oauth2.tls=true"
      - "traefik.http.services.oauth2.loadbalancer.server.port=4180"

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

# Create the config.yaml file
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

# Notify the user
echo "Deployment files created in 'headscale' directory."

# Start the Docker containers
if ! docker compose -f headscale/docker-compose.yaml up -d; then
    echo "Failed to start Docker containers. Exiting..."
    exit 1
fi

# Wait a few seconds for the containers to start
sleep 10

# Create the API key and capture the output
API_KEY=$(docker exec headscale headscale apikey create)
if [ $? -ne 0 ]; then
    echo "Failed to create API Key. Exiting..."
    exit 1
fi

# Display the API key and instructions to the user
echo "API Key generated: $API_KEY"
echo "Visit: https://$FULL_DOMAIN/admin (OAuth2 login required)"
echo "Use the following settings in the admin UI:"
echo "API URL: https://$FULL_DOMAIN"
echo "API Key: $API_KEY"
echo "To logout, visit: https://$FULL_DOMAIN/oauth2/sign_out"
