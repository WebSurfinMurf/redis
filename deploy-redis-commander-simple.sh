#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Redis Commander Simple Deployment with Basic Auth ===${NC}"

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

# Load Redis Commander Simple environment
REDIS_COMMANDER_SIMPLE_ENV="$HOME/projects/secrets/redis-commander-simple.env"
if [ ! -f "$REDIS_COMMANDER_SIMPLE_ENV" ]; then
    echo -e "${YELLOW}Creating Redis Commander Simple environment file...${NC}"
    cat > "$REDIS_COMMANDER_SIMPLE_ENV" << 'EOF'
# Redis Commander Simple Deployment (Basic Auth)
# Generated: $(date +%Y-%m-%d)

# Basic Authentication Credentials
HTTP_USER=admin
HTTP_PASSWORD=RedisCommander2025!

# Redis connection (loaded from redis.env)
# REDIS_HOST, REDIS_PORT, REDIS_PASSWORD are loaded from redis.env
EOF
    echo -e "${GREEN}Created $REDIS_COMMANDER_SIMPLE_ENV${NC}"
fi

source "$REDIS_COMMANDER_SIMPLE_ENV"

# Check if Redis is running
if ! docker ps --format '{{.Names}}' | grep -qx "redis"; then
    echo -e "${RED}Redis is not running!${NC}"
    echo "Start Redis first: cd /home/administrator/projects/redis && ./deploy.sh"
    exit 1
fi

# Stop and remove existing containers
echo -e "${YELLOW}Stopping existing Redis Commander containers...${NC}"
docker kill redis-commander redis-commander-auth-proxy 2>/dev/null || true
docker rm redis-commander redis-commander-auth-proxy 2>/dev/null || true

# Deploy Redis Commander with basic auth
echo -e "${YELLOW}Deploying Redis Commander with basic authentication...${NC}"
docker run -d \
  --name redis-commander \
  --restart unless-stopped \
  --network redis-net \
  -e REDIS_HOSTS="redis:redis:6379:0:$REDIS_PASSWORD" \
  -e HTTP_USER="$HTTP_USER" \
  -e HTTP_PASSWORD="$HTTP_PASSWORD" \
  -e ADDRESS=0.0.0.0 \
  -e PORT=8081 \
  -e URL_PREFIX=/ \
  -e TRUST_PROXY=true \
  --label "traefik.enable=true" \
  --label "traefik.docker.network=traefik-net" \
  --label "traefik.http.routers.redis-commander.rule=Host(\`redis.ai-servicers.com\`)" \
  --label "traefik.http.routers.redis-commander.entrypoints=websecure" \
  --label "traefik.http.routers.redis-commander.tls=true" \
  --label "traefik.http.routers.redis-commander.tls.certresolver=letsencrypt" \
  --label "traefik.http.services.redis-commander.loadbalancer.server.port=8081" \
  rediscommander/redis-commander:latest

# Connect to traefik-net network for web access
echo -e "${YELLOW}Connecting to traefik-net network...${NC}"
docker network connect traefik-net redis-commander 2>/dev/null || echo "Already connected"

# Also connect to mongodb-net for cross-service access
docker network connect mongodb-net redis-commander 2>/dev/null || echo "Already connected"

echo -e "${YELLOW}Waiting for container to start...${NC}"
sleep 10

# Check container status
if docker ps | grep -q redis-commander; then
    echo ""
    echo -e "${GREEN}=== Deployment Complete ===${NC}"
    echo ""
    echo -e "${GREEN}Access Redis Commander at:${NC} https://redis.ai-servicers.com"
    echo ""
    echo -e "${GREEN}Credentials:${NC}"
    echo "  Username: $HTTP_USER"
    echo "  Password: [see $REDIS_COMMANDER_SIMPLE_ENV]"
    echo ""
    echo -e "${YELLOW}Useful commands:${NC}"
    echo "  Check logs: docker logs redis-commander --tail 20"
    echo "  Restart:    docker restart redis-commander"
    echo ""
    echo -e "${YELLOW}Security Note:${NC}"
    echo "  Using basic authentication for simplicity"
    echo "  Consider upgrading to Keycloak SSO later"
else
    echo -e "${RED}Failed to start Redis Commander${NC}"
    echo "Check logs: docker logs redis-commander"
    exit 1
fi