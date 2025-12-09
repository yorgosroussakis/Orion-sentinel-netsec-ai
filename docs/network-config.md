# Network Configuration Guide - Port Mirroring & Firewall Setup

This guide covers the network infrastructure requirements for deploying Orion Sentinel NetSec Node, including switch port mirroring (SPAN) configuration and firewall rules.

## Overview

The NetSec Node operates as a **passive network sensor** that monitors traffic via port mirroring. It does not sit inline with network traffic and cannot disrupt connectivity if it fails.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Network Topology                        │
│                                                                 │
│  ┌──────────────┐         ┌─────────────┐        ┌──────────┐ │
│  │   Internet   │         │   Router    │        │  Switch  │ │
│  │   Modem      │────────▶│  (Gateway)  │───────▶│ Managed  │ │
│  └──────────────┘         │ 192.168.x.1 │        │          │ │
│                           └─────────────┘        │ Port     │ │
│                                                  │ Mirror   │ │
│                                                  │ Config   │ │
│                                                  └────┬─────┘ │
│                                                       │       │
│                                    ┌──────────────────┴─────────────┐
│                                    │                 │              │
│                              Mirror Source     Mirror Dest    LAN Devices
│                                    │                 │              │
│                             ┌──────▼────┐     ┌──────▼────┐   ┌────▼─────┐
│                             │  Uplink   │     │  NetSec   │   │ Laptop   │
│                             │  Port 1   │     │  Pi Port  │   │ Phone    │
│                             │ (Trunked) │     │  Port 24  │   │ NAS      │
│                             └───────────┘     │  (Mirror) │   │ ...      │
│                                               └───────────┘   └──────────┘
│                                                     │
│                                                     │
│                                              ┌──────▼────────┐
│                                              │  NetSec Pi 5  │
│                                              │  (Suricata)   │
│                                              │  192.168.x.50 │
│                                              └───────────────┘
└─────────────────────────────────────────────────────────────────┘
```

---

## Port Mirroring (SPAN) Configuration

Port mirroring copies network traffic from one or more source ports to a destination port where the NetSec Pi is connected.

### Terminology

- **SPAN**: Switched Port Analyzer (Cisco term)
- **Port Mirroring**: Generic term used by most vendors
- **Source Port**: Port(s) whose traffic you want to monitor
- **Destination Port**: Port where NetSec Pi is connected
- **Direction**: Ingress (incoming), Egress (outgoing), or Both

### General Configuration Steps

1. **Identify Source Port(s)**:
   - Uplink port to router (monitors all internet-bound traffic)
   - Internal VLAN trunk (monitors inter-VLAN traffic)
   - Specific devices (e.g., server, IoT VLAN)

2. **Identify Destination Port**:
   - Port where NetSec Pi is connected
   - Should have no other devices connected
   - Set to access mode (not trunk) unless monitoring VLANs

3. **Configure Mirroring**:
   - Enable port mirroring/SPAN
   - Set source port(s)
   - Set destination port
   - Set direction: **Both** (recommended)

4. **Verify Configuration**:
   - Check switch shows mirroring active
   - Verify NetSec Pi sees traffic (see Validation section)

---

## Vendor-Specific Configurations

### UniFi Switches (Ubiquiti)

**Web UI Method**:

1. Navigate to **UniFi Network Controller**
2. Go to **Settings** → **System** → **Traffic Management**
3. Click **Port Manager**
4. Select the NetSec Pi port (e.g., Port 24)
5. Under **Port Profile**, select **Port Mirroring**
6. Enable **Mirror Port**
7. Select **Source Ports** (e.g., Port 1 - Uplink)
8. Save

**CLI Method** (SSH to switch):

```bash
# Enable port mirroring
configure
set interface ethernet eth0/24 mirror-to enable
set interface ethernet eth0/1 mirror-from enable
commit
save
exit
```

**Verify**:
```bash
show mirror
```

---

### Cisco Catalyst Switches

**CLI Configuration**:

```cisco
# Enter configuration mode
Switch# configure terminal

# Create SPAN session
Switch(config)# monitor session 1 source interface GigabitEthernet1/0/1 both

# Set destination port
Switch(config)# monitor session 1 destination interface GigabitEthernet1/0/24

