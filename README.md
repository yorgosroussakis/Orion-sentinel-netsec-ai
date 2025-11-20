# Orion Sentinel - Network Security Monitoring & AI

**Mini-SOC Platform for Home/Lab Environments**

Orion Sentinel is a comprehensive security monitoring platform combining network security monitoring (NSM), AI-powered anomaly detection, automated response, and device management capabilities designed for home labs and small networks.

## Features

### 🛡️ SOAR-lite (Automated Response)
- Playbook-based automation
- Event-driven actions (blocking, tagging, notifications)
- Safety controls (dry-run mode, priorities)
- Integration with Pi-hole for DNS blocking

### 📊 Device Inventory & Fingerprinting
- Automatic device discovery
- Type classification (IoT, TV, NAS, etc.)
- Tagging and metadata management
- Risk scoring

### 🖥️ EDR-lite (Host Log Integration)
- Wazuh, osquery, syslog support
- Normalized event model
- Endpoint visibility

### 🍯 Honeypot Integration
- Designed for external honeypot containers
- High-confidence threat detection
- Attacker tracking

### 🔍 Change Detection
- Baseline snapshots
- Behavioral change alerts
- "What changed?" analysis

### 📈 Security Health Score
- Single 0-100 metric
- Four weighted components
- Actionable recommendations

### 🧪 Lab Mode
- Safe testing environment
- Device-based policy segregation
- Production protection

### 🌐 REST API
- Device profile endpoints
- Natural language assistant (pattern-based)
- Timeline views

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Grafana Dashboards                    │
└─────────────────────────────────────────────────────────────┘
                              ▲
                              │
┌─────────────────────────────┴───────────────────────────────┐
│                        Loki (Logs)                           │
└─────────────────────────────────────────────────────────────┘
         ▲         ▲         ▲         ▲         ▲
         │         │         │         │         │
    ┌────┴───┐ ┌──┴───┐ ┌───┴────┐ ┌──┴─────┐ ┌┴────────┐
    │  SOAR  │ │Inven-│ │Change  │ │Health  │ │   API   │
    │Service │ │tory  │ │Monitor │ │Score   │ │ Server  │
    └────────┘ └──────┘ └────────┘ └────────┘ └─────────┘
         ▲                   ▲
         │                   │
    ┌────┴─────────────────────────────────────┐
    │  Event Sources (Suricata, DNS, AI, etc.) │
    └──────────────────────────────────────────┘
```

## Quick Start

### Prerequisites

- Docker & Docker Compose
- Python 3.9+ (for development)
- Loki instance (included in docker-compose)

### Installation

1. **Clone repository**:
   ```bash
   git clone https://github.com/yorgosroussakis/Orion-sentinel-netsec-ai.git
   cd Orion-sentinel-netsec-ai
   ```

2. **Configure playbooks**:
   ```bash
   cp config/playbooks.yml.example config/playbooks.yml
   # Edit playbooks.yml for your environment
   ```

3. **Set environment variables**:
   ```bash
   export PIHOLE_API_KEY="your-api-key"
   export GRAFANA_ADMIN_PASSWORD="secure-password"
   ```

4. **Start services**:
   ```bash
   cd stacks/ai
   docker-compose up -d
   ```

5. **Access interfaces**:
   - Grafana: http://localhost:3000
   - API: http://localhost:8000
   - API Docs: http://localhost:8000/docs

### Development Setup

```bash
# Install dependencies
pip install -r requirements-dev.txt

# Install package in editable mode
pip install -e .

# Run a service
python -m orion_ai.soar.service
python -m orion_ai.inventory.service
python -m orion_ai.health_score.service
```

## Configuration

### SOAR Service

Key environment variables:

- `SOAR_DRY_RUN=1`: Enable dry run mode (recommended initially)
- `SOAR_POLL_INTERVAL=60`: Polling interval in seconds
- `SOAR_PLAYBOOKS_FILE=/config/playbooks.yml`: Playbook configuration
- `PIHOLE_URL=http://192.168.1.2`: Pi-hole instance URL
- `PIHOLE_API_KEY=xxx`: Pi-hole API key

