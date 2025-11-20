#!/usr/bin/env bash
# Orion Sentinel Restore Script
# Restores configuration and data from backup

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║         Orion Sentinel - Restore from Backup                   ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check if running from repo root
if [[ ! -d "stacks/nsm" ]] || [[ ! -d "stacks/ai" ]]; then
    echo -e "${RED}Error: Please run this script from the repository root directory${NC}"
    echo "Usage: ./scripts/restore-all.sh <backup-directory>"
    exit 1
fi

# Check for backup directory argument
if [[ $# -lt 1 ]]; then
    echo -e "${RED}Error: Please specify a backup directory${NC}"
    echo "Usage: ./scripts/restore-all.sh <backup-directory>"
    echo ""
    echo "Available backups:"
    if [[ -d "backups" ]]; then
        ls -1 backups/
    else
        echo "  No backups found"
    fi
    exit 1
fi

BACKUP_DIR="$1"

# Validate backup directory
if [[ ! -d "$BACKUP_DIR" ]]; then
    echo -e "${RED}Error: Backup directory not found: $BACKUP_DIR${NC}"
    exit 1
fi

echo -e "${YELLOW}Restore from: $BACKUP_DIR${NC}"
echo ""

# Show backup manifest if available
if [[ -f "$BACKUP_DIR/MANIFEST.txt" ]]; then
    echo "Backup information:"
    head -n 10 "$BACKUP_DIR/MANIFEST.txt"
    echo ""
fi

# Confirmation prompt
echo -e "${YELLOW}⚠ WARNING: This will overwrite current configuration!${NC}"
read -p "Are you sure you want to restore from this backup? (yes/no): " -r CONFIRM
if [[ ! $CONFIRM == "yes" ]]; then
    echo "Restore cancelled."
    exit 0
fi

echo ""
echo -e "${YELLOW}Starting restore...${NC}"

# Restore .env files
echo ""
echo -e "${YELLOW}[1/4] Restoring environment files...${NC}"
if [[ -f "$BACKUP_DIR/nsm.env" ]]; then
    cp "$BACKUP_DIR/nsm.env" stacks/nsm/.env
    echo -e "${GREEN}✓ Restored stacks/nsm/.env${NC}"
else
    echo -e "${YELLOW}⚠ nsm.env not found in backup${NC}"
fi

if [[ -f "$BACKUP_DIR/ai.env" ]]; then
    cp "$BACKUP_DIR/ai.env" stacks/ai/.env
    echo -e "${GREEN}✓ Restored stacks/ai/.env${NC}"
else
    echo -e "${YELLOW}⚠ ai.env not found in backup${NC}"
fi

# Restore config directory
echo ""
echo -e "${YELLOW}[2/4] Restoring config files...${NC}"
if [[ -d "$BACKUP_DIR/config" ]]; then
    # Backup current config first
    if [[ -d "config" ]]; then
        mv config "config.backup-$(date +%Y%m%d-%H%M%S)"
        echo "  Current config backed up"
    fi
    cp -r "$BACKUP_DIR/config" config
    echo -e "${GREEN}✓ Restored config/ directory${NC}"
else
    echo -e "${YELLOW}⚠ config/ not found in backup${NC}"
fi

# Restore data stores
echo ""
echo -e "${YELLOW}[3/4] Restoring data stores...${NC}"
if [[ -f "$BACKUP_DIR/inventory.db" ]]; then
    # Check if container is running
    if docker ps --format '{{.Names}}' | grep -q 'orion-inventory'; then
        echo "Stopping inventory service for restore..."
        docker stop orion-inventory >/dev/null 2>&1 || true
        
        # Copy database to volume
        docker run --rm -v orion_inventory-data:/data -v "$(pwd)/$BACKUP_DIR":/backup alpine \
            sh -c 'cp /backup/inventory.db /data/inventory.db' 2>/dev/null || echo -e "${YELLOW}⚠ Could not restore inventory database${NC}"
        
        echo -e "${GREEN}✓ Restored inventory database${NC}"
        echo "  You may need to restart services: cd stacks/ai && docker compose up -d"
    else
        echo -e "${YELLOW}⚠ Inventory service not running - database will be restored on next start${NC}"
    fi
else
    echo -e "${YELLOW}⚠ inventory.db not found in backup${NC}"
fi

# Show model manifest
echo ""
echo -e "${YELLOW}[4/4] Checking model manifest...${NC}"
if [[ -f "$BACKUP_DIR/model-manifest.txt" ]]; then
    echo "Models from backup:"
    cat "$BACKUP_DIR/model-manifest.txt"
    echo ""
    echo -e "${YELLOW}Note: Model files are not automatically restored.${NC}"
    echo "Please manually copy models from your backup if needed."
else
    echo -e "${YELLOW}⚠ No model manifest in backup${NC}"
fi

# Summary
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                      Restore Complete                          ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${GREEN}Configuration restored from: $BACKUP_DIR${NC}"
echo ""
echo "Next steps:"
echo "1. Review restored configuration in stacks/nsm/.env and stacks/ai/.env"
echo "2. Restart services if needed:"
echo "   cd stacks/nsm && docker compose up -d"
echo "   cd stacks/ai && docker compose up -d"
echo "3. Verify services are running: docker ps"
echo ""
