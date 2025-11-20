# Security Health Score

## Overview

The health score provides a single 0-100 metric representing the overall security posture of your network.

## Score Components

The score is calculated from four weighted components:

| Component | Weight | Description |
|-----------|--------|-------------|
| Inventory Health | 25% | Device classification and management |
| Threat Landscape | 35% | Active threats and alerts |
| Change Management | 20% | Behavioral changes and new devices |
| Hygiene Practices | 20% | Security best practices |

## Scoring Formula

### Overall Score

```
Score = (Inventory × 0.25) + (Threat × 0.35) + (Change × 0.20) + (Hygiene × 0.20)
```

### Inventory Score (0-100)

Starts at 100, penalties for:

- **Unknown devices**: -30 points (scaled by ratio)
- **Untagged devices**: -20 points (scaled by ratio)
- **High-risk devices**: -50 points (scaled by ratio)

### Threat Score (0-100)

Starts at 100, penalties for:

- **High-severity anomalies (24h)**: -5 each (max -40)
- **Intel matches (24h)**: -10 each (max -30)
- **Intel matches (7d)**: -2 each (max -20)
- **Suricata alerts (24h)**: -1 each (max -10)
- **Unresolved incidents**: -5 each (max -20)

### Change Score (0-100)

Starts at 100, penalties for:

- **New devices (7d)**: -5 each (max -30)
- **High-risk changes (24h)**: -10 each (max -70)

### Hygiene Score (0-100)

Based on manual flags:

- **Backups OK**: +40 points
- **Updates current**: +40 points
- **Firewall enabled**: +20 points

## Letter Grades

| Score | Grade |
|-------|-------|
| 90-100 | A |
| 80-89 | B |
| 70-79 | C |
| 60-69 | D |
| 0-59 | F |

## Input Metrics

### Automated Metrics

Collected automatically from:

- **Inventory database**: Device counts, classifications, risk scores
- **Loki**: Event counts (anomalies, alerts, intel matches)
- **Change monitor**: New devices, changes

### Manual Metrics

Set via configuration file (`/config/hygiene.yml`):

```yaml
hygiene:
  backups_ok: true
  updates_current: true
  firewall_enabled: true
```

## Recommendations

The health score service generates actionable recommendations based on metrics:

- "Tag 5 unknown devices"
- "Investigate 2 high-severity anomalies"
- "Review 3 recent threat intel matches"
- "Set up or verify backup system"

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `HEALTH_SCORE_INTERVAL_HOURS` | `1` | Calculation frequency |
| `LOKI_URL` | `http://localhost:3100` | Loki instance URL |

## Running the Service

```bash
cd stacks/ai
docker-compose up health-score
```

## Output

Health scores are emitted to Loki every hour:

```json
{
  "score": 82,
  "grade": "B",
  "inventory_score": 85.0,
  "threat_score": 90.0,
  "change_score": 75.0,
  "hygiene_score": 80.0,
  "recommendations": [
    "Tag 3 unknown devices",
    "Review 1 high-severity anomaly"
  ]
}
```

## Grafana Dashboard

Create a dashboard showing:

### Primary Panel

- **Gauge**: Current score (0-100) with color coding
  - 90-100: Green
  - 70-89: Yellow
  - 0-69: Red

### Secondary Panels

- **Time series**: Score history (last 30 days)
- **Bar chart**: Component scores breakdown
- **Table**: Current recommendations
- **Stat panels**: Individual component scores

### Example Dashboard JSON

```json
{
  "panels": [
    {
      "title": "Security Health Score",
      "type": "gauge",
      "targets": [
        {
          "expr": "{service=\"health_score\"} | json | score"
        }
      ],
      "options": {
        "reduceOptions": {
          "values": false,
          "calcs": ["lastNotNull"]
        },
        "thresholds": {
          "mode": "absolute",
          "steps": [
            {"color": "red", "value": 0},
            {"color": "yellow", "value": 70},
            {"color": "green", "value": 90}
          ]
        }
      }
    }
  ]
}
```

## Loki Queries

```logql
# Current score
{service="health_score", stream="health_score"} | json | score

# Score history
{service="health_score"} | json | line_format "{{.score}}"

# Recommendations
{service="health_score"} | json | line_format "{{.recommendations}}"

# Component breakdown
{service="health_score"} | json | line_format "Inv:{{.inventory_score}} Thr:{{.threat_score}}"
```

## Interpretation

### Score 90-100 (Grade A)

- Excellent security posture
- All devices classified
- Minimal active threats
- Good hygiene practices

**Action**: Maintain current practices

### Score 80-89 (Grade B)

- Good security posture
- Minor issues to address
- Low threat activity

**Action**: Address recommendations

### Score 70-79 (Grade C)

- Acceptable security
- Several areas need attention
- Moderate risk

**Action**: Prioritize recommendations

### Score 60-69 (Grade D)

- Poor security posture
- Multiple significant issues
- Elevated risk

**Action**: Immediate attention required

### Score 0-59 (Grade F)

- Critical security issues
- High threat activity or major gaps
- Serious risk

**Action**: Emergency response needed

## Tuning

Adjust weights in `calculator.py` based on your priorities:

```python
WEIGHTS = {
    "inventory": 0.25,  # Increase if device management is critical
    "threat": 0.35,     # Increase if threat detection is priority
    "change": 0.20,     # Increase if change control is important
    "hygiene": 0.20,    # Increase if compliance is key
}
```

## Best Practices

1. **Set realistic hygiene flags**: Don't mark backups OK if they're not
2. **Monitor score trends**: Score direction matters more than absolute value
3. **Act on recommendations**: Use them as a work queue
4. **Review component scores**: Identify weak areas
5. **Set improvement goals**: Target specific grade improvements

## Example Scenarios

### Scenario 1: New Device Surge

- 10 new unknown devices appear
- Score drops from 85 to 70
- Inventory component: 60/100
- Recommendation: "Tag 10 unknown devices"

**Response**: Investigate and classify devices

### Scenario 2: Threat Event

- High-confidence intel match detected
- 3 high-severity anomalies
- Score drops from 88 to 75
- Threat component: 65/100

**Response**: Investigate threats, execute playbooks

### Scenario 3: Neglected Hygiene

- Backups haven't been verified
- Updates overdue
- Score: 70 (C)
- Hygiene component: 20/100

**Response**: Update systems, verify backups

## Future Enhancements

- [ ] Historical comparison (vs. last week/month)
- [ ] Peer comparison (if multiple sites)
- [ ] Predictive scoring (trend analysis)
- [ ] Custom weighting per environment
- [ ] Compliance framework mapping (NIST, CIS, etc.)
- [ ] Score breakdown by device/network segment
