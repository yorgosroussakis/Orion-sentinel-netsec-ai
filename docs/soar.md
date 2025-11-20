# SOAR-lite: Automated Response Playbooks

## Overview

The SOAR (Security Orchestration, Automation, and Response) module provides automated response capabilities based on security events.

## Architecture

### Components

1. **Playbook Engine** (`engine.py`): Evaluates events against playbook conditions
2. **Action Executor** (`actions.py`): Executes automated actions with safety controls
3. **SOAR Service** (`service.py`): Continuous monitoring loop

### Data Flow

```
Events (Loki) → Playbook Engine → Matched Playbooks → Action Executor → Results (Loki)
```

## Playbook Structure

Playbooks are defined in YAML (default: `config/playbooks.yml`):

```yaml
playbooks:
  - id: unique-playbook-id
    name: Human-Readable Name
    description: What this playbook does
    enabled: true
    match_event_type: intel_match  # Event type to match
    dry_run: true  # SAFETY: Simulate without executing
    priority: 100  # Higher priority runs first
    conditions:
      - field: fields.confidence
        operator: ">="
        value: 0.9
    actions:
      - action_type: BLOCK_DOMAIN
        parameters:
          domain: "{{fields.ioc_value}}"
          reason: "Automated block"
```

## Event Types

Playbooks can match these event types:

- `intel_match`: Threat intelligence matches
- `ai-device-anomaly`: AI-detected device anomalies
- `ai-domain-risk`: Risky domain detections
- `inventory_event`: Device inventory changes
- `change_event`: Behavioral changes
- `honeypot_hit`: Honeypot interactions
- `suricata_alert`: Suricata IDS alerts

## Available Actions

### BLOCK_DOMAIN

Block a domain via Pi-hole.

```yaml
- action_type: BLOCK_DOMAIN
  parameters:
    domain: malicious.example.com
    reason: "Threat intel match"
```

**Requirements**: Pi-hole API access (set `PIHOLE_URL` and `PIHOLE_API_KEY`)

### TAG_DEVICE

Add a tag to a device in inventory.

```yaml
- action_type: TAG_DEVICE
  parameters:
    device_ip: 192.168.1.50
    tag: suspicious
```

### SEND_NOTIFICATION

Send notification (via configured channel).

```yaml
- action_type: SEND_NOTIFICATION
  parameters:
    message: "Alert: Suspicious activity detected"
    severity: high  # low, medium, high, critical
```

**Note**: Notification channels (Signal/Telegram/Email) are TODO

### SIMULATE_ONLY

No-op action for testing.

```yaml
- action_type: SIMULATE_ONLY
  parameters:
    test: true
```

## Safety Features

### Dry Run Mode

**Global Dry Run** (recommended for initial deployment):

```bash
export SOAR_DRY_RUN=1
```

This prevents ALL actions from executing, regardless of playbook settings.

**Per-Playbook Dry Run**:

```yaml
playbooks:
  - id: my-playbook
    dry_run: true  # Only this playbook simulates
```

### Logging

All actions (executed or simulated) are logged:

- Console output shows dry run status
- Loki receives `soar_action` events with execution details

### Priority System

Playbooks with higher `priority` values run first. Use this to:

- Run blocking actions before notifications
- Ensure critical playbooks execute first

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SOAR_DRY_RUN` | `1` | Global dry run mode (1=simulate, 0=execute) |
| `SOAR_POLL_INTERVAL` | `60` | How often to check for events (seconds) |
| `SOAR_PLAYBOOKS_FILE` | `/config/playbooks.yml` | Playbook configuration file |
| `SOAR_ALLOW_EMPTY_PLAYBOOKS` | `0` | Allow starting with no playbooks |
| `LOKI_URL` | `http://localhost:3100` | Loki instance URL |
| `PIHOLE_URL` | `http://192.168.1.2` | Pi-hole instance URL |
| `PIHOLE_API_KEY` | - | Pi-hole API key |

### Running the Service

**Docker Compose** (recommended):

```bash
cd stacks/ai
docker-compose up soar
```

**Standalone**:

```bash
export SOAR_DRY_RUN=1
export SOAR_PLAYBOOKS_FILE=./config/playbooks.yml
python -m orion_ai.soar.service
```

## Example Workflows

### Test Workflow (Safe)

1. Set `SOAR_DRY_RUN=1`
2. Create test playbook with low threshold
3. Trigger test events (manually or wait for real events)
4. Review logs to see what would be executed
5. Adjust playbook conditions

### Production Workflow

1. Test thoroughly in dry run mode
2. Start with high confidence thresholds (e.g., `confidence >= 0.9`)
3. Enable one playbook at a time
4. Monitor for false positives
5. Gradually lower thresholds or enable more playbooks

## Lab Mode

Tag devices with `lab` for testing:

```yaml
conditions:
  - field: fields.device_tags
    operator: contains
    value: lab
```

This allows aggressive actions on lab devices while keeping production devices safe.

## Monitoring

### Grafana Dashboards

Create panels showing:

- SOAR actions executed (by type)
- Dry run vs. executed ratio
- Playbook trigger frequency
- Action success/failure rates

### Loki Queries

```logql
# All SOAR actions
{service="soar", stream="soar_action"}

# Failed actions
{service="soar", stream="soar_action"} | json | success="false"

# Specific playbook
{service="soar", stream="soar_action"} | json | playbook_id="block-high-confidence-domains"
```

## Best Practices

1. **Always start in dry run mode**
2. **Test playbooks in lab environment first**
3. **Use high confidence thresholds initially**
4. **Monitor action logs closely**
5. **Have a rollback plan** (e.g., Pi-hole blacklist backups)
6. **Document playbook changes**
7. **Review false positives regularly**

## Troubleshooting

### Playbooks not triggering

- Check event type matches playbook `match_event_type`
- Verify conditions are correct (check field paths)
- Ensure playbook is `enabled: true`
- Check service logs for parsing errors

### Actions not executing

- Verify `SOAR_DRY_RUN` is set to `0`
- Check playbook `dry_run: false`
- Ensure required credentials are set (Pi-hole API key, etc.)
- Review action execution logs

### High false positive rate

- Increase confidence thresholds
- Add more specific conditions
- Review event data to understand patterns

## Future Enhancements

- [ ] Template variable resolution (`{{field.path}}`)
- [ ] Complex condition logic (AND/OR groups)
- [ ] Scheduled playbook execution
- [ ] External API integrations
- [ ] Action rollback/undo capabilities
- [ ] Machine learning for playbook tuning
