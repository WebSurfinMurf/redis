# Redis Central Instance

## Overview
Central Redis cache server with web management UI protected by Keycloak SSO.

## Services
- **redis**: Redis 7 cache server
- **redis-commander**: Web-based Redis management UI
- **redis-commander-auth-proxy**: OAuth2 proxy for SSO authentication

## Deployment
```bash
cd /home/administrator/projects/redis
./deploy.sh
```

## Access
- **Web UI**: https://redis.ai-servicers.com (requires Keycloak SSO)
- **Internal**: redis://redis:6379
- **External**: redis://localhost:6379

## Configuration
- **Secrets**: `$HOME/projects/secrets/redis-commander.env`
- **Config**: `/home/administrator/projects/redis/config/redis.conf`
- **Networks**: redis-net, traefik-net, keycloak-net
- **Volumes**: redis_data

## Redis Configuration
- **Max Memory**: 256MB
- **Eviction Policy**: allkeys-lru
- **Persistence**: RDB snapshots
- **Authentication**: Required (password in secrets file)

## Service Integration

### For Services Using Redis
Connection string format:
```
redis://:PASSWORD@redis:6379
```

Environment variables:
```bash
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=<from secrets/redis.env>
```

### Creating Service-Specific ACLs
For services that support Redis ACL (Redis 6.0+):
```bash
cd /home/administrator/projects/redis
./add-service-acl.sh <service_name> <password>
```

## Common Commands
```bash
# View logs
docker logs redis -f

# Connect via redis-cli
docker exec -it redis redis-cli -a <password>

# Get info
docker exec redis redis-cli INFO

# Check keyspace
docker exec redis redis-cli -a <password> INFO keyspace

# Monitor commands
docker exec redis redis-cli -a <password> MONITOR

# Check container status
docker ps | grep redis
```

## Networks
- **redis-net**: Cache access (internal only)
- **traefik-net**: Web UI routing
- **keycloak-net**: SSO authentication

## Volumes
- **redis_data**: RDB persistence files

## Security
- Password authentication required
- Web UI protected by Keycloak SSO
- Administrators group required for access
- Cache isolated on redis-net

## Health Checks
- Redis: `redis-cli --raw incr ping`
- Container includes automatic health monitoring

---
*Standardized: 2025-09-30*
*Part of Phase 2: Database Layer*
