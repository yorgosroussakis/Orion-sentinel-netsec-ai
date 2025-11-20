#!/usr/bin/env bash
# Orion Sentinel Upgrade Script
# Safely upgrades the system with backup

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              Orion Sentinel - System Upgrade                   ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check if running from repo root
if [[ ! -d "stacks/nsm" ]] || [[ ! -d "stacks/ai" ]]; then
    echo -e "${RED}Error: Please run this script from the repository root directory${NC}"
    echo "Usage: ./scripts/upgrade.sh"
    exit 1
fi

# Check if we're in a git repository
if [[ ! -d ".git" ]]; then
    echo -e "${RED}Error: Not in a git repository${NC}"
    exit 1
fi

# Step 1: Backup current state
echo -e "${YELLOW}[1/5] Creating backup of current configuration...${NC}"
if [[ -f "scripts/backup-all.sh" ]]; then
    ./scripts/backup-all.sh
    echo -e "${GREEN}✓ Backup complete${NC}"
else
    echo -e "${YELLOW}⚠ Backup script not found - continuing without backup${NC}"
    read -p "Continue without backup? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Upgrade cancelled."
        exit 0
    fi
fi

# Step 2: Check for uncommitted changes
echo ""
echo -e "${YELLOW}[2/5] Checking repository status...${NC}"
if [[ -n $(git status --porcelain) ]]; then
    echo -e "${YELLOW}⚠ You have uncommitted changes:${NC}"
    git status --short
    echo ""
    read -p "Stash changes and continue? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git stash push -m "Auto-stash before upgrade $(date +%Y%m%d-%H%M%S)"
        echo -e "${GREEN}✓ Changes stashed${NC}"
    else
        echo "Upgrade cancelled."
        exit 0
    fi
else
    echo -e "${GREEN}✓ Repository is clean${NC}"
fi

# Step 3: Pull latest changes
echo ""
echo -e "${YELLOW}[3/5] Pulling latest changes from repository...${NC}"
CURRENT_BRANCH=$(git branch --show-current)
echo "Current branch: $CURRENT_BRANCH"

if git pull origin "$CURRENT_BRANCH"; then
    echo -e "${GREEN}✓ Successfully pulled latest changes${NC}"
else
    echo -e "${RED}✗ Failed to pull changes${NC}"
    echo "Please resolve conflicts manually and retry."
    exit 1
fi

# Show what changed
echo ""
echo "Recent changes:"
git log --oneline -5
echo ""

# Step 4: Update Docker images
echo -e "${YELLOW}[4/5] Updating Docker images...${NC}"

# Update NSM stack
echo "Updating NSM stack..."
cd stacks/nsm
if docker compose pull; then
    echo -e "${GREEN}✓ NSM images updated${NC}"
else
    echo -e "${YELLOW}⚠ Could not update NSM images${NC}"
fi

# Update AI stack
echo ""
echo "Updating AI stack..."
cd ../ai
if docker compose pull; then
    echo -e "${GREEN}✓ AI images updated${NC}"
else
    echo -e "${YELLOW}⚠ Could not update AI images${NC}"
fi

cd ../..

# Step 5: Restart services
echo ""
echo -e "${YELLOW}[5/5] Restarting services with new images...${NC}"

# Restart NSM stack
echo "Restarting NSM stack..."
cd stacks/nsm
if docker compose up -d; then
    echo -e "${GREEN}✓ NSM stack restarted${NC}"
else
    echo -e "${RED}✗ Failed to restart NSM stack${NC}"
    echo "You may need to investigate and restart manually."
fi

# Restart AI stack (only if it was running)
cd ../ai
if docker compose ps | grep -q 'Up'; then
    echo ""
    echo "Restarting AI stack..."
    if docker compose up -d; then
        echo -e "${GREEN}✓ AI stack restarted${NC}"
    else
        echo -e "${YELLOW}⚠ Failed to restart AI stack${NC}"
    fi
else
    echo -e "${YELLOW}AI stack was not running - skipping restart${NC}"
fi

cd ../..

# Summary
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                     Upgrade Complete                           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${GREEN}System upgraded successfully!${NC}"
echo ""
echo "Verification steps:"
echo "1. Check service status: docker ps"
echo "2. Review logs: docker compose logs -f (in stacks/nsm or stacks/ai)"
echo "3. Access Grafana to verify dashboards"
echo ""
echo "If you experience issues, restore from backup:"
echo "  ./scripts/restore-all.sh backups/backup-<timestamp>"
echo ""
