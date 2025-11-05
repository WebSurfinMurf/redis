# Redis Central Instance

## Project Overview
Central Redis instance shared by multiple services for caching, session management, and real-time data operations.

## Current Status
- **Status**: ✅ RUNNING
- **Container**: redis
- **Version**: 7-alpine
- **Port**: 6379
- **Network**: redis-net
- **Created**: 2025-08-24
- **Last Updated**: 2025-08-25

## Architecture
```
Central Redis (port 6379)
    ├── ShellHub (caching/sessions)
    ├── [Future Service 1]
    └── [Future Service 2]
    
Redis Commander (Web UI)
    └── OAuth2 Proxy → Keycloak SSO
```

## Access Methods
- **Direct Connection**: redis:6379 (from Docker containers)
- **Host Connection**: localhost:6379 (from host machine)
- **Web UI**: https://redis.ai-servicers.com (Redis Commander with Keycloak SSO)

## Files & Paths
- **Deploy Script**: `/home/administrator/projects/redis/deploy.sh`
- **Secrets**: `$HOME/projects/secrets/redis.env`
- **Config**: `/home/administrator/projects/redis/config/redis.conf`
- **Data Volume**: `redis_data` (Docker volume)
- **ACL Script**: `/home/administrator/projects/redis/add-service-acl.sh`

## Credentials
- **Main Password**: [see secrets/redis.env]
- **Connection**: `redis://:password@redis:6379`

## Configuration
- **Max Memory**: 256MB
- **Eviction Policy**: allkeys-lru
- **Persistence**: RDB snapshots
- **Protected Mode**: Enabled
- **Authentication**: Required

## Service Integration

### For Services WITHOUT ACL Support (like ShellHub)
Use the main Redis password from secrets/redis.env:
```bash
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=<from secrets/redis.env>
```

### For Services WITH ACL Support (Redis 6.0+)
Create dedicated user:
```bash
cd /home/administrator/projects/redis
./add-service-acl.sh <service_name> <password>
```

## Web Interface (Redis Commander)

### Deployment Options
1. **With Keycloak SSO** (Production):
   ```bash
   cd /home/administrator/projects/redis
   ./deploy-redis-commander.sh
   ```

2. **With Basic Auth** (Testing):
   ```bash
   cd /home/administrator/projects/redis
   ./deploy-redis-commander-simple.sh
   ```

### Access
- **URL**: https://redis.ai-servicers.com
- **Authentication**: Keycloak SSO (administrators group)
- **Features**:
  - Browse all keys and values
  - View and edit data
  - Execute Redis commands
  - Monitor performance
  - Manage pub/sub channels
  - View slow log and connections

### Keycloak Configuration (Completed)
- **Client ID**: redis-commander
- **Client Secret**: QaFSciyYWQY5SepiEPA8PTiJHGEsPnU7 (in `$HOME/projects/secrets/redis-commander.env`)
- **Groups Scope**: Created and configured in Keycloak
- **Group Mapper**: Added to client for administrators group
- **Redirect URI**: https://redis.ai-servicers.com/oauth2/callback
- **Status**: ✅ Working with SSO

## Network Configuration
- **Primary Network**: redis-net
- **Connected Networks**: 
  - traefik-net (for web UI)
  - mongodb-net (for service integration)

## Common Commands
```bash
# Check status
docker ps | grep redis

# View logs
docker logs redis --tail 50

# Connect via CLI
docker exec -it redis redis-cli -a [password]

# Monitor in real-time
docker exec -it redis redis-cli -a [password] monitor

# Get info
docker exec redis redis-cli -a [password] INFO

# Create ACL user (optional)
cd /home/administrator/projects/redis
./add-service-acl.sh service_name password

# Deploy web UI
./deploy-redis-commander.sh
```

## Performance Tuning
- **Memory Limit**: 256MB (adjustable in redis.env)
- **Eviction Policy**: LRU for all keys
- **TCP Keepalive**: 300 seconds
- **TCP Backlog**: 511 connections

## Backup Considerations
- **Data Volume**: `redis_data`
- **Config File**: `/home/administrator/projects/redis/config/redis.conf`
- **Backup Command**:
  ```bash
  docker exec redis redis-cli -a [password] BGSAVE
  # Saves to /data/dump.rdb in container
  ```

## Troubleshooting

### Container won't start
- Check logs: `docker logs redis`
- Verify config syntax: `docker run --rm -v /path/to/redis.conf:/test.conf redis:7-alpine redis-server /test.conf --test-memory`

### Authentication failures
- Verify password in secrets/redis.env
- Check if password has special characters (may need escaping)
- Test: `docker exec redis redis-cli -a [password] ping`

### Memory issues
- Check current usage: `docker exec redis redis-cli -a [password] INFO memory`
- Adjust maxmemory in redis.conf if needed
- Monitor evictions: `docker exec redis redis-cli -a [password] INFO stats | grep evicted`

### Web UI issues
- Check OAuth2 proxy logs: `docker logs redis-commander-auth-proxy`
- Verify Keycloak client configuration
- Test with OAuth debug tool: https://nginx.ai-servicers.com/oauth-debug.html
- Ensure Redis Commander can reach Redis on network
- Check if groups scope exists in Keycloak

## Integration Notes
- Services can use redis-net or mongodb-net (Redis is on both)
- Use main password for simple services
- Create ACL users for services that support it
- Web UI restricted to administrators group via Keycloak

## Recent Changes (2025-08-25)
- Deployed Redis Commander web UI with Keycloak SSO
- Created both SSO and basic auth deployment options
- Configured OAuth2 proxy with administrators group restriction
- Successfully integrated with central authentication

---
*Created: 2025-08-24 by Claude*
*Last Updated: 2025-08-25 - Added web UI with Keycloak SSO*
*Central Redis instance for caching and real-time operations*