### Inventory Service

- `INVENTORY_POLL_INTERVAL=300`: Update interval in seconds
- `INVENTORY_DB_PATH=/data/inventory.db`: SQLite database path

### Other Services

- `LOKI_URL=http://loki:3100`: Loki instance URL
- `LOG_LEVEL=INFO`: Logging level

See individual service documentation for details.

## Documentation

- [SOAR Playbooks](docs/soar.md)
- [Device Inventory](docs/inventory.md)
- [Change Monitor](docs/change-monitor.md)
- [Health Score](docs/health-score.md)
- [Lab Mode](docs/lab-mode.md)
- [Host Logs (EDR-lite)](docs/host-logs.md)
- [Honeypot Integration](src/orion_ai/honeypot/design.md)

## Module Structure

```
src/orion_ai/
├── soar/              # SOAR automation
│   ├── models.py      # Data models
│   ├── engine.py      # Playbook engine
│   ├── actions.py     # Action executors
│   └── service.py     # SOAR service
├── inventory/         # Device inventory
│   ├── models.py
│   ├── collector.py   # Log collection
│   ├── fingerprinting.py
│   ├── store.py       # SQLite storage
│   └── service.py
├── host_logs/         # EDR-lite
│   ├── models.py
│   └── normalizer.py  # Log normalization
├── honeypot/          # Honeypot integration
│   └── design.md
├── change_monitor/    # Change detection
│   ├── models.py
│   ├── baseline.py
│   ├── analyzer.py
│   └── service.py
├── health_score/      # Security health score
│   ├── models.py
│   ├── calculator.py
│   └── service.py
└── ui/                # REST APIs
    ├── device_profile_api.py
    ├── assistant_api.py
    └── http_server.py
```

## API Examples

### Get Device Profile

```bash
curl http://localhost:8000/device/192.168.1.50
```

### Get Device Timeline

```bash
curl http://localhost:8000/device/192.168.1.50/timeline?hours=24
```

### Tag a Device

```bash
curl -X POST http://localhost:8000/device/192.168.1.50/tag?tag=lab
```

### Query Assistant

```bash
curl -X POST http://localhost:8000/assistant/query \
  -H "Content-Type: application/json" \
  -d '{"question": "Show me suspicious activity from 192.168.1.50"}'
```

## Safety & Testing

### Initial Deployment

1. **Start in dry run mode**: `SOAR_DRY_RUN=1`
2. **Review logs**: Check what actions would be taken
3. **Test on lab devices**: Tag devices with `lab` tag
4. **Gradually enable**: One playbook at a time
5. **Monitor closely**: Watch for false positives

### Production Checklist

- [ ] All playbooks tested in dry run
- [ ] Lab devices tagged and tested
- [ ] High confidence thresholds set (≥0.9)
- [ ] Rollback plan documented
- [ ] Monitoring dashboards configured
- [ ] Team trained on SOAR interface

## Contributing

This is a personal home/lab project, but suggestions and feedback are welcome via issues.

## License

MIT License - See LICENSE file

## Related Projects

- [orion-sentinel-dns-ha](https://github.com/yorgosroussakis/orion-sentinel-dns-ha): DNS & HA component (Pi-hole + Unbound + Keepalived)

## Roadmap

- [ ] Complete Loki integration (query & push)
- [ ] Pi-hole API client implementation
- [ ] Notification channels (Signal, Telegram, Email)
- [ ] Grafana dashboard templates
- [ ] AI model integration (ONNX/TFLite)
- [ ] Threat intel feed integration (abuse.ch, OTX)
- [ ] Template variable resolution in playbooks
- [ ] Web UI for playbook management
- [ ] MITRE ATT&CK mapping

## Acknowledgments

Built for learning and home lab security. Inspired by enterprise SOC platforms adapted for Raspberry Pi constraints.