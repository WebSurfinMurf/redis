#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Redis Commander Deployment with Keycloak OAuth2 ===${NC}"

# Check if running as administrator user
if [[ $EUID -eq 0 ]]; then
   echo -e "${RED}This script should not be run as root!${NC}"
   exit 1
fi

# Load Redis environment
REDIS_ENV="$HOME/projects/secrets/redis.env"
if [ ! -f "$REDIS_ENV" ]; then
    echo -e "${RED}Redis environment file not found!${NC}"
    echo "Deploy Redis first: cd /home/administrator/projects/redis && ./deploy.sh"
    exit 1
fi

source "$REDIS_ENV"

# Check if Redis is running
if ! docker ps --format '{{.Names}}' | grep -qx "redis"; then
    echo -e "${RED}Redis is not running!${NC}"
    echo "Start Redis first: cd /home/administrator/projects/redis && ./deploy.sh"
    exit 1
fi

# Create Redis Commander environment file if it doesn't exist
REDIS_COMMANDER_ENV="$HOME/projects/secrets/redis-commander.env"
if [ ! -f "$REDIS_COMMANDER_ENV" ]; then
    echo -e "${YELLOW}Creating Redis Commander environment file...${NC}"
    
    # Generate cookie secret
    COOKIE_SECRET=$(openssl rand -base64 32 | tr -d "=+/" | head -c 32; echo "=")
    
    cat > "$REDIS_COMMANDER_ENV" << EOF
# Redis Commander with OAuth2 Proxy Configuration
# Generated: $(date +%Y-%m-%d)

# OAuth2 Proxy Configuration (UPDATE THESE!)
OAUTH2_PROXY_CLIENT_ID=redis-commander
OAUTH2_PROXY_CLIENT_SECRET=PLACEHOLDER_GET_FROM_KEYCLOAK
OAUTH2_PROXY_COOKIE_SECRET=$COOKIE_SECRET
OAUTH2_PROXY_PROVIDER=keycloak-oidc
OAUTH2_PROXY_OIDC_ISSUER_URL=https://keycloak.ai-servicers.com/realms/master
OAUTH2_PROXY_SKIP_OIDC_DISCOVERY=true
OAUTH2_PROXY_OIDC_JWKS_URL=http://keycloak:8080/realms/master/protocol/openid-connect/certs
OAUTH2_PROXY_LOGIN_URL=https://keycloak.ai-servicers.com/realms/master/protocol/openid-connect/auth
OAUTH2_PROXY_REDEEM_URL=http://keycloak:8080/realms/master/protocol/openid-connect/token
OAUTH2_PROXY_REDIRECT_URL=https://redis.ai-servicers.com/oauth2/callback
OAUTH2_PROXY_EMAIL_DOMAINS=*
OAUTH2_PROXY_COOKIE_SECURE=true
OAUTH2_PROXY_UPSTREAMS=http://redis-commander:8081/
OAUTH2_PROXY_PASS_HOST_HEADER=false
OAUTH2_PROXY_PROXY_PREFIX=/oauth2
OAUTH2_PROXY_SET_AUTHORIZATION_HEADER=true
OAUTH2_PROXY_HTTP_ADDRESS=0.0.0.0:4180
OAUTH2_PROXY_SKIP_PROVIDER_BUTTON=true
OAUTH2_PROXY_PASS_USER_HEADERS=true
OAUTH2_PROXY_SET_XAUTHREQUEST=true

# Don't request groups scope explicitly - use default scopes
OAUTH2_PROXY_SCOPE=openid email profile
# Restrict to administrators group
OAUTH2_PROXY_ALLOWED_GROUPS=/administrators

# Redis Connection for Redis Commander
REDIS_HOSTS=redis:redis:6379:0:$REDIS_PASSWORD
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=$REDIS_PASSWORD

# Redis Commander Settings
HTTP_USER=
HTTP_PASSWORD=
ADDRESS=0.0.0.0
PORT=8081
URL_PREFIX=/
TRUST_PROXY=true
NO_LOG_DATA=false
FOLDING_CHAR=":"
EOF
    echo -e "${GREEN}Created $REDIS_COMMANDER_ENV${NC}"
    echo ""
    echo -e "${RED}IMPORTANT: You must now:${NC}"
    echo "1. Create 'redis-commander' client in Keycloak"
    echo "2. Get the client secret from Keycloak"
    echo "3. Update OAUTH2_PROXY_CLIENT_SECRET in $REDIS_COMMANDER_ENV"
    echo "4. Run this script again"
    exit 1
fi

source "$REDIS_COMMANDER_ENV"

# Verify OAuth2 client secret is configured
if [ "$OAUTH2_PROXY_CLIENT_SECRET" = "PLACEHOLDER_GET_FROM_KEYCLOAK" ] || [ -z "$OAUTH2_PROXY_CLIENT_SECRET" ]; then
    echo -e "${RED}OAuth2 client secret not configured!${NC}"
    echo ""
    echo -e "${BLUE}Please:${NC}"
    echo "1. Log into Keycloak at https://keycloak.ai-servicers.com/admin/"
    echo "2. Create client 'redis-commander' (or check if it exists)"
    echo "3. Get the client secret from Credentials tab"
    echo "4. Update OAUTH2_PROXY_CLIENT_SECRET in:"
    echo "   $REDIS_COMMANDER_ENV"
    echo "5. Run this script again"
    exit 1
