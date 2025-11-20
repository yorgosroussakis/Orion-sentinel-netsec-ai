#!/usr/bin/env bash
# Orion Sentinel Security Pi Installation Script
# Run from repository root: ./scripts/install.sh

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║         Orion Sentinel Security Pi - Installation             ║"
echo "║              Network Security Monitoring & AI                  ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check if running from repo root
if [[ ! -d "stacks/nsm" ]] || [[ ! -d "stacks/ai" ]]; then
    echo -e "${RED}Error: Please run this script from the repository root directory${NC}"
    echo "Usage: ./scripts/install.sh"
    exit 1
fi

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Step 1: Check Docker installation
echo -e "${YELLOW}[1/6] Checking Docker installation...${NC}"
if command_exists docker; then
    DOCKER_VERSION=$(docker --version)
    echo -e "${GREEN}✓ Docker is installed: $DOCKER_VERSION${NC}"
else
    echo -e "${YELLOW}Docker is not installed.${NC}"
    read -p "Would you like to install Docker now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Installing Docker..."
        curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
        sudo sh /tmp/get-docker.sh
        sudo usermod -aG docker $USER
        echo -e "${GREEN}✓ Docker installed successfully${NC}"
        echo -e "${YELLOW}Note: You may need to log out and log back in for group changes to take effect${NC}"
    else
        echo -e "${RED}Docker is required. Exiting.${NC}"
        exit 1
    fi
fi

# Check Docker Compose
echo -e "${YELLOW}Checking Docker Compose plugin...${NC}"
if docker compose version >/dev/null 2>&1; then
    COMPOSE_VERSION=$(docker compose version)
    echo -e "${GREEN}✓ Docker Compose is available: $COMPOSE_VERSION${NC}"
else
    echo -e "${RED}Error: Docker Compose plugin not found${NC}"
    echo "Please install Docker Compose: https://docs.docker.com/compose/install/"
    exit 1
fi

# Step 2: Prepare .env files
echo ""
echo -e "${YELLOW}[2/6] Preparing environment configuration...${NC}"

# NSM stack .env
if [[ -f "stacks/nsm/.env" ]]; then
    echo -e "${GREEN}✓ stacks/nsm/.env already exists${NC}"
else
    if [[ -f "stacks/nsm/.env.example" ]]; then
        cp stacks/nsm/.env.example stacks/nsm/.env
        echo -e "${GREEN}✓ Created stacks/nsm/.env from example${NC}"
    else
        echo -e "${YELLOW}Warning: stacks/nsm/.env.example not found${NC}"
    fi
fi

# AI stack .env
if [[ -f "stacks/ai/.env" ]]; then
    echo -e "${GREEN}✓ stacks/ai/.env already exists${NC}"
else
    if [[ -f "stacks/ai/.env.example" ]]; then
        cp stacks/ai/.env.example stacks/ai/.env
        echo -e "${GREEN}✓ Created stacks/ai/.env from example${NC}"
    else
        echo -e "${YELLOW}Warning: stacks/ai/.env.example not found${NC}"
    fi
fi

# Step 3: Interactive configuration
echo ""
echo -e "${YELLOW}[3/6] Configuration setup${NC}"

# Get NSM interface
read -p "Enter network interface for monitoring (default: eth0): " NSM_IFACE
NSM_IFACE=${NSM_IFACE:-eth0}
echo -e "Using interface: ${GREEN}$NSM_IFACE${NC}"

# Get Loki retention
read -p "Loki log retention in days (default: 7): " LOKI_RETENTION
LOKI_RETENTION=${LOKI_RETENTION:-7}
echo -e "Log retention: ${GREEN}$LOKI_RETENTION days${NC}"

# Get Grafana password
read -sp "Set Grafana admin password (press Enter for default 'admin'): " GRAFANA_PASSWORD
echo
GRAFANA_PASSWORD=${GRAFANA_PASSWORD:-admin}
if [[ "$GRAFANA_PASSWORD" == "admin" ]]; then
    echo -e "${YELLOW}⚠ Using default password 'admin' - please change after first login!${NC}"
else
    echo -e "${GREEN}✓ Custom Grafana password set${NC}"
fi

