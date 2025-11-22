# Observability with Loki & Grafana

This guide explains how security events are stored, queried, and visualized in Orion Sentinel.

## How SecurityEvents are Stored in Loki

Orion Sentinel uses a unified `SecurityEvent` model for all security-related events. Events are pushed to Loki's push API in the following format:

### Labels (for indexing and fast filtering)

Labels are key-value pairs used by Loki for indexing. They enable fast filtering but should be low-cardinality (not too many unique values):

```
app="orion-sentinel"
event_type="ai_detection" | "suricata_alert" | "soar_action" | "health_status" | "intel_match" | ...
severity="info" | "low" | "medium" | "high" | "critical"
component="inventory-service" | "soar-service" | "suricata" | ... (for health events)
device_id="192.168.1.50" (when applicable)
```

### Log Line (full event as JSON)

The actual event data is stored as a JSON log line with fields like:

```json
{
  "timestamp": "2024-01-15T10:30:45.123456Z",
  "event_type": "ai_detection",
  "severity": "high",
  "src_ip": "192.168.1.50",
  "dst_ip": "93.184.216.34",
  "domain": "evil-tracker.example.com",
  "risk_score": 0.92,
  "reasons": ["Domain matches DGA pattern", "Contacted from multiple devices"],
  "ti_sources": ["URLhaus", "OTX"],
  "detection_name": "Suspicious Domain Access",
  ...
}
```

## Example LogQL Queries

Log

QL is Loki's query language. Here are common queries for Orion Sentinel events:

### Basic Queries

```logql
# All Orion Sentinel events
{app="orion-sentinel"}

# Events by type
{app="orion-sentinel", event_type="ai_detection"}
{app="orion-sentinel", event_type="suricata_alert"}
{app="orion-sentinel", event_type="soar_action"}
{app="orion-sentinel", event_type="health_status"}

# Events by severity
{app="orion-sentinel", severity="critical"}
{app="orion-sentinel", severity=~"high|critical"}  # regex match

# Events for a specific device
{app="orion-sentinel", device_id="192.168.1.50"}
```

### JSON Filtering

Use `| json` to parse JSON fields and filter on them:

```logql
# High-risk AI detections
{app="orion-sentinel", event_type="ai_detection"} | json | risk_score > 0.9

# Events mentioning a specific domain
{app="orion-sentinel"} | json | domain =~ "evil.*"

# SOAR actions that were executed (not dry-run)
{app="orion-sentinel", event_type="soar_action"} | json | action_status = "executed"

# Health events showing components down
{app="orion-sentinel", event_type="health_status"} | json | health_status = "down"

# Suricata alerts in a specific category
{app="orion-sentinel", event_type="suricata_alert"} | json | suricata_category = "Malware"
```

### Aggregations

Count, sum, and group events:

```logql
# Count of events over time by type
sum by (event_type) (count_over_time({app="orion-sentinel"}[5m]))

# Count of high/critical events in last 24h
sum(count_over_time({app="orion-sentinel", severity=~"high|critical"}[24h]))

# Top risky devices (by max risk score)
topk(10, max by (device_id) (max_over_time({app="orion-sentinel", event_type="ai_detection"} | json | unwrap risk_score [24h])))
```

### Text Search

Use `|=` for substring search, `!=` for negation:

```logql
# Events containing "malware" anywhere in the log line
{app="orion-sentinel"} |= "malware"

# Events NOT containing "test"
{app="orion-sentinel"} != "test"

# AI detections with threat intel sources
{app="orion-sentinel", event_type="ai_detection"} |= "ti_sources"
```

## Grafana Dashboards

Orion Sentinel includes three pre-built dashboards. You can import them via file provisioning or the Grafana UI.

### 1. Orion Sentinel - Security Overview

**File**: `grafana/dashboards/orion-security-overview.json`

**Purpose**: High-level overview of all security events across the network.

**Panels**:
- **Events Over Time by Type**: Time-series showing event count grouped by `event_type`
- **High/Critical (24h)**: Stat panel with count of high/critical severity events
- **Total Events (1h)**: Overall event volume
- **Events by Severity**: Pie chart showing distribution across severity levels
- **Recent Events**: Table with last 100 events (timestamp, type, severity, device, domain, risk score)

**Use Cases**:
- "What's happening on my network right now?"
- "How many high-risk events did I have today?"
- "Which event types are most common?"

### 2. Orion Sentinel - Device View

**File**: `grafana/dashboards/orion-device-view.json`

**Purpose**: Deep dive into a specific device's security events.

**Template Variable**:
- `device`: Select from all devices seen in events (populated from `device_id` label)

**Panels**:
- **Events Over Time by Severity**: Time-series for the selected device, stacked by severity
- **Events by Type**: Pie chart showing event type distribution for this device
- **Top Domains / Indicators**: Table of domains/indicators accessed by this device, with risk scores
- **Suricata Alerts**: Table of IDS alerts for this device (signature, category, IPs, ports)
- **AI Detections & Threat Intel**: Table of AI-detected risks and threat intel matches

**Use Cases**:
- "Which devices are the noisiest?"
- "What's this IoT device talking to?"
- "Has this laptop been flagged by AI detection?"

### 3. Orion Sentinel - SOC Wallboard

**File**: `grafana/dashboards/orion-soc-wallboard.json`

