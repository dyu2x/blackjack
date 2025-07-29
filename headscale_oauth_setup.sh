#!/bin/bash

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root."
   exit 1
fi

# Prompt for full domain
read -p "Enter your full domain (e.g., headscale.example.com): " FULL_DOMAIN

# Create directory structure
mkdir -p headscale/data headscale/configs/headscale headscale/headscale-admin-ui

# Set executable permissions for scripts and configs
chmod -R 755 headscale

# Create docker-compose.yaml
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
    volumes:
      - './headscale-admin-ui:/usr/share/nginx/html'
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

# Create sample login page
cat <<EOF > headscale/headscale-admin-ui/login.html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>Login - Headscale Admin</title>
  <style>
    body {
      font-family: sans-serif;
      background: #f0f4f8;
      display: flex;
      justify-content: center;
      align-items: center;
      height: 100vh;
    }
    .login-box {
      background: white;
      padding: 2rem;
      border-radius: 12px;
      box-shadow: 0 4px 20px rgba(0,0,0,0.1);
      width: 100%;
      max-width: 400px;
    }
    .login-box h2 {
      margin-bottom: 1rem;
    }
    input {
      width: 100%;
      padding: 0.75rem;
      margin: 0.5rem 0;
      border-radius: 8px;
      border: 1px solid #ccc;
    }
    button {
      width: 100%;
      padding: 0.75rem;
      background: #007bff;
      color: white;
      border: none;
      border-radius: 8px;
      cursor: pointer;
    }
    button:hover {
      background: #0056b3;
    }
  </style>
</head>
<body>
  <div class="login-box">
    <h2>Login</h2>
    <form>
      <input type="text" placeholder="Username" required />
      <input type="password" placeholder="Password" required />
      <button type="submit">Log In</button>
    </form>
  </div>
</body>
</html>
EOF

# Start the Docker containers
if ! docker compose -f headscale/docker-compose.yaml up -d; then
    echo "Failed to start Docker containers."
    exit 1
fi

# Generate API key
API_KEY=$(docker exec headscale headscale apikey create)
if [ $? -ne 0 ]; then
    echo "Failed to create API key."
    exit 1
fi

# Display connection info
echo "API Key: $API_KEY"
echo "Visit: https://$FULL_DOMAIN/admin"