# Exit and save
Switch(config)# end
Switch# write memory
```

**Verify**:
```cisco
Switch# show monitor session 1
```

**Expected Output**:
```
Session 1
---------
Type                   : Local Session
Source Ports           :
    Both               : Gi1/0/1
Destination Ports      : Gi1/0/24
```

---

### TP-Link Managed Switches (T1600G, T2600G Series)

**Web UI Method**:

1. Log in to switch web interface
2. Go to **Switching** → **Port Mirroring**
3. Click **Add**
4. Configuration:
   - **Session**: 1
   - **Destination Port**: Port where NetSec Pi is connected (e.g., 24)
   - **Source Ports**: Select uplink port (e.g., Port 1)
   - **Direction**: Both
5. Click **Apply**

**Verify**: Check that status shows "Active"

---

### Netgear Managed Switches (GS Series)

**Web UI Method**:

1. Log in to switch web interface
2. Go to **Switching** → **Monitoring** → **Mirroring**
3. Enable **Port Mirroring**
4. Configuration:
   - **Destination Port**: NetSec Pi port
   - **Source Port**: Uplink port
   - **Direction**: TX and RX (Both)
5. Click **Apply**

---

### MikroTik Switches

**CLI Configuration**:

```bash
# Add port mirror
/interface ethernet switch
set port-mirroring-destination=ether24
set port-mirroring-mode=enabled
set port-mirroring-source-ports=ether1
```

**Verify**:
```bash
/interface ethernet switch print
```

---

### Dell/SonicWall Switches

**Web UI Method**:

1. Navigate to **Monitoring** → **Port Mirroring**
2. Enable **Port Mirroring**
3. Set **Destination Port**: NetSec Pi port
4. Add **Source Ports**: Uplink port
5. Set **Traffic Type**: Both RX and TX
6. Apply

---

## Advanced Mirroring Scenarios

### Scenario 1: Monitor All LAN Traffic

**Goal**: See all internal and internet-bound traffic

**Configuration**:
- **Source Port**: Uplink port to router (e.g., Port 1)
- **Destination Port**: NetSec Pi (e.g., Port 24)
- **Direction**: Both

**Use Case**: Full network visibility, detects lateral movement

---

### Scenario 2: Monitor Specific VLAN

**Goal**: Monitor only IoT VLAN traffic

**Configuration**:
- **Source**: VLAN 20 (IoT VLAN)
- **Destination**: NetSec Pi port
- **Direction**: Both

**Example (Cisco)**:
```cisco
monitor session 1 source vlan 20 both
monitor session 1 destination interface Gi1/0/24
```

**Use Case**: Isolate suspicious device behavior on specific segment

---

### Scenario 3: Monitor Multiple Ports

**Goal**: Monitor traffic from multiple servers

**Configuration**:
- **Source Ports**: Ports 10, 11, 12 (servers)
- **Destination Port**: NetSec Pi (Port 24)
- **Direction**: Both

**Example (Cisco)**:
```cisco
monitor session 1 source interface Gi1/0/10 - 12 both
monitor session 1 destination interface Gi1/0/24
```

**Use Case**: Focus on critical infrastructure

---

## VLAN Tagging

If you need to preserve VLAN tags in mirrored traffic:

### Enable VLAN Tagging on Destination Port

**Cisco**:
```cisco
monitor session 1 destination interface Gi1/0/24 encapsulation replicate
```

**UniFi**: Not supported by default (tags are stripped)

**TP-Link**: Enable **Encapsulation** in mirroring settings

**Why**: Allows Suricata to identify which VLAN traffic belongs to

---

## Firewall Configuration

### Required Outbound Rules (from NetSec Pi)

The NetSec Pi needs outbound access to:

1. **CoreSrv Loki** (log shipping):
   - Protocol: TCP
   - Port: 3100
   - Destination: CoreSrv IP (e.g., 192.168.8.50)

2. **CoreSrv Prometheus** (metrics):
   - Protocol: TCP
   - Port: 9090
   - Destination: CoreSrv IP

3. **Threat Intelligence Feeds** (optional but recommended):
   - Protocol: TCP
   - Ports: 80, 443
   - Destinations: 
     - otx.alienvault.com (AlienVault OTX)
     - urlhaus.abuse.ch (URLhaus)
     - feodotracker.abuse.ch (Feodo Tracker)
     - checkip.amazonaws.com (PhishTank)
   - **Note**: Verify current feed URLs in [docs/threat-intel.md](threat-intel.md) as endpoints may change

4. **DNS**:
   - Protocol: UDP
   - Port: 53

5. **NTP** (time sync):
   - Protocol: UDP
   - Port: 123

### Recommended Inbound Rules (to NetSec Pi)

Allow from **CoreSrv only**:

1. **Web UI** (for Traefik proxying):
   - Protocol: TCP
   - Port: 8000
   - Source: CoreSrv IP

2. **Node Exporter** (metrics scraping):
   - Protocol: TCP
   - Port: 9100
   - Source: CoreSrv IP

**Default Deny**: Block all other inbound traffic

---

### Example: pfSense Firewall Rules

**Outbound (NetSec Pi to Internet)**:

| Action | Protocol | Source         | Destination      | Port  | Description           |
|--------|----------|----------------|------------------|-------|-----------------------|
| Pass   | TCP      | NetSec Pi IP   | CoreSrv IP       | 3100  | Loki log shipping     |
| Pass   | TCP      | NetSec Pi IP   | CoreSrv IP       | 9090  | Prometheus metrics    |
| Pass   | TCP      | NetSec Pi IP   | any              | 80    | Threat intel (HTTP)   |
| Pass   | TCP      | NetSec Pi IP   | any              | 443   | Threat intel (HTTPS)  |
| Pass   | UDP      | NetSec Pi IP   | any              | 53    | DNS                   |
| Pass   | UDP      | NetSec Pi IP   | NTP servers      | 123   | Time sync             |

**Inbound (Internet to NetSec Pi)**:

| Action | Protocol | Source         | Destination      | Port  | Description           |
|--------|----------|----------------|------------------|-------|-----------------------|
| Pass   | TCP      | CoreSrv IP     | NetSec Pi IP     | 8000  | Web UI access         |
| Pass   | TCP      | CoreSrv IP     | NetSec Pi IP     | 9100  | Metrics scraping      |
| Block  | any      | any            | NetSec Pi IP     | any   | Default deny          |

---

### Example: iptables Rules (on NetSec Pi)

```bash
#!/bin/bash
# Orion Sentinel NetSec - Firewall Rules