# Enable AI stack
read -p "Enable AI stack immediately? (y/n, default: n): " -n 1 -r ENABLE_AI
echo
ENABLE_AI=${ENABLE_AI:-n}

# Step 4: Write configuration values
echo ""
echo -e "${YELLOW}[4/6] Writing configuration...${NC}"

# Update NSM .env
if [[ -f "stacks/nsm/.env" ]]; then
    # Update or append values
    if grep -q "^NSM_IFACE=" stacks/nsm/.env; then
        sed -i "s|^NSM_IFACE=.*|NSM_IFACE=$NSM_IFACE|" stacks/nsm/.env
    else
        echo "NSM_IFACE=$NSM_IFACE" >> stacks/nsm/.env
    fi
    
    if grep -q "^LOKI_RETENTION_DAYS=" stacks/nsm/.env; then
        sed -i "s|^LOKI_RETENTION_DAYS=.*|LOKI_RETENTION_DAYS=$LOKI_RETENTION|" stacks/nsm/.env
    else
        echo "LOKI_RETENTION_DAYS=$LOKI_RETENTION" >> stacks/nsm/.env
    fi
    
    if grep -q "^GRAFANA_ADMIN_PASSWORD=" stacks/nsm/.env; then
        sed -i "s|^GRAFANA_ADMIN_PASSWORD=.*|GRAFANA_ADMIN_PASSWORD=$GRAFANA_PASSWORD|" stacks/nsm/.env
    else
        echo "GRAFANA_ADMIN_PASSWORD=$GRAFANA_PASSWORD" >> stacks/nsm/.env
    fi
    
    echo -e "${GREEN}✓ NSM configuration updated${NC}"
fi

# Step 5: Start services
echo ""
echo -e "${YELLOW}[5/6] Starting services...${NC}"

# Start NSM stack
echo "Starting NSM stack (Suricata, Loki, Promtail, Grafana)..."
cd stacks/nsm
if docker compose up -d; then
    echo -e "${GREEN}✓ NSM stack started successfully${NC}"
else
    echo -e "${RED}✗ Failed to start NSM stack${NC}"
    exit 1
fi
cd ../..

# Start AI stack if requested
if [[ $ENABLE_AI =~ ^[Yy]$ ]]; then
    echo "Starting AI stack..."
    cd stacks/ai
    if docker compose up -d; then
        echo -e "${GREEN}✓ AI stack started successfully${NC}"
    else
        echo -e "${YELLOW}⚠ AI stack failed to start (you can start it later)${NC}"
    fi
    cd ../..
else
    echo -e "${YELLOW}AI stack not started (you can start it later with: cd stacks/ai && docker compose up -d)${NC}"
fi

# Step 6: Display summary
echo ""
echo -e "${YELLOW}[6/6] Installation complete!${NC}"
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                     Access Information                         ║"
echo "╚════════════════════════════════════════════════════════════════╝"

# Get local IP
LOCAL_IP=$(hostname -I | awk '{print $1}')
if [[ -z "$LOCAL_IP" ]]; then
    LOCAL_IP="<Pi2-IP>"
fi

echo ""
echo -e "${GREEN}Grafana Dashboard:${NC}   http://$LOCAL_IP:3000"
echo "  Username: admin"
echo "  Password: $GRAFANA_PASSWORD"
echo ""
echo -e "${GREEN}Loki API:${NC}            http://$LOCAL_IP:3100"
echo ""
if [[ $ENABLE_AI =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}AI API (optional):${NC}   http://$LOCAL_IP:8080"
    echo ""
fi

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                        Next Steps                              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "1. Access Grafana and explore the dashboards"
echo "2. Configure DNS log shipping from Pi #1 (DNS Pi)"
echo "   See: docs/integration-orion-dns-ha.md"
echo "3. Review configuration in stacks/nsm/.env and stacks/ai/.env"
if [[ "$GRAFANA_PASSWORD" == "admin" ]]; then
    echo "4. ${YELLOW}IMPORTANT: Change Grafana admin password!${NC}"
fi
echo ""
echo "For operations (backup, restore, upgrade), see: docs/operations.md"
echo ""
echo -e "${GREEN}Installation successful! Orion Sentinel is running.${NC}"
