# Device Inventory & Fingerprinting

## Overview

The inventory module tracks all devices on the network, classifies them, and maintains metadata for security analysis.

## Components

1. **Inventory Store** (`store.py`): SQLite database for device persistence
2. **Device Collector** (`collector.py`): Extracts device info from logs
3. **Device Fingerprinter** (`fingerprinting.py`): Classifies device types
4. **Inventory Service** (`service.py`): Continuous inventory updates

## Device Model

Each device has:

- **Identity**: IP, MAC, hostname
- **Classification**: Device type, tags, owner
- **Activity**: First/last seen, connection patterns
- **Risk**: Risk score, anomaly count, threat intel matches

## Device Types

The fingerprinter can identify:

- Smart TVs (Chromecast, Apple TV, Samsung, etc.)
- Printers
- NAS devices
- IP cameras
- Smart speakers
- Phones/tablets
- IoT devices
- Raspberry Pi
- Unknown

## Tagging System

Devices can have multiple tags:

- **Type tags**: `iot`, `media`, `security`, `office`, `storage`
- **Environment tags**: `lab`, `production`, `family`, `guest`
- **Risk tags**: `high-risk`, `medium-risk`, `anomalous`, `threat-indicator`
- **Custom tags**: Any user-defined tag

## Fingerprinting Heuristics

### Port-based

Devices are classified by open ports:

- Ports 8008, 8009 → Chromecast/Google TV
- Port 631 → Printer
- Ports 445, 139, 548 → NAS

### Destination-based

Devices are classified by domains they contact:

- `googleapis.com`, `googleusercontent.com` → Google device
- `apple.com`, `icloud.com` → Apple device
- `amazon.com`, `amazonaws.com` → Amazon device

### Vendor-based

MAC address OUI lookup identifies vendors.

## Data Collection

The collector extracts device information from:

1. **Suricata events**: Source/dest IPs, ports, protocols
2. **DNS queries**: Client IPs, queried domains
3. **Threat intel events**: Related IPs
4. **AI anomaly events**: Device behaviors

## Storage

Devices are stored in SQLite (`/data/inventory.db`) with indexes for:

- Last seen (for activity queries)
- Tags (for filtering)
- Risk score (for threat hunting)

## API Operations

```python
from orion_ai.inventory.store import InventoryStore

store = InventoryStore()

# Get device
device = store.get_device("192.168.1.50")

# Tag device
store.tag_device("192.168.1.50", "lab")

# List devices
devices = store.list_devices(limit=100)

# Get new devices
new = store.list_new_devices_since(datetime.utcnow() - timedelta(days=7))

# Get stats
stats = store.get_stats()
```

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `INVENTORY_POLL_INTERVAL` | `300` | Update interval (seconds) |
| `INVENTORY_DB_PATH` | `/data/inventory.db` | Database file path |
| `LOKI_URL` | `http://localhost:3100` | Loki instance URL |

## Running the Service

```bash
cd stacks/ai
docker-compose up inventory
```

## Integration with SOAR

SOAR playbooks can:

- Tag devices automatically
- Filter actions by device tags
- React to new device events

Example:

```yaml
- action_type: TAG_DEVICE
  parameters:
    device_ip: "{{fields.device_ip}}"
    tag: suspicious
```

## Grafana Dashboards

Recommended panels:

- Total devices over time
- New devices (last 7 days)
- Unknown/untagged devices
- Device type breakdown (pie chart)
- High-risk devices
- Device activity heatmap

## Loki Queries

```logql
# New device events
{service="inventory", stream="inventory_event"} | json | event_type="new_device"

# Devices by tag
{service="inventory"} | json | tags=~".*lab.*"
```

## Best Practices

1. **Tag devices promptly**: Helps with risk assessment
2. **Review unknown devices**: Investigate unclassified devices
3. **Set device owners**: Accountability for security
4. **Monitor new devices**: Alert on unexpected additions
5. **Periodic audits**: Review inventory for inactive devices

## Future Enhancements

- [ ] MAC vendor lookup (OUI database)
- [ ] Active fingerprinting (nmap integration)
- [ ] DHCP log integration
- [ ] Network segment awareness
- [ ] Device relationship mapping
- [ ] Automated type detection improvement via ML