# Flush existing rules
iptables -F
iptables -X

# Default policies
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT

# Allow established connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow from CoreSrv
CORESRV_IP="192.168.8.50"
iptables -A INPUT -s $CORESRV_IP -p tcp --dport 8000 -j ACCEPT  # Web UI
iptables -A INPUT -s $CORESRV_IP -p tcp --dport 9100 -j ACCEPT  # Node Exporter

# Allow SSH from LAN (adjust subnet)
iptables -A INPUT -s 192.168.8.0/24 -p tcp --dport 22 -j ACCEPT

# Allow ICMP (ping)
iptables -A INPUT -p icmp -j ACCEPT

# Log dropped packets (optional, for debugging)
iptables -A INPUT -j LOG --log-prefix "IPT-DROP: " --log-level 4

# Save rules
iptables-save > /etc/iptables/rules.v4
```

Make persistent:
```bash
sudo apt install iptables-persistent
sudo netfilter-persistent save
```

---

## Validation & Testing

### 1. Verify Port Mirror is Active

**On Switch**: Check port mirroring status shows "Active" or "Enabled"

**On NetSec Pi**: Use tcpdump to see if traffic is arriving:

```bash
# Install tcpdump if not present
sudo apt install tcpdump

# Capture on mirrored interface (replace eth0 with your MONITOR_IF)
sudo tcpdump -i eth0 -c 100

# You should see packets from various IPs on your network
```

**Expected Output**:
```
10:15:23.456789 IP 192.168.1.10.54321 > 8.8.8.8.53: UDP, length 28
10:15:23.457123 IP 8.8.8.8.53 > 192.168.1.10.54321: UDP, length 44
10:15:23.458901 IP 192.168.1.20.443 > 1.2.3.4.12345: TCP, length 1460
...
```

**If No Traffic**:
- Check switch port mirroring is enabled
- Verify correct source/destination ports
- Check physical cable connections
- Ensure MONITOR_IF is UP: `ip link set eth0 up`

---

### 2. Verify Suricata is Capturing

After starting NetSec services:

```bash
# Check Suricata logs
docker logs orion-suricata | grep "Capture"

