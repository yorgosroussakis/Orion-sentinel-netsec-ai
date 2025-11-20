# Operations Guide

This guide covers day-to-day operations, maintenance, and troubleshooting for Orion Sentinel Security Pi.

## Table of Contents

- [Installation](#installation)
- [Development vs Production Modes](#development-vs-production-modes)
- [Backup and Restore](#backup-and-restore)
- [Upgrades](#upgrades)
- [Service Management](#service-management)
- [Troubleshooting](#troubleshooting)
- [Monitoring](#monitoring)

---

## Installation

### Automated Installation (Recommended)

The `install.sh` script provides an interactive installation process:

```bash
# From repository root
./scripts/install.sh
```

The script will:
1. Check and optionally install Docker
2. Prepare environment configuration files
3. Prompt for configuration (NSM interface, Loki retention, passwords)
4. Start the NSM stack
5. Optionally start the AI stack
6. Display access URLs and next steps

### Manual Installation

If you prefer manual setup:

1. **Prepare environment files:**
   ```bash
   cp stacks/nsm/.env.example stacks/nsm/.env
   cp stacks/ai/.env.example stacks/ai/.env
   ```

2. **Edit configuration:**
   - Edit `stacks/nsm/.env` to set your network interface
   - Edit `stacks/ai/.env` to configure Pi-hole API access
   - Set secure passwords for Grafana

3. **Start services:**
   ```bash
   # Start NSM stack
   cd stacks/nsm
   docker compose up -d
   
   # Start AI stack (optional)
   cd ../ai
   docker compose up -d
   ```

---

## Development vs Production Modes

### Development Mode

Development mode uses sample log files instead of live network traffic. This is ideal for:
- Developing dashboards and queries
- Testing AI models and playbooks
- UI/UX development
- Learning the system without impacting production

**To run in dev mode:**

```bash
cd stacks/nsm
docker compose -f docker-compose.dev.yml up -d
```

**What's different in dev mode:**
- No Suricata (uses sample logs instead)
- Log injector replays sample data from `samples/` directory
- Separate Docker volumes (won't interfere with production data)
- Network name: `orion-nsm-dev-network`

**Sample log files:**
- `samples/suricata-eve.json` - Network security events
- `samples/dns.log` - DNS queries and responses
- `samples/intel-events.json` - Threat intelligence matches

**To stop dev mode:**
```bash
cd stacks/nsm
docker compose -f docker-compose.dev.yml down
```

### Production Mode

Production mode monitors real network traffic:

```bash
cd stacks/nsm
docker compose up -d
```

**Requirements:**
- Network switch/router configured for port mirroring
- Mirrored traffic sent to the interface specified in `NSM_IFACE`
- Sufficient disk space for log retention

---

## Backup and Restore

### Creating a Backup

Create a complete backup of your configuration and data:

```bash
./scripts/backup-all.sh
```

**What gets backed up:**
- Environment files (`.env` from both stacks)
- Configuration directory (`config/`)
- Inventory database
- Playbook configurations
- AI model manifest (list of models, not the files themselves)

**Backup location:**
Backups are stored in `backups/backup-YYYYMMDD-HHMMSS/`

**Best practices:**
- Run backups before major changes
- Run backups before upgrades
- Store backups off-system for disaster recovery
- Keep multiple backup versions

### Restoring from Backup

Restore configuration and data from a previous backup:

```bash
./scripts/restore-all.sh backups/backup-20240115-103000
```

**The restore process:**
1. Displays backup information and prompts for confirmation
2. Restores environment files
3. Restores configuration directory
4. Restores data stores (if services are running)
5. Shows model manifest for manual model restoration

**After restore:**
- Review restored configuration
- Restart services if needed
- Verify services are operational

---

## Upgrades

### Automated Upgrade

The upgrade script safely updates the system:

```bash
./scripts/upgrade.sh
```

**The upgrade process:**
1. Creates automatic backup
2. Checks for uncommitted changes (offers to stash)
3. Pulls latest code from repository
4. Updates Docker images
5. Restarts services with new versions

**If upgrade fails:**
Restore from the automatic backup:
```bash
./scripts/restore-all.sh backups/backup-<timestamp>
```

### Manual Upgrade

For more control over the upgrade process:

```bash
# 1. Backup
./scripts/backup-all.sh

# 2. Pull changes
git pull origin main

# 3. Update images and restart NSM stack
cd stacks/nsm
docker compose pull
docker compose up -d

# 4. Update images and restart AI stack
cd ../ai
docker compose pull
docker compose up -d
```

---

## Service Management

### Checking Service Status

```bash
# View all running containers
docker ps

# View specific stack
cd stacks/nsm
docker compose ps

cd stacks/ai
docker compose ps
```

### Viewing Logs

```bash
# View logs from NSM stack
cd stacks/nsm
docker compose logs -f

# View logs from specific service
docker compose logs -f suricata
docker compose logs -f loki

# View logs from AI stack
cd stacks/ai
docker compose logs -f soar
docker compose logs -f inventory
```

### Restarting Services

```bash
# Restart entire NSM stack
cd stacks/nsm
docker compose restart

# Restart specific service
docker compose restart suricata

# Restart entire AI stack
cd stacks/ai
docker compose restart
```

### Stopping Services

```bash
# Stop NSM stack
cd stacks/nsm
docker compose down

# Stop AI stack
cd stacks/ai
docker compose down

# Stop and remove volumes (WARNING: deletes data)
docker compose down -v
```

### Starting Services

```bash
# Start NSM stack
cd stacks/nsm
docker compose up -d

# Start AI stack
cd stacks/ai
docker compose up -d
```

---

## Troubleshooting

### Services Won't Start

**Check Docker:**
```bash
docker --version
docker compose version
systemctl status docker
```

**Check logs for errors:**
```bash
cd stacks/nsm
docker compose logs
```

**Common issues:**
- Port conflicts (3000, 3100, 8000, 8080 already in use)
- Insufficient permissions (add user to docker group)
- Out of disk space

### Suricata Not Capturing Traffic

**Verify interface:**
```bash
# Check NSM_IFACE setting
cat stacks/nsm/.env | grep NSM_IFACE

# Verify interface exists
ip link show

# Check if interface is up
ip link show eth0  # replace with your interface
```

**Check Suricata logs:**
```bash
cd stacks/nsm
docker compose logs suricata
```

### Grafana Won't Load

**Check if Grafana is running:**
```bash
docker ps | grep grafana
```

**Check Grafana logs:**
```bash
cd stacks/nsm
docker compose logs grafana
```

**Reset Grafana (WARNING: loses dashboards):**
```bash
cd stacks/nsm
docker compose down
docker volume rm orion_grafana-data
docker compose up -d
```

### Loki Storage Issues

**Check disk space:**
```bash
df -h
```

**Check Loki retention settings:**
```bash
cat stacks/nsm/.env | grep LOKI_RETENTION
```

**Adjust retention period:**
Edit `stacks/nsm/.env` and change `LOKI_RETENTION_DAYS`, then restart:
```bash
cd stacks/nsm
docker compose restart loki
```

### AI Service Issues

**Check AI service logs:**
```bash
cd stacks/ai
docker compose logs orion-ai
```

**Verify Loki connection:**
```bash
# Check if Loki is accessible
curl http://localhost:3100/ready
```

**Check Pi-hole connectivity:**
```bash
# Verify Pi-hole API configuration
cat stacks/ai/.env | grep PIHOLE
```

---

## Monitoring

### Health Checks

**Quick health check:**
```bash
# All services should show "Up"
docker ps

# Check Loki
curl http://localhost:3100/ready

# Check Grafana
curl http://localhost:3000/api/health
```

### Accessing Grafana

1. Open browser: `http://<Pi2-IP>:3000`
2. Login with credentials (default: admin/admin)
3. Navigate to dashboards
4. Check for data in graphs

### Viewing Logs in Loki

**Using Grafana:**
1. Go to Explore in Grafana
2. Select Loki datasource
3. Use LogQL queries:
   ```logql
   {job="suricata"}
   {job="dns"}
   {event_type="alert"}
   ```

**Using API:**
```bash
# Query recent logs
curl -G -s "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={job="suricata"}' \
  --data-urlencode 'limit=10' | jq
```

### Performance Monitoring

**Check resource usage:**
```bash
# Docker stats
docker stats

# System resources
htop
df -h
free -h
```

**Monitor log volume:**
```bash
# Check Loki data size
du -sh /var/lib/docker/volumes/orion_loki-data
```

---

## Additional Resources

- [Architecture Documentation](architecture.md)
- [SOAR Playbooks](soar.md)
- [Device Inventory](inventory.md)
- [Health Score](health-score.md)
- [AI Stack Details](ai-stack.md)

For issues and feature requests, visit the [GitHub repository](https://github.com/yorgosroussakis/Orion-sentinel-netsec-ai).
