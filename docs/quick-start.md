# Quick Start Guide

This guide helps you get Orion Sentinel up and running quickly on your Security Pi (Pi #2).

## Prerequisites

- Raspberry Pi 5 (8 GB recommended) or similar ARM64 system
- Raspberry Pi OS 64-bit (Debian Bookworm or later)
- Network connection to your LAN
- (Optional) Router/switch configured to mirror traffic to this Pi
- (Recommended) Access to Pi #1 running DNS stack

---

## Installation Path 1: Web Wizard (Recommended for First-Time Users)

The web wizard provides a guided, browser-based setup experience.

### Step 1: Prepare the System

SSH into your Security Pi:

```bash
# Update system (recommended but optional)
sudo apt update && sudo apt upgrade -y

# Install Git if not present
sudo apt install -y git
```

### Step 2: Clone Repository

```bash
cd ~
git clone https://github.com/yorgosroussakis/Orion-sentinel-netsec-ai.git
cd Orion-sentinel-netsec-ai
```

### Step 3: Start the Wizard

```bash
cd stacks/ai
docker compose up -d wizard
```

**Note:** If Docker isn't installed, the wizard won't start. Run `./scripts/install.sh` from the repo root first, or install Docker manually:

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
# Log out and back in for group changes to take effect
```

### Step 4: Access the Wizard

Open your web browser and navigate to:

```
http://<Pi2-IP>:8081
```

Replace `<Pi2-IP>` with your Security Pi's IP address (e.g., `http://192.168.1.20:8081`).

### Step 5: Follow the Wizard

The wizard will guide you through:

1. **Welcome Page**: Overview of what Orion Sentinel does
2. **DNS Pi Connection**: Enter IP and optionally Pi-hole API credentials
3. **Network & Mode**: Configure monitoring interface and operating mode
4. **AI Features**: Enable AI detection and threat intelligence
5. **Finish**: Review and apply configuration

### Step 6: Verify Installation

After the wizard completes:

- **Grafana**: http://<Pi2-IP>:3000 (username: admin, password: from wizard or default 'admin')
- **API Docs**: http://<Pi2-IP>:8000/docs (if AI stack is running)

### Step 7: Configure Traffic Mirroring

For Suricata to capture traffic, configure your router/switch to mirror LAN traffic to the interface you specified in the wizard (e.g., `eth0`).

Consult your router documentation for "port mirroring", "SPAN", or "traffic monitoring" features.

---

## Installation Path 2: Automated Script (Power Users)

Use the install script for automated command-line installation.

### Run the Installer

```bash
cd ~/Orion-sentinel-netsec-ai
./scripts/install.sh
```

The script will:
1. Check for Docker (offer to install if missing)
2. Create environment files from examples
3. Prompt for:
   - NSM network interface (e.g., `eth0`)
   - Log retention period (days)
   - Grafana admin password
   - Whether to enable AI stack immediately
4. Start NSM stack (Suricata, Loki, Grafana)
5. Optionally start AI stack
6. Display access URLs

### Post-Installation

After installation:

1. **Configure DNS Integration**: Set up log shipping from Pi #1 (see `docs/integration-orion-dns-ha.md`)
2. **Customize Playbooks**: Edit `config/playbooks.yml` for automated responses
3. **Review Configuration**: Check `stacks/nsm/.env` and `stacks/ai/.env`

---

## Installation Path 3: Manual Setup (Advanced)

For complete control, configure everything manually.

### 1. Prepare Environment Files

```bash
cp stacks/nsm/.env.example stacks/nsm/.env
cp stacks/ai/.env.example stacks/ai/.env
```

### 2. Edit Configuration

Edit `stacks/nsm/.env`:
```bash
NSM_IFACE=eth0                    # Your monitoring interface
LOKI_RETENTION_DAYS=7             # Log retention
GRAFANA_ADMIN_PASSWORD=secure123  # Change this!
```

Edit `stacks/ai/.env`:
```bash
PIHOLE_API_URL=http://192.168.1.10/admin/api.php
PIHOLE_API_TOKEN=your-token-here
ENABLE_BLOCKING=false             # Start in observe mode
```

### 3. Start Services

```bash
# Start NSM stack
cd stacks/nsm
docker compose up -d

# Start AI stack
cd ../ai
docker compose up -d
```

### 4. Verify Services

```bash
docker ps
```

All services should show "Up" status.

---

## Next Steps

After installation (regardless of method):

### 1. Access Grafana

Visit `http://<Pi2-IP>:3000` and login:
- Username: `admin`
- Password: (what you set, or default `admin`)

**Important**: Change the admin password on first login!

### 2. Configure Traffic Mirroring

Set up your router/switch to mirror all LAN traffic to your Security Pi's monitoring interface.

### 3. Configure DNS Log Shipping (Optional but Recommended)

If you have Pi #1 running the DNS stack:

1. On Pi #1, configure Promtail to ship logs to Pi #2's Loki
2. See `docs/integration-orion-dns-ha.md` for details

### 4. Explore Dashboards

In Grafana:
- Navigate to Dashboards
- Check SOC Management Dashboard
- View DNS & Pi-hole Dashboard
- Explore logs in the Explore tab

### 5. Configure SOAR Playbooks

Edit `config/playbooks.yml` to define automated responses:

```bash
cd ~/Orion-sentinel-netsec-ai
cp config/playbooks.yml.example config/playbooks.yml
nano config/playbooks.yml
```

See `docs/soar.md` for playbook syntax and examples.

### 6. Review Operating Mode

For the first 24-48 hours, keep the system in **Observe Only** mode:

```bash
# In stacks/ai/.env
ENABLE_BLOCKING=false
SOAR_DRY_RUN=1
```

This allows you to review detections before enabling automated actions.

---

## Troubleshooting

### Services Won't Start

Check Docker status:
```bash
docker ps
docker compose logs
```

### Wizard Not Accessible

Ensure the wizard service is running:
```bash
cd stacks/ai
docker compose ps wizard
docker compose logs wizard
```

### No Traffic in Suricata

Verify:
1. Interface name is correct in `.env`
2. Interface is receiving mirrored traffic
3. Suricata has necessary permissions

```bash
docker compose logs suricata
```

### Grafana Shows No Data

Check:
1. Loki is running: `curl http://localhost:3100/ready`
2. Promtail is shipping logs: `docker compose logs promtail`
3. Services are writing to Loki

---

## Development Mode

To test without live traffic, use dev mode with sample logs:

```bash
cd stacks/nsm
docker compose -f docker-compose.dev.yml up -d
```

This uses sample log files from `samples/` directory instead of real traffic.

---

## Resources

- **Operations Guide**: `docs/operations.md` - Backup, restore, upgrades
- **SOAR Documentation**: `docs/soar.md` - Automated response playbooks
- **Device Inventory**: `docs/inventory.md` - Device tracking and profiling
- **Health Score**: `docs/health-score.md` - Security health metrics
- **Architecture**: `docs/architecture.md` - System design and data flows

---

## Support

For issues, questions, or suggestions:
- GitHub Issues: https://github.com/yorgosroussakis/Orion-sentinel-netsec-ai/issues
- Documentation: All files in `docs/` directory

---

**Built for privacy-focused home network security** 🛡️
