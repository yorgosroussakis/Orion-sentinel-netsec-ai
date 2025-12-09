# Orion Sentinel NetSec Node - Architecture & Implementation Plan

## Overview

The Orion Sentinel NetSec Node is a production-ready network security monitoring and AI-powered threat detection system designed for Raspberry Pi 5 with AI accelerator support (Hailo AI Hat). This document outlines the final architecture, deployment profiles, and operational model.

## Architecture

### High-Level Design

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Home/Lab Network                            │
│                                                                     │
│  ┌──────────────┐         ┌─────────────┐        ┌──────────────┐ │
│  │   Router     │         │   CoreSrv   │        │  NetSec Pi   │ │
│  │  / Switch    │────────▶│   (Dell)    │◀───────│   (Pi 5)     │ │
│  │              │         │             │        │ (This Repo)  │ │
│  │ - Port       │         │ - Loki      │        │              │ │
│  │   Mirror     │         │ - Prometheus│        │ - Suricata   │ │
│  │ - SPAN       │         │ - Grafana   │        │ - Promtail   │ │
│  │              │         │ - Traefik   │        │ - AI Engine  │ │
│  └──────┬───────┘         │ - Dashboards│        │ - SOAR       │ │
│         │                 └─────────────┘        │              │ │
│         │ Mirrored                               │ Role:        │ │
│         │ Traffic                                │ - Sensor     │ │
│         └────────────────────────────────────────▶│ - Detector  │ │
│                                                   │ - Responder │ │
│                                                   └──────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

### Component Layers

The NetSec Node consists of three logical layers managed through Docker Compose profiles:

1. **netsec-core** - Network Security Monitoring
   - Suricata IDS (passive monitoring on mirrored traffic)
   - Promtail (log shipping to Loki)
   - Node Exporter (system metrics)

2. **ai** - AI Detection & Response
   - SOAR service (automated playbook execution)
   - Inventory service (device tracking)
   - Change Monitor (baseline & anomaly detection)
   - Health Score (security posture scoring)
   - Web API/UI (dashboard and control interface)

3. **exporters** - Observability & Metrics
   - Node Exporter (system-level metrics)
   - Process Exporter (optional, for detailed process monitoring)

### Data Flow

```
1. Network Traffic Capture
   Router/Switch (port mirror) → NetSec Pi (Suricata)
   
2. Log Collection
   Suricata EVE JSON → Promtail → CoreSrv Loki
   AI Services → Structured Logs → CoreSrv Loki
   
3. AI Analysis
   AI Services → Query Loki → Analyze Events → Generate SecurityEvents
   
4. Automated Response
   SOAR Service → Read SecurityEvents → Execute Playbooks → Actions
   
5. Visualization
   CoreSrv Grafana → Query Loki → Display Dashboards
   Web UI (via Traefik) → Query Services → Display Events/Devices
```

## Deployment Profiles

### Profile: netsec-core

**Purpose**: Core network security monitoring - the foundation layer.

**Services**:
- `suricata` - IDS/IPS engine on mirrored traffic interface
- `promtail` - Log shipper to Loki
- `node-exporter` - System metrics exporter

**Use Case**: Minimum viable sensor for network monitoring.

**Start Command**:
```bash
docker compose --profile netsec-core up -d
# OR
make up-core
```

### Profile: ai

**Purpose**: AI-powered detection, correlation, and automated response.

**Services**:
- `soar` - Security orchestration & automated response
- `inventory` - Device discovery and fingerprinting
- `change-monitor` - Baseline and change detection
- `health-score` - Security health scoring
- `api` - Web UI and REST API

**Use Case**: Full AI capabilities with automated response.

**Start Command**:
```bash
docker compose --profile netsec-core --profile ai up -d
# OR
make up-all
```

### Profile: exporters

**Purpose**: Enhanced system observability.

**Services**:
- `node-exporter` - System-level metrics (CPU, memory, disk, network)
- `process-exporter` (optional) - Per-process metrics

**Use Case**: Detailed system monitoring for troubleshooting.

**Start Command**:
```bash
docker compose --profile netsec-core --profile exporters up -d
```

### Combined Profiles

Most common deployment modes:

1. **Production (Full Stack)**:
   ```bash
   make up-all
   # Runs: netsec-core + ai + exporters
   ```

2. **Core Only (Minimal)**:
   ```bash
   make up-core
   # Runs: netsec-core only
   ```

3. **Development (with local observability)**:
   ```bash
   make start-standalone
   # Runs: netsec-core + ai + local Loki + Grafana
   ```

## Configuration Management

### Environment Variables

All configuration is centralized in `.env` file at repository root:

**Network Interface** (required):
```bash
MONITOR_IF=eth0          # Interface receiving mirrored traffic
```

