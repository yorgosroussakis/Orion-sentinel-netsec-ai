#!/usr/bin/env bash
# Orion Sentinel NetSec Node - Bootstrap Script
# Prepares a Raspberry Pi 5 for running the NetSec security monitoring stack
#
# This script:
#   - Checks for Docker and Docker Compose
#   - Validates network interface configuration
#   - Sets kernel parameters if needed
#   - Creates .env file from template
#   - Guides user through initial configuration

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Print colored messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_header() {
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  $1${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check Docker installation
check_docker() {
    print_header "Checking Docker Installation"
    
    if ! command_exists docker; then
        print_error "Docker is not installed"
        echo ""
        echo "To install Docker on Raspberry Pi OS:"
        echo "  curl -fsSL https://get.docker.com -o get-docker.sh"
        echo "  sudo sh get-docker.sh"
        echo "  sudo usermod -aG docker \$USER"
        echo "  newgrp docker"
        echo ""
        return 1
    fi
    
    # Check Docker version
    docker_version=$(docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    print_success "Docker installed: v${docker_version}"
    
    # Check if user can run docker without sudo
    if ! docker ps >/dev/null 2>&1; then
        print_warning "Current user cannot run Docker commands"
        echo "  Run: sudo usermod -aG docker \$USER && newgrp docker"
        return 1
    fi
    
    print_success "Docker is accessible"
    return 0
}

# Check Docker Compose installation
check_docker_compose() {
    print_header "Checking Docker Compose Installation"
    
    if ! docker compose version >/dev/null 2>&1; then
        print_error "Docker Compose plugin is not installed"
        echo ""
        echo "To install Docker Compose plugin:"
        echo "  sudo apt-get update"
        echo "  sudo apt-get install docker-compose-plugin"
        echo ""
        return 1
    fi
    
    compose_version=$(docker compose version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "installed")
    print_success "Docker Compose installed: v${compose_version}"
    return 0
}

# List available network interfaces
list_interfaces() {
    print_header "Available Network Interfaces"
    
    echo "Interface    Status    IP Address"
    echo "─────────────────────────────────────────────"
    ip -br addr show | while read -r iface state addr; do
        printf "%-12s %-8s %s\n" "$iface" "$state" "$addr"
    done
    echo ""
}

# Validate network interface exists
validate_interface() {
    local iface=$1
    
    if ! ip link show "$iface" >/dev/null 2>&1; then
        print_error "Interface '$iface' does not exist"
        return 1
    fi
    
    # Check if interface is UP
    if ! ip link show "$iface" | grep -q "state UP"; then
        print_warning "Interface '$iface' is DOWN"
        read -p "Do you want to bring it UP? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo ip link set "$iface" up
            print_success "Interface '$iface' is now UP"
        else
            print_warning "Interface is still DOWN - may not capture traffic"
        fi
    else
        print_success "Interface '$iface' is UP"
    fi
    
    return 0
}

# Check and configure kernel parameters
check_kernel_params() {
    print_header "Checking Kernel Parameters"
    
    local need_reboot=0
    
    # Check if we need to increase receive buffer sizes for high traffic
    local rmem_max
    rmem_max=$(sysctl -n net.core.rmem_max 2>/dev/null)
    
    # Validate rmem_max is a number
    if [[ ! "$rmem_max" =~ ^[0-9]+$ ]]; then
        print_warning "Could not read net.core.rmem_max, skipping kernel parameter check"
        return 0
    fi
    
    if [ "$rmem_max" -lt 16777216 ]; then
        print_info "Increasing network receive buffer size"
        echo "net.core.rmem_max = 16777216" | sudo tee -a /etc/sysctl.conf >/dev/null
        echo "net.core.rmem_default = 16777216" | sudo tee -a /etc/sysctl.conf >/dev/null
        need_reboot=1
    else
        print_success "Network receive buffer size is adequate"
    fi
    
    # Apply sysctl changes
    if [ $need_reboot -eq 1 ]; then
        sudo sysctl -p >/dev/null 2>&1
        print_success "Kernel parameters updated"
    fi
}

# Create .env file from template
create_env_file() {
    print_header "Configuring Environment"
    
    cd "$PROJECT_ROOT"
    
    if [ -f .env ]; then
        print_warning ".env file already exists"
        read -p "Do you want to recreate it? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Keeping existing .env file"
            return 0
        fi
        # Backup existing .env
        cp .env .env.backup.$(date +%Y%m%d-%H%M%S)
        print_info "Backed up existing .env file"
    fi
    
    # Copy template
    if [ ! -f .env.example ]; then
        print_error ".env.example template not found"
        return 1
    fi
    
    cp .env.example .env
    print_success "Created .env from template"
    
    # Interactive configuration
    echo ""
    echo "Let's configure the key settings..."
    echo ""
    
    # Network interface
    list_interfaces
    read -p "Enter the network interface to monitor (e.g., eth0, eth1): " monitor_if
    if [ -n "$monitor_if" ]; then
        if validate_interface "$monitor_if"; then
            # Update MONITOR_IF in .env
            if grep -q "^MONITOR_IF=" .env; then
                sed -i "s/^MONITOR_IF=.*/MONITOR_IF=$monitor_if/" .env
            else
                echo "MONITOR_IF=$monitor_if" >> .env
            fi
            print_success "Set MONITOR_IF=$monitor_if"
        fi
    fi
    
    echo ""
    read -p "Enter CoreSrv Loki URL (e.g., http://192.168.8.50:3100) or press Enter to skip: " loki_url
    if [ -n "$loki_url" ]; then
        sed -i "s|^LOKI_URL=.*|LOKI_URL=$loki_url|" .env
        print_success "Set LOKI_URL=$loki_url"
    fi
    
    echo ""
    read -p "Enter a name for this node (e.g., netsec-pi-01) or press Enter to skip: " node_name
    if [ -n "$node_name" ]; then
        if grep -q "^NODE_NAME=" .env; then
            sed -i "s/^NODE_NAME=.*/NODE_NAME=$node_name/" .env
        else
            echo "NODE_NAME=$node_name" >> .env
        fi
        print_success "Set NODE_NAME=$node_name"
    fi
    
    # Set proper permissions
    chmod 600 .env
    print_success ".env file created with secure permissions (0600)"
    
    echo ""
    print_info "You can edit .env later to configure additional settings:"
    echo "  - Pi-hole integration (PIHOLE_URL, PIHOLE_API_KEY)"
    echo "  - Email notifications (NOTIFY_SMTP_*)"
    echo "  - Threat intelligence (TI_ENABLE_*, TI_OTX_API_KEY)"
    echo ""
}

# Verify Docker images can be pulled
test_docker_pull() {
    print_header "Testing Docker Registry Access"
    
    # Test pull a small image
    if docker pull hello-world:latest >/dev/null 2>&1; then
        print_success "Docker registry is accessible"
        docker rmi hello-world:latest >/dev/null 2>&1
        return 0
    else
        print_warning "Cannot pull from Docker registry - check internet connection"
        return 1
    fi
}

# Display next steps
show_next_steps() {
    print_header "Bootstrap Complete!"
    
    echo "Your Orion Sentinel NetSec node is ready to deploy."
    echo ""
    echo "Next steps:"
    echo ""
    echo "  1. Review and edit .env file if needed:"
    echo "     ${GREEN}nano .env${NC}"
    echo ""
    echo "  2. Start the NetSec core services:"
    echo "     ${GREEN}make up-core${NC}"
    echo "     or: ${GREEN}docker compose --profile netsec-core up -d${NC}"
    echo ""
    echo "  3. Start the full stack (core + AI):"
    echo "     ${GREEN}make up-all${NC}"
    echo "     or: ${GREEN}docker compose --profile netsec-core --profile ai up -d${NC}"
    echo ""
    echo "  4. Verify Suricata is capturing traffic:"
    echo "     ${GREEN}make test${NC}"
    echo "     or: ${GREEN}docker logs orion-suricata | grep 'Capture'${NC}"
    echo ""
    echo "  5. Check log shipping to Loki:"
    echo "     ${GREEN}docker logs orion-promtail | grep 'POST'${NC}"
    echo ""
    echo "For more information:"
    echo "  - Full documentation: ${GREEN}cat README.md${NC}"
    echo "  - Architecture plan: ${GREEN}cat PLAN.md${NC}"
    echo "  - Quick start guide: ${GREEN}cat QUICKSTART.md${NC}"
    echo ""
    print_success "Ready to deploy!"
}

# Main execution
main() {
    print_header "Orion Sentinel NetSec Node - Bootstrap"
    
    echo "This script will prepare your system for running the NetSec stack."
    echo "It will check prerequisites and guide you through initial configuration."
    echo ""
    
    # Check prerequisites
    local failed=0
    
    if ! check_docker; then
        failed=1
    fi
    
    if ! check_docker_compose; then
        failed=1
    fi
    
    if [ $failed -eq 1 ]; then
        echo ""
        print_error "Prerequisites check failed. Please install missing components and re-run this script."
        exit 1
    fi
    
    # System configuration
    check_kernel_params
    
    # Test Docker registry
    test_docker_pull || true
    
    # Create environment configuration
    create_env_file
    
    # Show next steps
    show_next_steps
}

# Run main function
main "$@"
