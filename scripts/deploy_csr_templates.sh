#!/bin/bash
# ============================================================================
# Deploy CSR Templates Schema to Production Server
# ============================================================================
#
# Dieses Skript deployed das neue CSR Templates Schema auf den FIN1-Server.
#
# Voraussetzungen:
# - SSH-Zugang zum Server (io@192.168.178.24)
# - Docker läuft auf dem Server
#
# Usage:
#   ./scripts/deploy_csr_templates.sh
#
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.env.server
[ -f "$SCRIPT_DIR/.env.server" ] && source "$SCRIPT_DIR/.env.server"

# Configuration
SERVER_USER="${FIN1_SERVER_USER:-io}"
SERVER_IP="${FIN1_SERVER_IP:-192.168.178.24}"
SCHEMA_FILE="backend/postgres/init/017_schema_csr_templates.sql"
REMOTE_DIR="/home/io/fin1-server"
CONTAINER_NAME="fin1-postgres"
DB_NAME="fin1_analytics"
DB_USER="fin1_user"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}FIN1 CSR Templates Schema Deployment${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if schema file exists
if [ ! -f "$SCHEMA_FILE" ]; then
    echo -e "${RED}Error: Schema file not found: $SCHEMA_FILE${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 1: Copying schema to server...${NC}"
scp "$SCHEMA_FILE" "${SERVER_USER}@${SERVER_IP}:${REMOTE_DIR}/backend/postgres/init/"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Schema file copied successfully${NC}"
else
    echo -e "${RED}✗ Failed to copy schema file${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Step 2: Executing schema in PostgreSQL...${NC}"

# Execute schema via docker exec
ssh "${SERVER_USER}@${SERVER_IP}" "cd ${REMOTE_DIR} && docker exec -i ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} < backend/postgres/init/017_schema_csr_templates.sql"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Schema executed successfully${NC}"
else
    echo -e "${RED}✗ Failed to execute schema${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Step 3: Verifying tables were created...${NC}"

# Verify tables exist
ssh "${SERVER_USER}@${SERVER_IP}" "docker exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -c \"SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name LIKE 'csr_%' ORDER BY table_name;\""

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Die folgenden Tabellen wurden erstellt:"
echo "  - csr_template_categories"
echo "  - csr_response_templates"
echo "  - csr_email_templates"
echo "  - csr_template_usage_stats"
echo ""
echo "Die Cloud Functions wurden bereits in templates.js implementiert."
echo "Starten Sie den Parse Server Container neu, um die Änderungen zu laden:"
echo ""
echo -e "  ${YELLOW}ssh ${SERVER_USER}@${SERVER_IP}${NC}"
echo -e "  ${YELLOW}cd ${REMOTE_DIR} && docker compose -f docker-compose.production.yml restart parse-server${NC}"
echo ""
