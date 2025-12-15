# NetSec Pi - Network Security Monitoring Node

This document describes the Orion Sentinel NetSec Pi deployment, a production-ready network security sensor for Raspberry Pi 5 with NVMe storage.

## What This Node Produces

The NetSec Pi produces three main outputs:

### 1. EVE JSON Logs (`eve.json`)

Suricata writes all security events to `/var/log/suricata/eve.json` (mounted from NVMe at `${NVME_MOUNT}/suricata/logs/eve.json`).

**Event types included:**
- `alert` - IDS signature matches
- `dns` - DNS queries and responses
- `http` - HTTP request/response metadata
- `tls` - TLS/SSL handshake information
- `flow` - Network flow records
- `stats` - Suricata performance statistics

**Example alert event:**
```json
{
  "timestamp": "2024-01-15T10:30:00.000000+0000",
  "event_type": "alert",
  "src_ip": "192.168.1.100",
  "dest_ip": "93.184.216.34",
  "alert": {
    "signature": "ET POLICY curl User-Agent Outbound",
    "signature_id": 2014726,
    "severity": 3,
    "category": "Potential Corporate Privacy Violation"
  }
}
```

### 2. Log Shipping via Promtail → Loki

Promtail tails the Suricata logs and ships them to your central Loki instance (typically on CoreSrv).

**Labels applied to logs:**
- `orion_node_role: netsec`
- `orion_node_name: <from .env>`
- `app: suricata`
- `stream: eve-json` | `fast` | `stats` | `app-log`
- `job: netsec`

**Loki query examples:**
```logql
# All alerts from this node
{orion_node_role="netsec", app="suricata"} | json | event_type="alert"

# High severity alerts
{orion_node_role="netsec"} | json | event_type="alert" | alert_severity <= 2

# DNS queries
{orion_node_role="netsec"} | json | event_type="dns"
```

### 3. Node Metrics via Node Exporter

System metrics are exposed on port `${NODE_EXPORTER_PORT:-19100}` for Prometheus scraping.

**Metrics available:**
- CPU usage per core
- Memory and swap usage
- Disk I/O and usage (including NVMe)
- Network I/O per interface
- System uptime and load average

**Why port 19100?**
The default port is 19100 instead of the standard 9100 to avoid conflicts with other node-exporters that may be running on the same network. If your Prometheus is already scraping port 9100 from another source, this prevents "address already in use" errors.

Configure in `.env`:
```bash
NODE_EXPORTER_PORT=19100  # Default, change if needed
```

---

## Quick Commands

### Stack Management

```bash
# Start the stack
./scripts/netsec-up.sh

# Start with EveBox UI
./scripts/netsec-up.sh --with-evebox

# Stop the stack
docker compose --profile netsec-minimal down

# View container status
docker compose ps

# View all containers (including stopped)
docker compose ps -a
```

### Suricata Operations

```bash
# Test Suricata configuration
docker exec orion-netsec-suricata suricata -T -c /etc/suricata/suricata.yaml

# View live Suricata logs
docker logs -f orion-netsec-suricata

# Update rules and restart
./scripts/suricata-update.sh

# Update rules without restart
./scripts/suricata-update.sh --no-restart
```

### Log Analysis

```bash
# View all alerts (live)
tail -f ${NVME_MOUNT:-/mnt/orion-nvme-netsec}/suricata/logs/eve.json | jq 'select(.event_type=="alert")'

# Count alerts by signature
jq -r 'select(.event_type=="alert") | .alert.signature' /mnt/orion-nvme-netsec/suricata/logs/eve.json | sort | uniq -c | sort -rn | head -20

# Search for specific alert
grep '"event_type":"alert"' /mnt/orion-nvme-netsec/suricata/logs/eve.json | jq 'select(.alert.signature | contains("curl"))'

# View DNS queries
jq 'select(.event_type=="dns")' /mnt/orion-nvme-netsec/suricata/logs/eve.json | head -50
```

### Validation

```bash
# Full validation
./scripts/validate-netsec.sh

# Quick check (container + eve.json only)
./scripts/validate-netsec.sh --quick

# Check NVMe health
./scripts/check-nvme.sh
```

### Debugging

