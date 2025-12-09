# Validation & Testing Guide - Orion Sentinel NetSec

This guide provides step-by-step validation procedures to ensure your Orion Sentinel NetSec Node is properly configured and operational.

## Quick Validation Checklist

After deployment, run through this checklist:

- [ ] Docker and Docker Compose are installed
- [ ] Services are running (`docker compose ps`)
- [ ] Suricata is capturing traffic on mirrored interface
- [ ] Promtail is shipping logs to Loki
- [ ] AI services are operational
- [ ] Web UI is accessible
- [ ] Grafana dashboards show data (if using CoreSrv)

---

## Automated Validation

Run the built-in test suite:

```bash
make test
```

This performs automated checks on:
1. Service status
2. Suricata packet capture
3. Promtail log shipping
4. API health

---

## Manual Validation Steps

### 1. Docker Environment

**Check Docker Installation**:
```bash
docker --version
# Expected: Docker version 20.10+

docker compose version
# Expected: Docker Compose version v2.0+
```

**Check Docker Daemon**:
```bash
docker ps
# Should list running containers (if services are started)
```

---

### 2. Service Status

**List all services**:
```bash
docker compose ps
# or
make status
```

**Expected Output** (after `make up-all`):
```
NAME                   IMAGE                      STATUS
orion-api              orion-ai:latest            Up 5 minutes
orion-change-monitor   orion-ai:latest            Up 5 minutes
orion-health-score     orion-ai:latest            Up 5 minutes
orion-inventory        orion-ai:latest            Up 5 minutes
orion-node-exporter    prom/node-exporter:latest  Up 5 minutes
orion-promtail         grafana/promtail:2.9.3     Up 5 minutes
orion-soar             orion-ai:latest            Up 5 minutes
orion-suricata         jasonish/suricata:latest   Up 5 minutes
```

**All services should show "Up"**. If any show "Restarting" or "Exited", investigate logs.

---

### 3. Network Interface

**Verify monitoring interface exists**:
```bash
ip link show
# Look for your MONITOR_IF interface (e.g., eth0, eth1)
```

**Check interface status**:
```bash
ip link show eth0
# Should show "state UP"
```

**If interface is DOWN**:
```bash
sudo ip link set eth0 up
```

**Verify traffic on interface**:
```bash
sudo tcpdump -i eth0 -c 10
# Should show packets from various devices on your network
```

---

### 4. Suricata IDS

#### Check Suricata is Running

```bash
docker ps | grep suricata
# Should show "Up" status
```

#### Verify Packet Capture

**Method 1: Check logs**
```bash
docker logs orion-suricata | grep -i "capture"
```

**Expected Output**:
```
[INFO] Suricata is running in AF_PACKET mode
[INFO] Capture: Using AF_PACKET interface eth0
[INFO] Capture: Received 15234 packets
```

**Method 2: Use suricatasc**
```bash
docker exec orion-suricata suricatasc -c "capture-mode"
```

**Expected Output**:
```
{"message": "AF_PACKET", "return": "OK"}
```

#### Check Suricata Statistics

```bash
docker exec orion-suricata suricatasc -c "dump-counters"
```

Look for:
- `capture.kernel_packets` > 0 (packets received)
- `decoder.pkts` > 0 (packets decoded)
- `detect.alert` (alerts generated)

#### Test Alert Generation

**Trigger a test alert**:

From another device on your network:
```bash
curl http://testmyids.com
```

**Check for alert**:
```bash
docker exec orion-suricata tail -20 /var/log/suricata/eve.json | jq 'select(.event_type=="alert")'
```

**Expected**: You should see an alert for signature ID 2100498 ("GPL ATTACK_RESPONSE id check returned root")

---

### 5. Promtail Log Shipping

#### Check Promtail Status

```bash
docker logs orion-promtail 2>&1 | tail -50
```

**Look for**:
```
level=info msg="POST /loki/api/v1/push (200 OK)"
```

This indicates logs are successfully shipped to Loki.

#### Test Loki Connectivity

```bash
# Replace $LOKI_URL with your actual Loki URL from .env
curl -s ${LOKI_URL}/ready
```

**Expected Output**:
```
ready
```

#### Query Logs in Loki

**Check if Suricata logs are in Loki**:
```bash
curl -G -s "${LOKI_URL}/loki/api/v1/query" \
  --data-urlencode 'query={job="orion-suricata"}' \
  --data-urlencode 'limit=10' | jq .
```

**Expected**: Should return recent Suricata logs

---

### 6. AI Services

#### Check AI Service Health