**Purpose**: Big-screen "at-a-glance" view of security posture for a home/lab SOC.

**Layout** (designed for 1080p/1440p TV):
- **Top Row (Big Stats)**:
  - High/Critical events (24h)
  - Active devices seen (24h)
  - SOAR actions executed (24h)
  - Components down (last 10 min)
- **Middle Row**:
  - Events over time (stacked area chart by type)
  - Top risky devices (table with detection count and max risk score)
- **Bottom Row**:
  - Recent high-risk detections (table)
  - Suricata alerts by category (bar chart, last 1h)
  - Component health status (table with color-coded status)

**Template Variable**:
- `severity`: Filter events by severity (multi-select)

**Use Cases**:
- "Is anything on fire right now?"
- "Which device is causing the most alerts?"
- "Are all system components healthy?"

**Auto-refresh**: 10 seconds (configurable via Grafana UI)

## Importing Dashboards

### Method 1: File Provisioning (Automatic)

If you're using Grafana's provisioning feature (typically in Docker deployments), place the JSON files in your Grafana dashboards directory:

```bash
# Example for Docker Compose
cp grafana/dashboards/*.json /path/to/grafana/provisioning/dashboards/

# Or mount as a volume in docker-compose.yml:
volumes:
  - ./grafana/dashboards:/etc/grafana/provisioning/dashboards
```

Grafana will automatically load them on startup.

### Method 2: Manual Import via UI

1. Open Grafana (`http://localhost:3000`)
2. Go to **Dashboards** → **Import**
3. Click **Upload JSON file**
4. Select a dashboard JSON file (e.g., `orion-security-overview.json`)
5. Choose your Loki datasource from the dropdown
6. Click **Import**

Repeat for each dashboard.

### Method 3: API Import

```bash
# Import via Grafana API
GRAFANA_URL="http://localhost:3000"
GRAFANA_API_KEY="your-api-key"  # Create one in Grafana settings

curl -X POST "$GRAFANA_URL/api/dashboards/db" \
  -H "Authorization: Bearer $GRAFANA_API_KEY" \
  -H "Content-Type: application/json" \
  -d @grafana/dashboards/orion-security-overview.json
```

## Querying Loki from the Command Line

You can query Loki directly using `curl` or `logcli`:

### Using curl

```bash
LOKI_URL="http://localhost:3100"

# Query for recent events
curl -G "$LOKI_URL/loki/api/v1/query_range" \
  --data-urlencode 'query={app="orion-sentinel"}' \
  --data-urlencode 'limit=100' \
  --data-urlencode 'start='$(date -d '1 hour ago' +%s)000000000 \
  | jq '.data.result'

# Get label values (e.g., all event types)
curl "$LOKI_URL/loki/api/v1/label/event_type/values" | jq
```

### Using logcli

Install `logcli` (Loki's official CLI):

```bash
# Install logcli
go install github.com/grafana/loki/cmd/logcli@latest

# Set Loki URL
export LOKI_ADDR=http://localhost:3100

# Query recent events
logcli query '{app="orion-sentinel"}'

# Query with filters
logcli query '{app="orion-sentinel", event_type="ai_detection"} | json | risk_score > 0.8'

# Tail logs in real-time
logcli query --tail '{app="orion-sentinel"}'
```

## Best Practices

1. **Use labels for high-level filtering**: Labels are indexed and fast. Use them for broad categories (`event_type`, `severity`, `device_id`).

2. **Parse JSON for detailed filtering**: Use `| json` to access fields within the log line for fine-grained queries.

3. **Limit time ranges**: Querying large time ranges can be slow. Start with narrow ranges (last hour, last day) and expand as needed.

4. **Aggregate for dashboards**: Use `count_over_time()`, `sum()`, and `rate()` for dashboard panels instead of raw logs.

5. **Test queries in Grafana Explore**: Use the Explore view to test LogQL queries before adding them to dashboards.

## Troubleshooting

### No data in dashboards

**Check**:
1. Loki datasource is configured correctly in Grafana
2. Events are actually being sent to Loki (`orionctl send-test-event`)
3. Time range in dashboard includes recent data
4. Label names match (e.g., `app="orion-sentinel"`, not `app="orion"`)

**Debug**:
```bash
# Test Loki connectivity
curl http://localhost:3100/ready

# Query for any labels
curl http://localhost:3100/loki/api/v1/labels | jq

# Send a test event
orionctl send-test-event

# Query for test event
curl -G 'http://localhost:3100/loki/api/v1/query' \
  --data-urlencode 'query={app="orion-sentinel", component="orionctl"}' \
  --data-urlencode 'limit=10' | jq
```

### Queries are slow

**Tips**:
- Use more specific labels in your query (e.g., add `event_type`)
- Reduce time range
- Use `| json` only when needed (it's more expensive than label filters)
- Consider Loki retention and compaction settings

### Events not showing up immediately

- Loki may have a small ingestion delay (usually < 1 second)
- Check dashboard refresh interval (bottom-right in Grafana)
- Try manual refresh or set auto-refresh to 10-30 seconds

## See Also

- [orionctl CLI](orionctl.md) - Operational CLI with health checks
- [Architecture](architecture.md) - How events flow through the system
- [SOAR Playbooks](soar.md) - Automated response based on events
- [Web UI](web-ui.md) - Alternative event viewing interface
