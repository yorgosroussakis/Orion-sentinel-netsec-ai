# Orion Sentinel

**AI-Assisted Network Security & SOAR for Home Labs and Small Offices**

An open, hackable SOC-in-a-box that runs on a Raspberry Pi or mini-PC. Orion Sentinel combines network security monitoring (Suricata + Loki), AI-powered threat detection, and automated response (SOAR) to give you real visibility and control over your home or small office network.

**Who it's for:**
- 🏠 **Home power users** – Protect family devices, block sketchy domains, understand "what just happened?"
- 🧪 **Lab builders & learners** – See how modern security stacks work (NSM + AI + SOAR + observability)
- 🏢 **Small offices & freelancers** – Simple monitoring with automated actions, no enterprise complexity

**What you get:**
- Network security monitoring with Suricata IDS and centralized logging (Loki)
- AI-powered detection that explains its reasoning (risk scores + threat intel enrichment)
- SOAR playbooks that can block domains (Pi-hole), send notifications, or tag devices
- Real-time dashboards (Grafana) and a web UI for events, devices, and playbooks

---

## What is Orion Sentinel?

Orion Sentinel is a comprehensive security monitoring platform designed for **one network** (your home, lab, or small office). It sits between consumer appliances like Firewalla—which are easy but opaque—and enterprise SOC platforms like Security Onion or Wazuh—which are powerful but heavy and complex. 

You get transparent, hackable components (all Docker-based), full observability into what's happening on your network, and the ability to automate responses without writing code. Perfect for learning, experimenting, or genuinely protecting a small network.

---

## Why Not Just Use a Firewall Box or Security Onion?

**vs. Firewalla / UniFi Threat Management (consumer appliances):**
- ✅ **Open & inspectable**: Every component is visible and configurable—no black-box appliance
- ✅ **Runs on your hardware**: Use a Pi 4/5 or any mini-PC you already own
- ✅ **Full observability**: Loki + Grafana dashboards show exactly what's happening
- ✅ **Hackable & extensible**: Modify playbooks, add models, integrate with your tools
- ❌ Not as polished or plug-and-play (trade-off for transparency and control)

**vs. Security Onion / Wazuh / SELKS (enterprise SOC platforms):**
- ✅ **Single-device deployment**: Designed for one Pi or mini-PC, not multi-node clusters
- ✅ **Docker Compose simplicity**: No Kubernetes, complex installers, or heavy infrastructure
- ✅ **Pi-friendly**: Optimized for ARM and constrained resources (4–8GB RAM)
- ✅ **Home/lab scale**: Built for <50 devices, not 1000+ endpoints or 24/7 SOC teams
- ❌ Not enterprise-grade (intentionally—this is for your home/lab network)

**vs. CrowdSec (community firewall):**
- ✅ **Full NSM + observability**: Not just blocking—you see flows, DNS, alerts, and AI context
- ✅ **AI-assisted correlation**: Explains why something is risky, not just scores
- ✅ **SOAR automation**: Playbooks for actions beyond blocking (notifications, tagging, webhooks)
- ❌ Smaller community and less mature than CrowdSec (trade-off for customization)

**The Orion Sentinel niche:**
- Transparent architecture you can understand, inspect, and modify
- AI that correlates events and explains reasoning (not just black-box scores)
- SOAR that acts on your specific network (Pi-hole DNS, router APIs, notifications)
- Designed for learning: see how modern security stacks work in practice

---

## Key Features

### 🔍 Network Security Monitoring (NSM)
- **Suricata IDS**: Passive traffic monitoring via mirrored/SPAN port with signature-based detection
- **Loki log aggregation**: Centralized storage for NSM logs, DNS queries, AI events, and host logs
- **Promtail log shipping**: Unified collection from Suricata, Pi-hole, system logs
- **Real-time visibility**: See all flows, alerts, and DNS activity as they happen

### 🤖 AI-Assisted Detection & Threat Intelligence
- **Event correlation**: AI analyzes Suricata alerts + DNS logs + device inventory + threat intel together
- **Risk scoring with explanations**: Each event gets a score (0–1) plus human-readable context
- **Device anomaly detection**: Per-device behavioral analysis (connections, bytes, DNS patterns)
- **Domain risk scoring**: DGA detection, phishing identification, botnet C2 spotting
- **Threat intel integration** (automatic IOC enrichment):
  - AlienVault OTX (community threat exchange)
  - abuse.ch URLhaus (malicious URLs)
  - abuse.ch Feodo Tracker (botnet C2 servers)
  - PhishTank (verified phishing sites)