**Loki/Prometheus Endpoints** (required for SPoG mode):
```bash
LOKI_URL=http://192.168.8.50:3100
PROMETHEUS_URL=http://192.168.8.50:9090
```

**Node Identification** (recommended):
```bash
NODE_NAME=netsec-pi-01
NODE_LOCATION=basement
HOSTNAME=pi-netsec
```

**Operational Modes**:
```bash
LOCAL_OBSERVABILITY=false    # true = standalone, false = SPoG
SOAR_DRY_RUN=1              # 1 = dry-run, 0 = execute actions
```

### Configuration Files

- `.env` - Environment variables (operator configured)
- `config/playbooks.yml` - SOAR playbook definitions
- `stacks/nsm/suricata/suricata.yaml` - Suricata IDS configuration
- `stacks/nsm/promtail/promtail-config.yml` - Log shipping configuration

## Network Requirements

### Switch Configuration

The NetSec Pi requires **port mirroring** (also called SPAN - Switched Port Analyzer) to passively monitor network traffic.

**Configuration Steps**:

1. **Identify Ports**:
   - Source: Port(s) to monitor (typically uplink to router or internal VLAN)
   - Destination: Port connected to NetSec Pi's `MONITOR_IF`

2. **Configure Port Mirror**:
   - Enable port mirroring/SPAN on your switch
   - Set source port(s) = traffic you want to monitor
   - Set destination port = NetSec Pi interface
   - Direction: Both (ingress + egress)

3. **Examples**:

   **UniFi Switch**:
   ```
   Settings → Port → Select Pi port → Port Profile → Mirror Port
   ```

   **Cisco/Managed Switch**:
   ```
   monitor session 1 source interface gi1/0/1 both
   monitor session 1 destination interface gi1/0/24
   ```

   **TP-Link Managed Switch**:
   ```
   Switching → Mirroring → Add → Source Port → Destination Port
   ```

### Firewall Rules

**Outbound from NetSec Pi** (required):
- Allow TCP 3100 to CoreSrv (Loki)
- Allow TCP 9090 to CoreSrv (Prometheus)
- Allow TCP 80/443 for threat intel feeds (OTX, URLhaus, etc.)
- Allow DNS (UDP 53)

**Inbound to NetSec Pi** (optional):
- Allow TCP 8000 from CoreSrv (for Web UI proxying via Traefik)
- Allow TCP 9100 from CoreSrv (node-exporter metrics)

**Example iptables**:
```bash
# Allow established connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow from CoreSrv to services
iptables -A INPUT -s 192.168.8.50 -p tcp --dport 8000 -j ACCEPT
iptables -A INPUT -s 192.168.8.50 -p tcp --dport 9100 -j ACCEPT

# Default deny inbound
iptables -A INPUT -j DROP
```

## AI Accelerator Support

### Hailo AI Hat (Raspberry Pi 5)

The AI services are designed to leverage hardware acceleration when available.

**Requirements**:
- Raspberry Pi 5 (4GB+ RAM)
- Hailo-8 AI Kit or Hailo AI Hat (~13 TOPS)
- Hailo driver and firmware installed

**Driver Installation** (on Raspberry Pi OS):
```bash
# Install Hailo kernel module
sudo apt update
sudo apt install hailo-all

# Verify device
ls -la /dev/hailo*
# Should show: /dev/hailo0
```

**Model Format**:
- AI models should be in ONNX or TFLite format
- Hailo SDK can convert models to HEF (Hailo Executable Format)
- Place models in `stacks/ai/models/` directory

**Container Device Mapping**:
The AI services automatically mount `/dev/hailo*` devices when available:
```yaml
devices:
  - /dev/hailo0:/dev/hailo0
```

**Fallback**:
If no accelerator is detected, AI services fall back to CPU-based inference (slower but functional).

### Alternative Accelerators

The architecture supports other AI accelerators with minimal changes:

- **Google Coral TPU**: Map `/dev/apex_0`
- **Intel Movidius**: Map `/dev/myriad*`
- **NVIDIA Jetson**: Native CUDA support

Update the AI service containers in `compose.yml` to include the appropriate device mappings.

## Observability

### Dashboards

Pre-configured Grafana dashboards are provided in `grafana_dashboards/`:

1. **SOC Management** - Security overview, health score, recent events
2. **DNS & Pi-hole** - DNS query analysis, blocking stats
3. **Network Traffic** - Suricata flow statistics
4. **System Metrics** - Node exporter data (CPU, RAM, disk)

**Dashboard Import** (on CoreSrv):
```bash
# Copy dashboards to CoreSrv Grafana
scp grafana_dashboards/*.json coresrv:/path/to/grafana/provisioning/dashboards/
```

### Metrics Endpoints

**Node Exporter**: `http://pi-netsec:9100/metrics`
- System CPU, memory, disk, network stats

