# Grafana Dashboards for Orion Sentinel NetSec

This directory contains pre-built Grafana dashboards for visualizing NetSec node metrics and security events.

## Dashboards Included

### 1. SOC Management Dashboard
**File**: `soc-management.json`

**Purpose**: High-level security operations center view

**Panels**:
- Security Health Score (0-100)
- Recent High-Risk Events
- Event Timeline
- Top Blocked Domains
- Device Risk Distribution
- SOAR Action Summary

**Recommended Refresh**: 30s

---

### 2. DNS & Pi-hole Dashboard
**File**: `dns-pihole.json`

**Purpose**: DNS query analysis and Pi-hole integration metrics

**Panels**:
- Total DNS Queries
- Block Rate Percentage
- Top Queried Domains
- Top Blocked Domains
- Query Types Distribution
- Queries by Device
- Temporal Query Patterns

**Recommended Refresh**: 1m

---

## Installation on CoreSrv (SPoG Mode)

### Method 1: Dashboard Provisioning (Recommended)

1. **Copy dashboards to CoreSrv**:
   ```bash
   # Example: Copy to CoreSrv Grafana provisioning directory
   # Adjust path based on your CoreSrv setup
   scp *.json user@coresrv:/var/lib/grafana/dashboards/
   
   # Or if using Docker volume:
   # scp *.json user@coresrv:/path/to/docker/volumes/grafana-provisioning/_data/dashboards/
   ```

2. **Ensure provisioning is configured** in CoreSrv's Grafana `grafana.ini`:
   ```ini
   [dashboards]
   path = /path/to/grafana/provisioning/dashboards
   ```

3. **Restart Grafana** on CoreSrv:
   ```bash
   docker restart grafana
   ```

Dashboards will auto-load on Grafana startup.

### Method 2: Manual Import

1. **Access CoreSrv Grafana**: https://grafana.local (or http://coresrv-ip:3000)

2. **Import Dashboard**:
   - Click **+** → **Import**
   - Click **Upload JSON file**
   - Select dashboard JSON file
   - Choose Loki data source
   - Click **Import**

3. **Repeat for each dashboard**

---

## Installation for Standalone Mode

If running Orion Sentinel in standalone mode with local Grafana:

1. **Access Local Grafana**: http://localhost:3000

2. **Configure Loki Data Source** (if not already done):
   - Go to **Configuration** → **Data Sources**
   - Add **Loki**
   - URL: `http://loki:3100`
   - Save & Test

3. **Import Dashboards** using Method 2 above

---

## Customization

### Modifying Dashboards

1. Open dashboard in Grafana
2. Click ⚙️ (Settings) → **JSON Model**
3. Edit JSON
4. Click **Save changes**
5. Export updated JSON: **Share** → **Export** → **Save to file**

### Common Customizations

**Change Time Range**:
```json
"time": {
  "from": "now-24h",
  "to": "now"
}
```

**Adjust Refresh Rate**:
```json
"refresh": "30s"
```

**Update Data Source**:
Replace all occurrences of `"datasource": "Loki"` with your data source name.

---

## Dashboard Variables

Dashboards support Grafana variables for filtering:

- `$timeFilter` - LogQL time filter
- `$host` - NetSec node hostname (from `NODE_NAME` env var)
- `$severity` - Event severity filter (high, medium, low)

To use variables in queries:
```logql
{host="$host"} |= "SecurityEvent" | json | severity="$severity"
```

---

## Creating New Dashboards

### Best Practices

1. **Use Loki as Data Source**: All NetSec logs go to Loki
2. **Label Events Properly**: Ensure LogQL queries use correct labels
3. **Add Descriptions**: Help operators understand each panel
4. **Set Meaningful Thresholds**: Use colors (green/yellow/red) for risk levels
5. **Include Links**: Link to related dashboards or Web UI

### Example LogQL Queries

**Recent Security Events**:
```logql
{job="orion-ai"} |= "SecurityEvent" | json | __error__=""
```

**Alert Count by Severity**:
```logql
sum by (severity) (count_over_time({job="orion-suricata"} |= "alert" [5m]))
```

**Device Risk Scores**:
```logql
{job="orion-ai", service="inventory"} |= "risk_score" | json
```

---

## Troubleshooting

### Dashboard Shows "No Data"

1. **Check Loki Connection**: Grafana → Configuration → Data Sources → Loki → Test
2. **Verify Logs in Loki**: Run LogQL query in Explore view
3. **Check Time Range**: Ensure time range covers period with data
4. **Inspect Query**: Use Query Inspector to see actual LogQL query

### Wrong Data Source

If dashboard shows "Data source not found":
1. Edit dashboard JSON
2. Replace data source UID: Find `"datasource": {"uid": "..."}` and update UID
3. Or set to `"datasource": {"type": "loki", "uid": "$datasource"}`

### Panel Errors

Check Grafana logs:
```bash
docker logs grafana 2>&1 | grep -i error
```

---

## Export & Backup

**Export All Dashboards**:
```bash
# On CoreSrv Grafana
curl -H "Authorization: Bearer YOUR_API_KEY" \
  http://localhost:3000/api/dashboards/db/soc-management -o soc-management.json
```

**Backup Directory**:
```bash
tar -czf grafana-dashboards-backup-$(date +%Y%m%d).tar.gz grafana_dashboards/
```

---

## Updates & Versioning

Dashboard versions are managed in this repository. To update:

1. Pull latest code: `git pull origin main`
2. Review `grafana_dashboards/` for new/updated dashboards
3. Re-import to Grafana using method above

---

## Support

For dashboard issues or feature requests:
- Open an issue: https://github.com/orionsentinel/Orion-sentinel-netsec-ai/issues
- See main README: [../README.md](../README.md)

---

**Last Updated**: 2024-12-09