```bash
# Check interface traffic
sudo tcpdump -i ${NETSEC_INTERFACE:-eth1} -c 10 -nn

# Check Suricata stats
docker exec orion-netsec-suricata cat /var/log/suricata/stats.log | tail -50

# Check Promtail shipping
docker logs orion-netsec-promtail | grep -i "POST\|push"

# Enter debug container (if running)
docker exec -it orion-netsec-debug /bin/sh
```

---

## Configuration Files

| File | Location | Purpose |
|------|----------|---------|
| `.env` | Project root | Environment variables |
| `compose.yml` | Project root | Docker Compose services |
| `config/suricata/suricata.yaml` | Repo template | Suricata config template |
| `config/suricata/disable.conf` | Repo template | Rules to disable |
| `${NVME_MOUNT}/suricata/etc/suricata.yaml` | NVMe runtime | Active Suricata config |
| `${NVME_MOUNT}/suricata/etc/disable.conf` | NVMe runtime | Active disable rules |

---

## Key Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `NVME_MOUNT` | `/mnt/orion-nvme-netsec` | NVMe mount point |
| `NETSEC_INTERFACE` | `eth1` | Interface for packet capture |
| `NODE_EXPORTER_PORT` | `19100` | Prometheus metrics port |
| `LOKI_URL` | `http://loki:3100` | Loki push endpoint |
| `TZ` | `Europe/Amsterdam` | Timezone |
| `ORION_NODE_NAME` | `netsec-pi-01` | Node identifier for Loki labels |

---

## Troubleshooting

### Suricata not capturing traffic

1. Check interface is UP and in promiscuous mode:
   ```bash
   ip link show ${NETSEC_INTERFACE:-eth1}
   ```

2. Check traffic on interface:
   ```bash
   sudo tcpdump -i ${NETSEC_INTERFACE:-eth1} -c 10
   ```

3. Verify SPAN/mirror port configuration on your switch

### No rules loaded

1. Run rule update:
   ```bash
   ./scripts/suricata-update.sh
   ```

2. Check for rule parse errors:
   ```bash
   docker logs orion-netsec-suricata 2>&1 | grep -i "rule\|error"
   ```

### eve.json not growing

1. Check Suricata is capturing packets:
   ```bash
   docker logs orion-netsec-suricata | grep -i "packet\|capture"
   ```

2. Check stats for captured packets:
   ```bash
   docker exec orion-netsec-suricata cat /var/log/suricata/stats.log | grep capture
   ```

### Promtail not shipping logs

1. Check Loki URL is correct in `.env`

2. Check Promtail logs:
   ```bash
   docker logs orion-netsec-promtail | tail -50
   ```

3. Test Loki connectivity:
   ```bash
   curl -s ${LOKI_URL:-http://loki:3100}/ready
   ```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    NetSec Pi (Raspberry Pi 5)                │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Suricata (network_mode: host, AF_PACKET)              │ │
│  │  • Passive packet capture from ${NETSEC_INTERFACE}     │ │
│  │  • ET Open rules (via suricata-update)                 │ │
│  │  • Writes eve.json to NVMe                             │ │
│  └────────────────────────────────────────────────────────┘ │
│                           │                                  │
│                           ▼                                  │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Promtail                                              │ │
│  │  • Tails eve.json                                      │ │
│  │  • Ships to Loki (CoreSrv)                             │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Node Exporter                                         │ │
│  │  • System metrics on port 19100                        │ │
│  │  • Scraped by Prometheus (CoreSrv)                     │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  NVMe Storage: ${NVME_MOUNT}                           │ │
│  │  ├── suricata/etc/     (config files)                  │ │
│  │  ├── suricata/logs/    (eve.json, stats.log)           │ │
│  │  ├── suricata/lib/     (rules, suricata-update data)   │ │
│  │  └── promtail/         (positions file)                │ │
│  └────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      CoreSrv Node                            │
│  • Loki: Log aggregation                                    │
│  • Prometheus: Metrics collection                           │
│  • Grafana: Dashboards and alerting                         │
└─────────────────────────────────────────────────────────────┘
```

---

## See Also

- [Architecture Overview](../architecture-netsec.md) - Full system architecture
- [Grafana Dashboards](../grafana-dashboards.md) - Dashboard setup
- [CoreSrv Integration](../CORESRV-INTEGRATION.md) - Loki and Prometheus setup