# Expected output:
# [INFO] Capture: Using AF_PACKET interface eth0
# [INFO] Capture: Received 15234 packets
```

**Query Suricata Stats**:
```bash
docker exec orion-suricata suricatasc -c "capture-mode"
# Output: AF_PACKET
```

---

### 3. Test with Known Signature

Generate traffic that should trigger Suricata alert:

```bash
# On another device on the network, run:
curl http://testmyids.com

# Or:
curl http://testmyids.com/uid/index.html
```

**Check for Alert**:
```bash
# Check Suricata eve.json log
docker exec orion-suricata tail /var/log/suricata/eve.json | jq .

# Should see alert for "GPL ATTACK_RESPONSE id check returned root"
```

---

### 4. Verify Log Shipping to Loki

```bash
# Check Promtail logs
docker logs orion-promtail 2>&1 | grep -i "POST"

# Expected output:
# level=info msg="POST /loki/api/v1/push (200 OK)"
```

**Query Loki** (on CoreSrv or via API):
```bash
# From NetSec Pi (if LOKI_URL is set)
curl -G -s "${LOKI_URL}/loki/api/v1/query" \
  --data-urlencode 'query={job="orion-suricata"}' | jq .
```

---

## Troubleshooting

### No Traffic Seen on Mirror Port

**Symptoms**: tcpdump shows no packets

**Solutions**:
1. Verify switch port mirroring configuration
2. Check source port has active traffic: `show interface gi1/0/1 stats`
3. Ensure destination port is in access mode (not trunk)
4. Try different source port
5. Reboot switch (some models require reboot to apply mirroring)

---

### Suricata Not Capturing

**Symptoms**: Suricata logs show 0 packets

**Solutions**:
1. Check `MONITOR_IF` in `.env` matches actual interface: `ip link show`
2. Bring interface UP: `sudo ip link set eth0 up`
3. Verify Suricata has permissions: Check container has `NET_ADMIN` capability
4. Review Suricata logs: `docker logs orion-suricata`
5. Restart Suricata service: `docker restart orion-suricata`

---

### High Packet Loss

**Symptoms**: Suricata reports many dropped packets

**Solutions**:
1. **Increase Ring Buffer Size**: Edit `suricata.yaml`:
   ```yaml
   af-packet:
     - interface: eth0
       ring-size: 16384  # Increase from default
   ```
2. **Reduce Suricata Rules**: Disable unused rulesets
3. **Upgrade Hardware**: Consider faster CPU or more RAM
4. **Filter Mirrored Traffic**: Mirror only critical ports/VLANs

---

### Firewall Blocking Loki Shipping

**Symptoms**: Promtail logs show "Connection refused" or timeouts

**Solutions**:
1. Test connectivity: `curl http://$LOKI_URL/ready`
2. Check firewall allows outbound to CoreSrv:3100
3. Verify CoreSrv Loki is running: `docker ps | grep loki`
4. Check network routing: `traceroute $CORESRV_IP`

---

## Best Practices

### ✅ Do

- Use dedicated NIC for mirrored traffic (if possible)
- Mirror uplink port for full visibility
- Test mirroring with tcpdump before deploying Suricata
- Document switch port configuration
- Use VLAN tagging if monitoring multiple VLANs
- Regularly verify mirroring is active

### ❌ Don't

- Mirror to a port with other devices (creates loops/conflicts)
- Mirror in only one direction (use "Both")
- Forget to bring mirror interface UP on Pi
- Neglect to update firewall rules for Loki access
- Mirror too many ports if hardware is constrained

---

## References

- [Suricata Documentation - AF_PACKET](https://suricata.readthedocs.io/en/latest/performance/packet-capture.html)
- [Cisco SPAN Configuration](https://www.cisco.com/c/en/us/support/docs/switches/catalyst-2950-series-switches/10566-span.html)
- [UniFi Port Mirroring](https://help.ui.com/hc/en-us/articles/360008836574)

---

**Last Updated**: 2024-12-09  
**Tested With**: UniFi Switch Pro 24, Cisco Catalyst 2960, TP-Link T2600G
