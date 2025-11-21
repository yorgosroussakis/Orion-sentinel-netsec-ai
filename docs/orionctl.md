# orionctl - Operational CLI

`orionctl` is a lightweight command-line tool for day-2 operations and health checks in Orion Sentinel.

## Installation

The CLI is included with Orion Sentinel. If you've installed the package, you can run it as:

```bash
# As a Python module
python -m orion_ai.cli.orionctl <command>

# Or using the wrapper script
./scripts/orionctl <command>

# Or if installed system-wide
orionctl <command>
```

## Commands

### `orionctl doctor`

Run health checks and diagnostics on the Orion Sentinel system.

**What it checks:**
- Loki connectivity (can we reach the Loki API?)
- Loki query functionality (can we query logs?)
- Grafana connectivity (if `GRAFANA_URL` is set)
- Future: Suricata, AI services, SOAR status

**Usage:**

```bash
orionctl doctor

# With custom timeout
orionctl doctor --timeout 5.0
```

**Example output:**

```
Orion Sentinel Doctor
============================================================

Loki (http://localhost:3100):                [OK] Loki is ready
Loki query test:                             [OK] Query successful (3 stream(s) in last 5m)
Grafana (http://localhost:3000):            [OK] Grafana is healthy
Suricata:                                    [UNKNOWN] not checked in this version
AI services:                                 [UNKNOWN] not checked in this version

✓ All critical checks passed
```

**Exit codes:**
- `0`: All critical checks passed
- `1`: One or more critical checks failed (e.g., Loki unreachable)

### `orionctl send-test-event`

Send a test `SecurityEvent` to Loki to verify the event pipeline is working.

**What it does:**
- Creates a `health_status` event with `component="orionctl"`
- Pushes it to Loki via the Loki push API
- Confirms the event was sent successfully

**Usage:**

```bash
orionctl send-test-event
```

**Example output:**

```
Sending test event to Loki at http://localhost:3100...
✓ Test event sent successfully at 2024-01-15T10:30:45.123456

You can view it in Grafana or query Loki:
  {app="orion-sentinel", event_type="health_status", component="orionctl"}
```

**Use cases:**
- Test that Loki is receiving events
- Verify the event pipeline after configuration changes
- Generate sample events for dashboard testing

### `orionctl version`

Show version information for Orion Sentinel and the CLI.

**Usage:**

```bash
orionctl version
```

**Example output:**

```
orionctl version 0.2.0
Orion Sentinel - AI-assisted SOC-in-a-box for home labs & small offices
```

## Environment Variables

`orionctl` respects these environment variables:

- **`LOKI_URL`** or **`ORION_LOKI_URL`**: Loki base URL (default: `http://localhost:3100`)
- **`GRAFANA_URL`**: Grafana URL for health checks (optional)

**Example:**

```bash
export LOKI_URL=http://loki:3100
export GRAFANA_URL=http://grafana:3000
orionctl doctor
```

## Integration with Services

### Health Reporting

Services can use the `HealthReporter` class to periodically emit health status events that show up in Grafana dashboards (especially the SOC Wallboard).

**Python example:**

```python
from orion_ai.health import HealthReporter
import asyncio

async def main():
    # Create a health reporter for your service
    reporter = HealthReporter(
        component="my-service",
        loki_url="http://localhost:3100",
        interval_seconds=300  # Report every 5 minutes
    )
    
    # Start periodic reporting
    await reporter.start()
    
    # In your service loop, update health status:
    try:
        # Do some work...
        if everything_ok:
            reporter.report_healthy(["All systems operational"])
        else:
            reporter.report_degraded(["Database connection slow"])
    except Exception as e:
        reporter.report_down([f"Critical error: {e}"])
    
    # ... service continues running ...
    
    # On shutdown:
    await reporter.stop()

if __name__ == "__main__":
    asyncio.run(main())
```

**One-off health check:**

```python
from orion_ai.health import emit_health_check
import asyncio

async def check_and_report():
    await emit_health_check(
        component="backup-job",
        health_status="healthy",
        reasons=["Backup completed successfully"],
    )

asyncio.run(check_and_report())
```

### Viewing Health Events

Health events appear in:

1. **Grafana SOC Wallboard** (`orion-soc-wallboard` dashboard):
   - "Component Health" panel shows latest status per component
   - Color-coded: green (healthy), yellow (degraded), red (down)

2. **Loki queries**:
   ```
   {app="orion-sentinel", event_type="health_status"}
   {app="orion-sentinel", event_type="health_status", component="inventory-service"}
   {app="orion-sentinel", event_type="health_status"} | json | health_status="down"
   ```

3. **Web UI** (Events page):
   - Filter by `event_type=health_status`
   - See component status over time

## Troubleshooting

### `orionctl doctor` fails with "Cannot connect to Loki"

**Possible causes:**
- Loki is not running
- Wrong `LOKI_URL` (check env var or default)
- Firewall/network issue

**Steps to debug:**
```bash
# Check Loki is running
docker ps | grep loki

# Test Loki manually
curl http://localhost:3100/ready

# Check environment
echo $LOKI_URL
```

### `orionctl send-test-event` succeeds but I don't see the event in Grafana

**Possible causes:**
- Time range in Grafana is too narrow (event just happened—try "Last 5 minutes")
- Wrong Loki datasource in Grafana
- Label mismatch in your query

**Steps to debug:**
```bash
# Query Loki directly
curl -G 'http://localhost:3100/loki/api/v1/query' \
  --data-urlencode 'query={app="orion-sentinel", component="orionctl"}' \
  --data-urlencode 'limit=10'

# Check in Grafana Explore:
# - Datasource: Loki
# - Query: {app="orion-sentinel", component="orionctl"}
# - Time range: Last 15 minutes
```

### Health events not appearing on the SOC Wallboard

**Check:**
1. Component name matches exactly (case-sensitive)
2. Service is actually calling `reporter.emit_health_event()` or `reporter.start()`
3. Loki is reachable from the service container
4. Dashboard time range includes recent events

## Future Enhancements

Planned additions to `orionctl`:

- **`orionctl logs <component>`**: Tail logs for a specific component from Loki
- **`orionctl events --severity high`**: Query and display recent events with filters
- **`orionctl playbook list`**: List SOAR playbooks and their status
- **`orionctl playbook run <id>`**: Manually trigger a playbook
- **`orionctl status`**: Quick one-line status summary
- **`orionctl doctor --full`**: Deep health checks including Suricata, AI models, SOAR

## See Also

- [Architecture](architecture.md) - Overall system design
- [Observability](observability.md) - Grafana dashboards and Loki queries
- [SOAR Playbooks](soar.md) - Automated response configuration
- [Web UI](web-ui.md) - Web dashboard for events and devices
