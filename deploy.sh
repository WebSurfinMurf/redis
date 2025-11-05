#!/bin/bash
set -e

echo "🚀 Deploying Redis Stack"
echo "==================================="
echo ""

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Environment file
ENV_FILE="$HOME/projects/secrets/redis-commander.env"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# --- Pre-deployment Checks ---
echo "🔍 Pre-deployment checks..."

# Check environment file
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}❌ Environment file not found: $ENV_FILE${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Environment file exists${NC}"

# Source environment variables
set -o allexport
source "$ENV_FILE"
set +o allexport

# Validate required variables
required_vars=("REDIS_PASSWORD" "KEYCLOAK_CLIENT_SECRET" "OAUTH2_COOKIE_SECRET")

for var in "${required_vars[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        echo -e "${RED}❌ Required variable $var is not set${NC}"
        exit 1
    fi
done
echo -e "${GREEN}✅ Environment variables validated${NC}"

# Check if networks exist
for network in redis-net traefik-net keycloak-net; do
    if ! docker network inspect "$network" &>/dev/null; then
        echo -e "${RED}❌ $network network not found${NC}"
        echo "Run: /home/administrator/projects/infrastructure/setup-networks.sh"
        exit 1
    fi
done
echo -e "${GREEN}✅ All required networks exist${NC}"

# Check/create volume
if ! docker volume inspect redis_data &>/dev/null; then
    echo "Creating redis_data volume..."
    docker volume create redis_data
fi
echo -e "${GREEN}✅ Redis data volume ready${NC}"

# Check redis.conf exists
if [ ! -f "$SCRIPT_DIR/config/redis.conf" ]; then
    echo -e "${RED}❌ redis.conf not found at $SCRIPT_DIR/config/redis.conf${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Redis configuration file exists${NC}"

# Validate docker-compose.yml syntax
echo ""
echo "✅ Validating docker-compose.yml..."
if ! docker compose config > /dev/null 2>&1; then
    echo -e "${RED}❌ docker-compose.yml validation failed${NC}"
    docker compose config
    exit 1
fi
echo -e "${GREEN}✅ docker-compose.yml is valid${NC}"

# --- Deployment ---
echo ""
echo "🚀 Deploying Redis stack..."
docker compose up -d --remove-orphans

# --- Post-deployment Validation ---
echo ""
echo "⏳ Waiting for Redis to be ready..."
timeout 30 bash -c 'until docker exec redis redis-cli --raw incr ping 2>/dev/null; do sleep 2; done' || {
    echo -e "${RED}❌ Redis failed to start${NC}"
    docker logs redis --tail 30
    exit 1
}
echo -e "${GREEN}✅ Redis is ready${NC}"

echo ""
echo "⏳ Waiting for Redis Commander to be ready..."
timeout 30 bash -c 'until docker logs redis-commander 2>&1 | grep -q "listening"; do sleep 2; done' || {
    echo -e "${RED}❌ Redis Commander failed to start${NC}"
    docker logs redis-commander --tail 30
    exit 1
}
echo -e "${GREEN}✅ Redis Commander is ready${NC}"

echo ""
echo "⏳ Waiting for OAuth2 proxy to be ready..."
sleep 5  # Give proxy time to initialize
docker run --rm --network traefik-net alpine/curl:latest curl -sI http://redis-commander-auth-proxy:4180 | grep -q "HTTP" || {
    echo -e "${RED}❌ OAuth2 proxy failed to start${NC}"
    docker logs redis-commander-auth-proxy --tail 30
    exit 1
}
echo -e "${GREEN}✅ OAuth2 proxy is ready${NC}"

# Get Redis info
echo ""
echo "📊 Redis Status:"
docker exec redis redis-cli INFO server 2>/dev/null | grep -E "redis_version|uptime_in_days" || true
docker exec redis redis-cli INFO memory 2>/dev/null | grep -E "used_memory_human|maxmemory_human" || true

# --- Summary ---
echo ""
echo "=========================================="
echo "✅ Redis Deployment Summary"
echo "=========================================="
echo "Containers:"
echo "  - redis (${REDIS_IMAGE:-redis:7-alpine})"
echo "  - redis-commander (web UI)"
echo "  - redis-commander-auth-proxy (OAuth2)"
echo ""
echo "Networks:"
echo "  - redis-net (cache access)"
echo "  - traefik-net (web routing)"
echo "  - keycloak-net (authentication)"
echo ""
echo "Volumes:"
echo "  - redis_data (RDB persistence)"
echo ""
echo "Access:"
echo "  - Web UI: https://redis.ai-servicers.com"
echo "  - Internal: redis://redis:6379"
echo "  - External: redis://localhost:6379"
echo ""
echo "=========================================="
echo ""
echo "📊 View logs:"
echo "   docker logs redis -f"
echo "   docker logs redis-commander -f"
echo ""
echo "🔍 Connect via redis-cli:"
echo "   docker exec -it redis redis-cli"
echo ""
echo "✅ Deployment complete!"