- High-confidence IOC matches boost risk scores automatically

### ⚡ SOAR & Automated Response
- **Playbook-based automation**: YAML-defined event-driven actions (no coding required)
- **Built-in actions**:
  - Block domains via Pi-hole DNS API
  - Send notifications (Email/SMTP, Signal, Telegram, custom webhooks)
  - Tag devices or change device profiles
  - Execute custom scripts
- **Safety controls**:
  - Dry-run mode (see what would happen without executing)
  - Priority-based execution (high-priority playbooks run first)
  - Lab mode (device-based policy segregation—test on lab devices only)
  - Full audit logging (every action is logged to Loki)
- **Web UI for playbook management**: Enable/disable playbooks, view execution history, test actions

### 📊 Observability & Dashboards
- **Grafana dashboards** (auto-provisioned):
  - SOC Management: Health score, key metrics, recent high-risk events
  - DNS & Pi-hole: Query analysis, block rates, top domains
  - Custom dashboards: LogQL queries for any data in Loki
- **Web UI** (port 8080):
  - Dashboard: Security health score and recent event summary
  - Events: Searchable, filterable log of all security events
  - Devices: Complete asset inventory with risk scoring
  - Playbooks: Manage SOAR playbooks (enable/disable, view history)
- **JSON REST APIs**: All web UI pages available as JSON for scripting/automation

### 🏠 Home/SOHO & Lab-Friendly
- **Docker Compose deployment**: Simple two-stack setup (`stacks/nsm` + `stacks/ai`)—no Kubernetes
- **Designed for constrained hardware**:
  - Raspberry Pi 4/5 (4–8GB RAM recommended)
  - Intel N100 or similar mini-PC
  - Single-box deployment (one device does it all)
- **Lab mode**: Safe testing environment with device-based policy segregation
- **Low maintenance**: Auto-provisioned dashboards, configurable log retention, minimal tuning needed

### 🔧 Additional Capabilities
- **Multi-channel notifications**: Rich alert formatting with threat context sent via Email, Signal, Telegram, or webhooks
- **Device inventory & fingerprinting**: Automatic discovery, type classification (IoT, TV, NAS, etc.), tagging, metadata
- **Security health score**: Single 0–100 metric with weighted components (unknown devices, anomalies, threat intel hits, critical events) and actionable recommendations
- **EDR-lite (host log integration)**: Normalize and correlate logs from Wazuh, osquery, or syslog for endpoint visibility
- **Honeypot integration**: Support for external honeypot containers (high-confidence threat detection)
- **Change detection**: Baseline snapshots, behavioral change alerts, "what changed?" analysis

---

## Architecture at a Glance

Orion Sentinel runs as **two Docker Compose stacks** on a single device (Raspberry Pi or mini-PC):

```
┌───────────────────────────────────────────────────────────────────┐
│                   Pi/Mini-PC (Docker Host)                        │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────────┐│
│  │            Stack 1: NSM (Network Monitoring)                 ││
│  │  ┌──────────┐  ┌─────────┐  ┌─────────┐  ┌──────────┐      ││
│  │  │ Suricata │─▶│Promtail │─▶│  Loki   │◀─│ Grafana  │      ││
│  │  │   IDS    │  │         │  │  Logs   │  │Dashboards│      ││
│  │  └────▲─────┘  └─────────┘  └────▲────┘  └──────────┘      ││
│  │       │                           │                          ││
│  └───────┼───────────────────────────┼──────────────────────────┘│
│          │ Mirrored Traffic          │                           │
│  ┌───────┴───────────────────────────┼──────────────────────────┐│
│  │            Stack 2: AI (Detection & Response)                ││
│  │                                    │                          ││
│  │  ┌─────────────────────────────────┼────────────────────┐    ││
│  │  │         AI Engine & SOAR        │                    │    ││
│  │  │  • Inventory Service   ─────────┘ Read/Write Events  │    ││
│  │  │  • SOAR Service                                       │    ││
│  │  │  • Health Score Service                               │    ││
│  │  │  • Threat Intel Sync                                  │    ││
│  │  │  • Change Monitor                                     │    ││
│  │  └───────────────────────────────────────────────────────┘    ││
│  │  ┌─────────────────────────────────────────────────────┐     ││
│  │  │          Web UI (Port 8080)                         │     ││
│  │  │  Dashboard │ Events │ Devices │ Playbooks           │     ││
│  │  └─────────────────────────────────────────────────────┘     ││
│  │             │ Actions (via playbooks)                        ││
│  │             ▼                                                 ││
│  │  ┌────────────────────────────────┐                          ││
│  │  │ Pi-hole / Router APIs          │ (Optional integrations)  ││
│  │  │ Notification Services          │                          ││
│  │  └────────────────────────────────┘                          ││
│  └───────────────────────────────────────────────────────────────┘│
│         ▲                                                         │
│         │ Port Mirror / SPAN                                     │
└─────────┼─────────────────────────────────────────────────────────┘
          │
    ┌─────┴──────┐
    │  Router /  │
    │   Switch   │
    └────────────┘
```