```bash
# Test API endpoint
curl -s http://localhost:8000/api/health
```

**Expected Output**:
```json
{"status": "healthy", "services": ["soar", "inventory", "health-score", "change-monitor"]}
```

#### Check Individual Service Logs

**SOAR Service**:
```bash
docker logs orion-soar --tail 50
```

Look for:
```
INFO: SOAR service started
INFO: Loaded X playbooks from /config/playbooks.yml
```

**Inventory Service**:
```bash
docker logs orion-inventory --tail 50
```

Look for:
```
INFO: Inventory service started
INFO: Polling Loki every 300 seconds
```

#### Check Database Files

```bash
docker exec orion-inventory ls -lh /data/
```

**Expected**:
```
inventory.db
threat_intel.db
```

---

### 7. Web UI

#### Access Web UI

**SPoG Mode**: 
- Via CoreSrv Traefik: `https://security.local`
- Direct: `http://<pi-ip>:8000`

**Standalone Mode**: 
- `http://localhost:8000`

#### Test API Endpoints

```bash
# Get recent events
curl -s http://localhost:8000/api/events?limit=5 | jq .

# Get device inventory
curl -s http://localhost:8000/api/devices | jq .

# Get health score
curl -s http://localhost:8000/api/health | jq .

# List playbooks
curl -s http://localhost:8000/api/playbooks | jq .
```

---

### 8. Node Exporter (Metrics)

```bash
curl -s http://localhost:9100/metrics | head -20
```

**Expected**: Should show Prometheus metrics like:
```
# HELP node_cpu_seconds_total Seconds the CPUs spent in each mode.
# TYPE node_cpu_seconds_total counter
node_cpu_seconds_total{cpu="0",mode="idle"} 123456.78
...
```

---

### 9. CoreSrv Integration (SPoG Mode)

If using SPoG mode with CoreSrv:

#### Verify Loki on CoreSrv

```bash
# From NetSec Pi or another device
curl -s http://<coresrv-ip>:3100/ready
```

#### Check Grafana Dashboards

1. Access CoreSrv Grafana: `https://grafana.local`
2. Navigate to **Dashboards**
3. Look for:
   - SOC Management
   - DNS & Pi-hole
4. Dashboards should show data from NetSec node

#### Query NetSec Logs in Grafana

1. Go to **Explore** in Grafana
2. Select **Loki** data source
3. Query: `{host="pi-netsec"}`
4. Should see logs from NetSec services

---

## Performance Validation

### CPU Usage

```bash
docker stats --no-stream
```

**Typical Usage** (Raspberry Pi 5):
- Suricata: 15-30% CPU
- AI services: 5-10% CPU each
- Promtail: <5% CPU

**If CPU > 80%**:
- Reduce Suricata rules (disable unused rulesets)
- Increase AI service polling intervals
- Check for runaway processes

---

### Memory Usage

```bash
free -h
```

**Typical Usage** (8 GB Pi):
- Total: 8 GB
- Used: 2-4 GB (with all services)
- Free: 4-6 GB
- Cached: 1-2 GB

**If Memory > 90%**:
- Check for memory leaks: `docker stats`
- Reduce Suricata memcaps in `suricata.yaml`
- Restart services: `make restart`

---

### Disk Usage

```bash
df -h
```

**Log Disk Usage**:
```bash
du -sh /var/lib/docker/volumes/
```

**Typical Growth**:
- Suricata logs: ~500 MB/day (moderate network)
- AI databases: ~50 MB total

**If disk > 80% full**:
- Adjust Loki retention: `LOKI_RETENTION_DAYS` in `.env`
- Clean old volumes: `docker volume prune`

---

## Troubleshooting Common Issues

### Issue: No Packets in Suricata

**Symptoms**:
```bash
docker logs orion-suricata | grep "Capture"
# Shows: Received 0 packets
```

**Diagnosis**:
1. Check port mirroring on switch: See [docs/network-config.md](network-config.md)
2. Verify interface is UP: `ip link show eth0`
3. Check for traffic on interface: `sudo tcpdump -i eth0 -c 10`

**Solutions**:
- Bring interface UP: `sudo ip link set eth0 up`
- Verify switch mirroring is configured correctly
- Check MONITOR_IF in `.env` matches actual interface

---

### Issue: Promtail Not Shipping Logs

**Symptoms**:
```bash
docker logs orion-promtail | grep POST
# No output or errors
```

**Diagnosis**:
1. Test Loki connectivity: `curl ${LOKI_URL}/ready`
2. Check firewall: `sudo iptables -L -n -v`
3. Verify LOKI_URL in `.env`

