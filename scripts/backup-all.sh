#!/usr/bin/env bash
# Orion Sentinel Backup Script
# Backs up configuration, data, and model information

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║         Orion Sentinel - Backup All Configuration             ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check if running from repo root
if [[ ! -d "stacks/nsm" ]] || [[ ! -d "stacks/ai" ]]; then
    echo -e "${RED}Error: Please run this script from the repository root directory${NC}"
    echo "Usage: ./scripts/backup-all.sh"
    exit 1
fi

# Create backup directory with timestamp
BACKUP_DIR="backups/backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo -e "${YELLOW}Backup location: $BACKUP_DIR${NC}"
echo ""

# Backup .env files
echo -e "${YELLOW}[1/5] Backing up environment files...${NC}"
if [[ -f "stacks/nsm/.env" ]]; then
    cp stacks/nsm/.env "$BACKUP_DIR/nsm.env"
    echo -e "${GREEN}✓ Backed up stacks/nsm/.env${NC}"
else
    echo -e "${YELLOW}⚠ stacks/nsm/.env not found${NC}"
fi

if [[ -f "stacks/ai/.env" ]]; then
    cp stacks/ai/.env "$BACKUP_DIR/ai.env"
    echo -e "${GREEN}✓ Backed up stacks/ai/.env${NC}"
else
    echo -e "${YELLOW}⚠ stacks/ai/.env not found${NC}"
fi

# Backup config directory
echo ""
echo -e "${YELLOW}[2/5] Backing up config files...${NC}"
if [[ -d "config" ]]; then
    cp -r config "$BACKUP_DIR/config"
    echo -e "${GREEN}✓ Backed up config/ directory${NC}"
else
    echo -e "${YELLOW}⚠ config/ directory not found${NC}"
fi

# Backup Docker volume data (if accessible)
echo ""
echo -e "${YELLOW}[3/5] Backing up data stores...${NC}"

# Export inventory database if running
if docker ps --format '{{.Names}}' | grep -q 'orion-inventory'; then
    echo "Exporting inventory database..."
    docker exec orion-inventory sh -c 'if [ -f /data/inventory.db ]; then cat /data/inventory.db; fi' > "$BACKUP_DIR/inventory.db" 2>/dev/null || echo -e "${YELLOW}⚠ Could not export inventory database${NC}"
    if [[ -f "$BACKUP_DIR/inventory.db" ]] && [[ -s "$BACKUP_DIR/inventory.db" ]]; then
        echo -e "${GREEN}✓ Backed up inventory database${NC}"
    else
        rm -f "$BACKUP_DIR/inventory.db"
    fi
else
    echo -e "${YELLOW}⚠ Inventory service not running${NC}"
fi

# Backup playbooks if they exist
if [[ -f "config/playbooks.yml" ]]; then
    cp config/playbooks.yml "$BACKUP_DIR/playbooks.yml"
    echo -e "${GREEN}✓ Backed up playbooks${NC}"
fi

# Create model manifest
echo ""
echo -e "${YELLOW}[4/5] Creating AI model manifest...${NC}"
if [[ -d "stacks/ai/models" ]]; then
    find stacks/ai/models -type f -name "*.onnx" -o -name "*.tflite" > "$BACKUP_DIR/model-manifest.txt" 2>/dev/null || true
    if [[ -s "$BACKUP_DIR/model-manifest.txt" ]]; then
        echo -e "${GREEN}✓ Created model manifest${NC}"
        echo "  Models found: $(wc -l < "$BACKUP_DIR/model-manifest.txt")"
    else
        echo -e "${YELLOW}⚠ No models found${NC}"
        rm -f "$BACKUP_DIR/model-manifest.txt"
    fi
else
    echo -e "${YELLOW}⚠ Models directory not found${NC}"
fi

# Create backup manifest
echo ""
echo -e "${YELLOW}[5/5] Creating backup manifest...${NC}"
cat > "$BACKUP_DIR/MANIFEST.txt" <<EOF
Orion Sentinel Backup
Created: $(date)
Hostname: $(hostname)
User: $USER

Backup Contents:
$(find "$BACKUP_DIR" -type f -exec basename {} \; | sort)

Docker Containers at Backup Time:
$(docker ps --format "table {{.Names}}\t{{.Status}}" 2>/dev/null || echo "Docker not running")

To restore this backup:
  ./scripts/restore-all.sh $BACKUP_DIR
EOF

echo -e "${GREEN}✓ Created backup manifest${NC}"

# Summary
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                      Backup Complete                           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${GREEN}Backup saved to: $BACKUP_DIR${NC}"
echo ""
echo "Backup contents:"
ls -lh "$BACKUP_DIR"
echo ""
echo -e "${YELLOW}To restore this backup:${NC}"
echo "  ./scripts/restore-all.sh $BACKUP_DIR"
echo ""