**Data flow in 5 steps:**

1. **Traffic capture**: Router/switch mirrors LAN traffic → Suricata IDS sees everything, analyzes, logs alerts/flows/DNS
2. **Log centralization**: Suricata logs + Pi-hole DNS logs + host logs → Promtail → Loki (central storage)
3. **AI analysis**: AI services read logs from Loki → correlate events, score risks, enrich with threat intel
4. **Event generation**: AI produces `SecurityEvent` records with scores + explanations → written back to Loki
5. **Automated response**: SOAR service reads high-risk events from Loki → matches playbooks → executes actions (block, notify, tag)

Everything is visible in Grafana (analytics/dashboards) and the Web UI (operational view of events, devices, playbooks).

---

## Who Is This For?

### 🏠 Home Power User
**Scenario**: "I want to protect my kids' devices, block sketchy domains automatically, and understand 'what just happened?' when something pings a weird country or generates suspicious DNS queries."

**What Orion Sentinel does for you**:
- See all network activity in Grafana dashboards (who's talking to whom, which domains are queried)
- Get notified (email/Signal/Telegram) when high-risk events occur (threat intel hits, anomalies)
- Automatically block known-bad domains via Pi-hole integration
- Review device inventory to see what's on your network and tag "lab" vs "production" devices

### 🧪 Lab Builder / Learner
**Scenario**: "I want to learn how modern security stacks work. I want to generate attack traffic in a lab, see Suricata alerts, watch Loki aggregate logs, see AI correlation in action, and understand how SOAR playbooks execute."

**What Orion Sentinel does for you**:
- Hands-on experience with real NSM tools (Suricata, Loki, Grafana) in a safe home lab
- Experiment with AI models, threat intel feeds, and playbook logic
- Lab mode lets you test aggressive policies on tagged devices without affecting production
- Transparent architecture: inspect every config file, log, and Docker container
- Modify playbooks, add custom actions, integrate with your own tools

### 🏢 Small Office / Freelancer
**Scenario**: "I have 10–20 devices (laptops, phones, NAS, IoT). I want basic security monitoring, automated blocking of known-bad domains, and alerts when something high-risk happens—without buying expensive enterprise gear or spending hours on maintenance."

**What Orion Sentinel does for you**:
- Simple Docker Compose deployment on a cheap mini-PC or Pi
- Automated threat response via SOAR playbooks (block domains, send notifications)
- Health score dashboard shows overall security posture at a glance
- Low maintenance: runs unattended, auto-provisions dashboards, configurable retention

---

## Quick Start for Raspberry Pi / Mini-PC

**Goal**: Get Suricata + Loki + Grafana + AI/SOAR running in 30–60 minutes.

**Prerequisites**:
- Raspberry Pi 4/5 (4–8GB RAM) or Intel N100/similar mini-PC
- Raspberry Pi OS 64-bit, Ubuntu, or Debian with Docker + Docker Compose installed
- Network switch with port mirroring (SPAN/TAP) or access to router's mirror port
- 32GB+ storage (microSD or external SSD recommended for Loki logs)
- (Optional) Pi-hole instance for DNS blocking integration

**High-level steps**:

1. **Clone repo and configure**:
   ```bash
   git clone https://github.com/yorgosroussakis/Orion-sentinel-netsec-ai.git
   cd Orion-sentinel-netsec-ai
   cp .env.example .env
   # Edit .env with your settings (network interface, Pi-hole URL, notification credentials, etc.)
   ```

2. **Start NSM stack** (Suricata + Loki + Grafana):
   ```bash
   cd stacks/nsm
   docker compose up -d
   ```

3. **Start AI/SOAR stack** (detection, playbooks, web UI):
   ```bash
   cd ../ai
   docker compose up -d
   ```

4. **Access interfaces**:
   - Web UI: `http://<pi-ip>:8080` (dashboard, events, devices, playbooks)
   - Grafana: `http://<pi-ip>:3000` (default: `admin/admin`)
   - Loki API: `http://<pi-ip>:3100`

5. **Generate test events**: Visit known test domains, trigger Suricata alerts, check dashboards

**For detailed step-by-step instructions**, see **[docs/QUICKSTART-home-lab.md](docs/QUICKSTART-home-lab.md)**.

---

## Comparison Table

| Feature                | Orion Sentinel            | Firewalla              | Security Onion         | CrowdSec              |
|------------------------|---------------------------|------------------------|------------------------|-----------------------|
| **Target User**        | Home/lab/small office     | Home user              | Enterprise SOC         | Servers & web apps    |
| **Openness**           | Fully open (MIT)          | Closed source          | Open (GPL)             | Open (MIT)            |
| **Hardware**           | Pi 4/5, N100 mini-PC      | Firewalla appliance    | Multi-node servers     | Any Linux             |
| **AI/ML**              | AI risk scoring + TI      | Yes (proprietary)      | Yes (Zeek ML, Strelka) | Community blocklists  |
| **SOAR**               | Yes (playbooks, actions)  | Limited (mobile app)   | Advanced (TheHive)     | Bouncers (blocking)   |
| **Complexity**         | Moderate (Docker Compose) | Low (plug & play)      | High (Elastic, K8s)    | Low (agent install)   |
| **Typical Deployment** | Single device             | Appliance on network   | Multi-server cluster   | Per-server agent      |
| **Observability**      | Full (Loki + Grafana)     | Mobile app only        | Kibana dashboards      | Grafana/Prometheus    |
| **Cost**               | Free (DIY hardware)       | $200–$500+ (appliance) | Free (DIY servers)     | Free (DIY)            |

---

## Configuration

All configuration is via environment variables in `.env` files. See `.env.example` for all options.

**Key settings**:

- **SOAR Automation**:
  - `SOAR_DRY_RUN=1` – Enable dry-run mode (recommended initially—logs actions without executing)
  - `SOAR_POLL_INTERVAL=60` – Event polling interval in seconds

- **Notifications** ([Setup Guide](docs/notifications.md)):
  - `NOTIFY_SMTP_HOST`, `NOTIFY_SMTP_USER`, `NOTIFY_SMTP_PASS` – Email via SMTP
  - `NOTIFY_SIGNAL_ENABLED=true`, `NOTIFY_SIGNAL_API_URL` – Signal messenger
  - `NOTIFY_TELEGRAM_ENABLED=true`, `NOTIFY_TELEGRAM_BOT_TOKEN` – Telegram bot

- **Threat Intelligence** ([Integration Guide](docs/threat-intel.md)):
  - `TI_ENABLE_OTX=true`, `TI_OTX_API_KEY=<your-key>` – AlienVault OTX
  - `TI_ENABLE_URLHAUS=true` – abuse.ch URLhaus
  - `TI_ENABLE_FEODO=true` – abuse.ch Feodo Tracker
  - `TI_ENABLE_PHISHTANK=true` – PhishTank

- **Pi-hole Integration**:
  - `PIHOLE_URL=http://192.168.1.2` – Pi-hole instance URL
  - `PIHOLE_API_KEY=<your-api-key>` – Pi-hole API key for domain blocking

- **Web UI**:
  - `API_HOST=0.0.0.0`, `API_PORT=8080` – Web interface binding

See `.env.example` for complete configuration options.

---

## Documentation

### Core Features
- [SOAR Playbooks](docs/soar.md) – Automated response and playbook configuration
- [Notifications & Alerts](docs/notifications.md) – Multi-channel notification setup
- [Threat Intelligence](docs/threat-intel.md) – IOC feeds and enrichment
- [Web Dashboard](docs/web-ui.md) – Web UI usage and API reference
- [Device Inventory](docs/inventory.md) – Asset discovery and tracking
- [Health Score](docs/health-score.md) – Security health calculation
- [Change Monitor](docs/change-monitor.md) – Behavioral change detection

### Setup & Architecture
- [Quick Start for Home Labs](docs/QUICKSTART-home-lab.md) – Step-by-step first install
- [Architecture Overview](docs/architecture.md) – Detailed system design and data flows
- [Roadmap](docs/ROADMAP.md) – Feature roadmap and project status
- [Lab Mode](docs/lab-mode.md) – Safe testing environment
- [Integration with Pi-hole/DNS](docs/integration-orion-dns-ha.md) – DNS component integration

### Advanced Topics
- [Host Logs (EDR-lite)](docs/host-logs.md) – Endpoint log integration
- [Honeypot Integration](src/orion_ai/honeypot/design.md) – Honeypot design
- [Grafana Dashboards](config/grafana/README.md) – Dashboard customization

---

## API Examples

### Web UI Pages (HTML)

```bash
# Dashboard with health score and recent events
http://localhost:8080/

# Security events log (searchable, filterable)
http://localhost:8080/events

# Device inventory
http://localhost:8080/devices

# SOAR playbook management
http://localhost:8080/playbooks
```

### JSON API Endpoints

```bash
# Get recent events
curl http://localhost:8080/api/events?limit=50&hours=24

# Get device list
curl http://localhost:8080/api/devices

# Get device profile
curl http://localhost:8080/api/device/192.168.1.50

# List playbooks
curl http://localhost:8080/api/playbooks

# Toggle playbook
curl -X POST http://localhost:8080/api/playbooks/alert-high-risk-domain/toggle \
  -H "Content-Type: application/json" \
  -d '{"enabled": false}'

# Get health score
curl http://localhost:8080/api/health
```

### Threat Intelligence CLI

```bash
# Sync threat intel feeds (AlienVault OTX, URLhaus, Feodo, PhishTank)
docker compose exec ai-service python -m orion_ai.threat_intel.sync --hours 24

# View IOC statistics
docker compose exec ai-service python -m orion_ai.threat_intel.sync --stats
```

---

## Safety & Testing

### Initial Deployment Recommendations

1. **Start in dry-run mode**: Set `SOAR_DRY_RUN=1` in `.env` to see what actions would be taken without executing them
2. **Review logs**: Check what playbooks match and what actions would execute
3. **Test on lab devices first**: Tag test devices with `lab` tag and enable lab mode
4. **Enable playbooks gradually**: Start with notifications-only, then add blocking
5. **Monitor closely**: Watch for false positives in the first days/weeks

### Production Checklist

Before disabling dry-run mode and enabling automated blocking:

- [ ] All playbooks tested in dry-run mode for at least 1 week
- [ ] Lab devices tagged and tested with aggressive policies
- [ ] High confidence thresholds set (≥0.9 for automated blocking)
- [ ] Rollback plan documented (how to quickly disable playbooks or revert blocks)
- [ ] Monitoring dashboards reviewed daily
- [ ] Notification channels tested (email/Signal/Telegram working)

---

## Project Status & Expectations

**Orion Sentinel is a work-in-progress home/lab SOC project.** It is actively developed and used in a personal home lab environment. 

**What this means for you**:
- ✅ **Functional**: Core features (NSM, AI detection, SOAR, dashboards) are implemented and working
- ⚠️ **Evolving**: Expect changes, improvements, and occasional breaking updates
- 🧪 **Experimental**: Some features are in early stages (marked in [docs/ROADMAP.md](docs/ROADMAP.md))
- 🛠️ **DIY-friendly**: Designed for technically comfortable users who can troubleshoot Docker, read logs, and modify configs
- 📚 **Learning-focused**: Great for understanding how security stacks work, not a polished commercial product

**This is not**:
- ❌ A supported commercial product with SLAs or guarantees
- ❌ Enterprise-ready out of the box (it's for home/lab/small office scale)
- ❌ A plug-and-play appliance (requires setup, configuration, and understanding of components)

**Contributions welcome!** Open issues for bugs or feature requests, submit PRs for improvements, experiment with playbooks and models, and share your experiences. This is a community/learning project.

---

## Related Projects

- [orion-sentinel-dns-ha](https://github.com/yorgosroussakis/orion-sentinel-dns-ha) – DNS & Privacy component (Pi-hole + Unbound + Keepalived)

---

## License

MIT License – See [LICENSE](LICENSE) file.

---

## Acknowledgments

Built for learning and home lab security. Inspired by enterprise SOC platforms, adapted for Raspberry Pi constraints and home network scale.

**Built with ❤️ for privacy-focused, transparent home network security.**