**Suricata Stats**: Available via EVE JSON logs in Loki
- Alert counts, drop rates, capture stats

**AI Service Metrics**: Written to Loki as structured logs
- Event processing rates, risk scores, action counts

## Operational Workflows

### Initial Setup

1. **Clone Repository**:
   ```bash
   git clone https://github.com/orionsentinel/Orion-sentinel-netsec-ai.git
   cd Orion-sentinel-netsec-ai
   ```

2. **Run Bootstrap**:
   ```bash
   ./scripts/bootstrap-netsec.sh
   ```
   This script:
   - Checks Docker installation
   - Verifies kernel parameters
   - Validates network interface exists
   - Creates `.env` from template

3. **Edit Configuration**:
   ```bash
   nano .env
   ```
   Set:
   - `MONITOR_IF` - Your mirrored traffic interface
   - `LOKI_URL` - CoreSrv Loki endpoint
   - `NODE_NAME` - Identifier for this sensor

4. **Start Services**:
   ```bash
   make up-all
   ```

5. **Verify Operation**:
   ```bash
   make test
   ```

### Day-to-Day Operations

**View Logs**:
```bash
make logs
# OR
./scripts/netsecctl.sh logs
```

**Check Status**:
```bash
make status
# OR
docker compose ps
```

**Restart Services**:
```bash
make restart-spog
```

**Update Images**:
```bash
make update-images
make restart-spog
```

### Validation & Testing

**1. Verify Suricata is Capturing**:
```bash
docker exec orion-suricata suricatasc -c "capture-mode"
# Should show: "AF_PACKET"

docker logs orion-suricata | grep "Capture"
# Should show packets received on MONITOR_IF
```

**2. Verify Log Shipping**:
```bash
docker logs orion-promtail | grep "POST"
# Should show: POST /loki/api/v1/push (200 OK)
```

**3. Verify AI Services**:
```bash
curl http://localhost:8000/api/health
# Should return: {"status": "healthy"}
```

**4. Generate Test Traffic**:
```bash
# On another device, generate some HTTP traffic
curl http://testmyids.com
# Should trigger Suricata alert visible in Loki
```

## Security Considerations

### Least Privilege

- Suricata runs with only `NET_ADMIN`, `NET_RAW`, and `SYS_NICE` capabilities
- AI services run without special privileges
- No services run as root inside containers

### Credential Management

- No credentials in code or compose files
- All secrets via `.env` file (excluded from git)
- `.env` permissions should be `0600` (owner read/write only)

### Network Isolation

- NetSec Pi operates in **passive mode only**
- No inline traffic processing (not a firewall)
- Cannot block traffic directly (uses Pi-hole API for DNS blocking)

### Audit Trail

- All SOAR actions logged to Loki with timestamps and justifications
- Dry-run mode for testing before enforcement
- Full event correlation chain preserved

## Troubleshooting

### Common Issues

**1. No traffic in Suricata**:
- Verify port mirroring is configured on switch
- Check `MONITOR_IF` is correct interface: `ip link show`
- Ensure interface is up: `ip link set eth0 up`

**2. Promtail not shipping logs**:
- Check `LOKI_URL` is reachable: `curl $LOKI_URL/ready`
- Verify network connectivity to CoreSrv
- Check Promtail logs: `docker logs orion-promtail`

**3. AI services not starting**:
- Check Loki connectivity from AI containers
- Verify volumes are writable: `ls -la stacks/ai/data/`
- Check service logs: `docker logs orion-soar`

**4. High CPU usage**:
- Reduce Suricata rule count (disable unused rulesets)
- Increase AI service polling intervals in `.env`
- Consider hardware upgrade (more RAM/CPU cores)

## Upgrade Path

### Version Updates

1. **Backup Configuration**:
   ```bash
   make backup-config
   ```

2. **Pull Latest Code**:
   ```bash
   git pull origin main
   ```

3. **Update Images**:
   ```bash
   make update-images
   ```

4. **Review Changelog**: Check for breaking changes

5. **Restart Services**:
   ```bash
   make restart-spog
   ```

### Rollback

If issues occur:
```bash
git checkout <previous-tag>
docker compose down
docker compose up -d
```

## Future Enhancements

Planned features for future releases:

- [ ] Active IPS mode (inline blocking) with failsafe
- [ ] Multi-node deployment (multiple NetSec Pi sensors)
- [ ] Custom ML model training pipeline
- [ ] MITRE ATT&CK mapping and reporting
- [ ] Integration with SIEM platforms (Splunk, Elastic)
- [ ] Mobile app for alerts and management

## References

- [README.md](README.md) - User-facing documentation
- [QUICKSTART.md](QUICKSTART.md) - Fast setup guide
- [docs/](docs/) - Detailed component documentation
- [Suricata Documentation](https://suricata.io/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/latest/)