fi

# Stop and remove existing containers
echo -e "${YELLOW}Stopping existing Redis Commander containers...${NC}"
docker kill redis-commander redis-commander-auth-proxy 2>/dev/null || true
docker rm redis-commander redis-commander-auth-proxy 2>/dev/null || true

# Verify containers are stopped
if docker ps | grep -q "redis-commander"; then
    echo -e "${RED}Failed to stop containers. Please stop them manually.${NC}"
    exit 1
fi

# Deploy Redis Commander (internal only, no Traefik labels)
echo -e "${YELLOW}Deploying Redis Commander...${NC}"
docker run -d \
  --name redis-commander \
  --restart unless-stopped \
  --network redis-net \
  -e REDIS_HOSTS="$REDIS_HOSTS" \
  -e REDIS_HOST="$REDIS_HOST" \
  -e REDIS_PORT="$REDIS_PORT" \
  -e REDIS_PASSWORD="$REDIS_PASSWORD" \
  -e HTTP_USER="" \
  -e HTTP_PASSWORD="" \
  -e ADDRESS="$ADDRESS" \
  -e PORT="$PORT" \
  -e URL_PREFIX="$URL_PREFIX" \
  -e TRUST_PROXY="$TRUST_PROXY" \
  -e NO_LOG_DATA="$NO_LOG_DATA" \
  -e FOLDING_CHAR="$FOLDING_CHAR" \
  rediscommander/redis-commander:latest

# Ensure redis-commander is resolvable by name on the network
echo -e "${YELLOW}Configuring network alias...${NC}"
docker network disconnect redis-net redis-commander 2>/dev/null || true
docker network connect --alias redis-commander redis-net redis-commander

# Also connect to traefik-net for OAuth2 proxy
docker network connect traefik-net redis-commander 2>/dev/null || true

# Deploy OAuth2 Proxy with Traefik labels
echo -e "${YELLOW}Deploying OAuth2 Proxy for Redis Commander...${NC}"
docker run -d \
  --name redis-commander-auth-proxy \
  --restart unless-stopped \
  --network redis-net \
  --env-file "$REDIS_COMMANDER_ENV" \
  --label "traefik.enable=true" \
  --label "traefik.docker.network=traefik-net" \
  --label "traefik.http.routers.redis-commander.rule=Host(\`redis.ai-servicers.com\`)" \
  --label "traefik.http.routers.redis-commander.entrypoints=websecure" \
  --label "traefik.http.routers.redis-commander.tls=true" \
  --label "traefik.http.routers.redis-commander.tls.certresolver=letsencrypt" \
  --label "traefik.http.services.redis-commander.loadbalancer.server.port=4180" \
  quay.io/oauth2-proxy/oauth2-proxy:latest

# Connect OAuth2 proxy to traefik-net and keycloak-net
docker network connect traefik-net redis-commander-auth-proxy 2>/dev/null || true

echo -e "${YELLOW}Connecting OAuth2 proxy to keycloak-net...${NC}"
docker network create keycloak-net 2>/dev/null || echo "Network keycloak-net already exists"
docker network connect keycloak-net redis-commander-auth-proxy 2>/dev/null || true

echo -e "${YELLOW}Waiting for containers to start...${NC}"
sleep 10

# Check container status
echo -e "${YELLOW}Container status:${NC}"
docker ps | grep redis-commander | awk '{print $NF, $7, $8, $9}'

# Test internal connectivity
echo -e "${YELLOW}Testing internal connectivity...${NC}"
if docker run --rm --network redis-net alpine ping -c 1 redis-commander >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Network alias working${NC}"
else
    echo -e "${RED}✗ Network alias not working${NC}"
fi

echo ""
echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo ""
echo -e "${GREEN}Access Redis Commander at:${NC} https://redis.ai-servicers.com"
echo ""
echo -e "${YELLOW}Authentication:${NC}"
echo "  Uses Keycloak SSO (administrators group only)"
echo "  Login with your Keycloak credentials"
echo ""
echo -e "${YELLOW}Useful commands:${NC}"
echo "  Check logs:       docker logs redis-commander --tail 20"
echo "  Check auth logs:  docker logs redis-commander-auth-proxy --tail 20"
echo "  Check session:    https://redis.ai-servicers.com/oauth2/userinfo"
echo "  Restart:          docker restart redis-commander redis-commander-auth-proxy"
echo ""
echo -e "${YELLOW}Features:${NC}"
echo "  • Browse all Redis keys and values"
echo "  • View and edit data"
echo "  • Execute Redis commands"
echo "  • Monitor performance"
echo "  • Manage pub/sub channels"
echo "  • View slow log and client connections"
echo ""

# Check if group restriction is enabled
if grep -q "^OAUTH2_PROXY_ALLOWED_GROUPS=" "$REDIS_COMMANDER_ENV"; then
    echo -e "${GREEN}Group restriction: ENABLED (administrators only)${NC}"
else
    echo -e "${YELLOW}Group restriction: DISABLED (all authenticated users)${NC}"
    echo "To enable: Set OAUTH2_PROXY_ALLOWED_GROUPS in redis-commander.env"
fi