**Solutions**:
- Ensure CoreSrv Loki is running: `ssh coresrv "docker ps | grep loki"`
- Check network route: `traceroute <coresrv-ip>`
- Verify firewall allows outbound to Loki port 3100

---

### Issue: AI Services Failing

**Symptoms**:
```bash
docker ps | grep orion-soar
# Shows: Restarting
```

**Diagnosis**:
```bash
docker logs orion-soar
# Check for errors
```

**Common Errors**:

**"Connection refused to Loki"**:
- Solution: Verify LOKI_URL is correct and Loki is running

**"Playbooks file not found"**:
- Solution: Ensure `config/playbooks.yml` exists
- Or set `SOAR_ALLOW_EMPTY_PLAYBOOKS=1` in `.env`

**"Permission denied /data/"**:
- Solution: Check volume permissions
- `docker volume inspect soar-data`

---

### Issue: Web UI Not Accessible

**Symptoms**: `curl http://localhost:8000` fails

**Diagnosis**:
```bash
docker ps | grep orion-api
# Check if running

docker logs orion-api
# Check for errors
```

**Solutions**:
- Verify port 8000 is not in use: `sudo netstat -tlnp | grep 8000`
- Check firewall: `sudo iptables -L INPUT -n -v | grep 8000`
- Restart API service: `docker restart orion-api`

---

## Advanced Validation

### Packet Drop Rate

Monitor for packet drops in Suricata:

```bash
docker exec orion-suricata suricatasc -c "dump-counters" | grep -i drop
```

**Acceptable**: <1% packet drop
**High drop rate**: Indicates CPU/memory constraints or misconfiguration

**Solutions**:
- Increase `ring-size` in `suricata.yaml`
- Reduce Suricata rules
- Upgrade hardware

---

### Log Ingestion Rate

Check how many events per second Loki is receiving:

```bash
# Query Loki metrics (if available)
curl -s "${LOKI_URL}/metrics" | grep loki_ingester_streams_created_total
```

---

### End-to-End Flow Test

**Generate test traffic** → **Verify full pipeline**:

1. **Generate HTTP request**:
   ```bash
   # From another device
   curl http://example.com
   ```

2. **Check Suricata sees it**:
   ```bash
   docker exec orion-suricata tail /var/log/suricata/eve.json | grep example.com
   ```

3. **Check Promtail ships it**:
   ```bash
   docker logs orion-promtail 2>&1 | tail -5
   ```

4. **Query in Loki**:
   ```bash
   curl -G "${LOKI_URL}/loki/api/v1/query" \
     --data-urlencode 'query={job="orion-suricata"} |= "example.com"' | jq .
   ```

5. **View in Grafana** (if using CoreSrv):
   - Open Grafana Explore
   - Query: `{job="orion-suricata"} |= "example.com"`

---

## Performance Benchmarks

### Raspberry Pi 5 (8 GB) Baseline

**Traffic Load**: ~500 Mbps network, 1000 devices

| Metric                | Value          |
|-----------------------|----------------|
| CPU Usage             | 25-40%         |
| Memory Usage          | 3.5 GB         |
| Disk I/O              | 10 MB/s write  |
| Suricata Packet Rate  | 5000 pps       |
| Loki Ingestion        | 500 events/sec |
| AI Event Processing   | 100 events/min |

---

## Monitoring Checklist

Daily/weekly checks:

- [ ] Check service status: `make status`
- [ ] Review disk usage: `df -h`
- [ ] Check for errors in logs: `docker compose logs --tail 100`
- [ ] Verify Suricata is capturing: `docker logs orion-suricata | grep Capture`
- [ ] Review Grafana dashboards for anomalies
- [ ] Check health score: `curl http://localhost:8000/api/health`

---

## Automated Monitoring

Set up cron job for daily validation:

```bash
# Add to crontab
crontab -e
```

```cron
# Daily health check at 6 AM
0 6 * * * cd /home/pi/Orion-sentinel-netsec-ai && make test >> /var/log/orion-health.log 2>&1
```

---

## Support & Troubleshooting

If issues persist after following this guide:

1. **Collect diagnostics**:
   ```bash
   ./scripts/collect-diagnostics.sh  # (If available)
   ```

2. **Review logs**:
   ```bash
   docker compose logs > orion-logs.txt
   ```

3. **Check GitHub Issues**: https://github.com/orionsentinel/Orion-sentinel-netsec-ai/issues

4. **Open new issue** with:
   - Description of problem
   - Steps to reproduce
   - Output of `make test`
   - Relevant logs

---

**Last Updated**: 2024-12-09
