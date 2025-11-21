"""
Unified SecurityEvent model for the Orion Sentinel event spine.

This model provides a consistent structure for all security events in the system,
whether they come from Suricata, AI detection, SOAR actions, or health monitoring.
"""

from datetime import datetime
from enum import Enum
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field


class EventType(str, Enum):
    """Types of security events."""
    
    SURICATA_ALERT = "suricata_alert"
    AI_DETECTION = "ai_detection"
    SOAR_ACTION = "soar_action"
    HEALTH_STATUS = "health_status"
    INTEL_MATCH = "intel_match"
    INVENTORY_EVENT = "inventory_event"
    CHANGE_EVENT = "change_event"
    HONEYPOT_HIT = "honeypot_hit"


class Severity(str, Enum):
    """Event severity levels."""
    
    INFO = "info"
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


class IndicatorType(str, Enum):
    """Types of threat indicators."""
    
    DOMAIN = "domain"
    IP = "ip"
    URL = "url"
    HASH = "hash"


class SecurityEvent(BaseModel):
    """
    Unified security event model.
    
    This is the core data structure for all security events in Orion Sentinel.
    Events flow through the system: Suricata → Loki → AI → SOAR → Loki.
    
    Design principles:
    - All fields except timestamp, event_type, and severity are optional
    - Fields are grouped by domain (network, detection, SOAR, health, etc.)
    - Use None for missing values rather than empty strings/lists
    - The 'extra' field can hold arbitrary event-specific data
    """
    
    # Required fields
    timestamp: datetime = Field(
        description="Event timestamp (when the event occurred or was detected)"
    )
    event_type: EventType = Field(
        description="Type of event (suricata_alert, ai_detection, soar_action, etc.)"
    )
    severity: Severity = Field(
        description="Event severity (info, low, medium, high, critical)"
    )
    
    # Core network identifiers
    src_ip: Optional[str] = Field(
        None, description="Source IP address"
    )
    dst_ip: Optional[str] = Field(
        None, description="Destination IP address"
    )
    src_port: Optional[int] = Field(
        None, description="Source port number"
    )
    dst_port: Optional[int] = Field(
        None, description="Destination port number"
    )
    protocol: Optional[str] = Field(
        None, description="Network protocol (tcp, udp, icmp, etc.)"
    )
    
    # Domain / URL / indicator
    domain: Optional[str] = Field(
        None, description="Domain name associated with the event"
    )
    url: Optional[str] = Field(
        None, description="Full URL associated with the event"
    )
    indicator_type: Optional[IndicatorType] = Field(
        None, description="Type of threat indicator (domain, ip, url, hash)"
    )
    indicator_value: Optional[str] = Field(
        None, description="Value of the threat indicator"
    )
    
    # Device & inventory
    device_id: Optional[str] = Field(
        None, description="Unique device identifier (usually IP or MAC)"
    )
    device_name: Optional[str] = Field(
        None, description="Human-readable device name"
    )
    device_role: Optional[str] = Field(
        None, description="Device role (workstation, iot, server, etc.)"
    )
    
    # Detection / AI
    detection_id: Optional[str] = Field(
        None, description="Unique identifier for this detection"
    )
    detection_name: Optional[str] = Field(
        None, description="Human-readable detection name"
    )
    risk_score: Optional[float] = Field(
        None, ge=0.0, le=1.0, description="Risk score (0.0 to 1.0)"
    )
    reasons: Optional[List[str]] = Field(
        None, description="Human-readable explanations for the detection/score"
    )
    
    # Threat intelligence
    ti_sources: Optional[List[str]] = Field(
        None, description="Threat intel sources that matched (e.g. ['OTX', 'Feodo'])"
    )
    
    # Suricata specifics
    suricata_sid: Optional[int] = Field(
        None, description="Suricata signature ID"
    )
    suricata_signature: Optional[str] = Field(
        None, description="Suricata signature text"
    )
    suricata_category: Optional[str] = Field(
        None, description="Suricata alert category"
    )
    
    # SOAR / actions
    playbook_id: Optional[str] = Field(
        None, description="ID of the playbook that was executed"
    )
    playbook_name: Optional[str] = Field(
        None, description="Name of the playbook that was executed"
    )
    action_type: Optional[str] = Field(
        None, description="Type of action executed (block_domain, notify, etc.)"
    )
    action_status: Optional[str] = Field(
        None, description="Action execution status (executed, skipped, dry-run, failed)"
    )
    
    # Health / HA
    component: Optional[str] = Field(
        None, description="System component (suricata, loki, pihole, keepalived, etc.)"
    )
    health_status: Optional[str] = Field(
        None, description="Health status (healthy, degraded, down)"
    )
    
    # Misc
    labels: Optional[Dict[str, str]] = Field(
        None, description="Arbitrary key-value labels for filtering/grouping"
    )
    extra: Optional[Dict[str, Any]] = Field(
        None, description="Additional event-specific data not covered by other fields"
    )
    
    class Config:
        """Pydantic configuration."""
        json_encoders = {
            datetime: lambda v: v.isoformat(),
        }
    
    def to_loki_labels(self) -> Dict[str, str]:
        """
        Generate Loki labels from this event.
        
        Loki labels are used for indexing and fast filtering.
        Use sparingly - only include high-cardinality fields.
        
        Returns:
            Dict of label key-value pairs for Loki
        """
        labels_dict = {
            "event_type": self.event_type.value,
            "severity": self.severity.value,
        }
        
        # Add optional labels if present
        if self.component:
            labels_dict["component"] = self.component
        
        if self.device_id:
            labels_dict["device_id"] = self.device_id
        
        if self.detection_name:
            labels_dict["detection"] = self.detection_name
        
        # Add custom labels
        if self.labels:
            labels_dict.update(self.labels)
        
        return labels_dict
    
    def to_loki_log_line(self) -> str:
        """
        Generate Loki log line from this event.
        
        The log line contains the full event as JSON.
        This is the "value" part of a Loki log entry.
        
        Returns:
            JSON string representation of the event
        """
        return self.model_dump_json(exclude_none=True)
    
    def summary(self) -> str:
        """
        Generate a human-readable summary of this event.
        
        Returns:
            One-line summary suitable for logging or display
        """
        parts = [
            f"[{self.severity.value.upper()}]",
            f"{self.event_type.value}:",
        ]
        
        if self.detection_name:
            parts.append(self.detection_name)
        elif self.playbook_name:
            parts.append(f"Playbook '{self.playbook_name}'")
        elif self.suricata_signature:
            parts.append(self.suricata_signature)
        
        if self.src_ip:
            parts.append(f"from {self.src_ip}")
        
        if self.dst_ip:
            parts.append(f"to {self.dst_ip}")
        
        if self.domain:
            parts.append(f"domain={self.domain}")
        
        if self.risk_score is not None:
            parts.append(f"risk={self.risk_score:.2f}")
        
        return " ".join(parts)
