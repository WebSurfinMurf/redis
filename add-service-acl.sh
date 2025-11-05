#!/bin/bash
# Usage: ./add-service-acl.sh <service_name> <password>
# Note: Redis ACL requires Redis 6.0+

if [ $# -ne 2 ]; then
    echo "Usage: $0 <service_name> <password>"
    echo "Example: $0 shellhub MyServicePass123"
    exit 1
fi

SERVICE_NAME=$1
SERVICE_PASSWORD=$2

source $HOME/projects/secrets/redis.env

echo "Creating Redis ACL user for '$SERVICE_NAME'..."

# Create ACL user with specific permissions
docker exec redis redis-cli -a "$REDIS_PASSWORD" ACL SETUSER "$SERVICE_NAME" \
  on ">$SERVICE_PASSWORD" \
  "~*" "&*" "+@all" \
  2>/dev/null

if [ $? -eq 0 ]; then
    echo ""
    echo "Redis user created successfully!"
    echo ""
    echo "Connection details for $SERVICE_NAME:"
    echo "  Host: redis"
    echo "  Port: 6379"
    echo "  Username: $SERVICE_NAME"
    echo "  Password: $SERVICE_PASSWORD"
    echo ""
    echo "Connection string:"
    echo "  redis://$SERVICE_NAME:$SERVICE_PASSWORD@redis:6379"
else
    echo "Failed to create user. Using default authentication."
    echo ""
    echo "Connection details for $SERVICE_NAME:"
    echo "  Host: redis"
    echo "  Port: 6379"
    echo "  Password: $REDIS_PASSWORD"
    echo ""
    echo "Connection string:"
    echo "  redis://:$REDIS_PASSWORD@redis:6379"
fi
