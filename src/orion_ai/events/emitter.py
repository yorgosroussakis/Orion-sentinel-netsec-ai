"""
Helper functions for emitting SecurityEvents from various services.

This module provides convenient wrappers for creating and pushing common
event types without boilerplate code.
"""

import logging
import os
from datetime import datetime
from typing import List, Optional

from .loki_client import LokiClient, create_loki_client
from .models import EventType, SecurityEvent, Severity


logger = logging.getLogger(__name__)


class EventEmitter:
    """
    Helper class for emitting SecurityEvents to Loki.
    
    Usage:
        emitter = EventEmitter()
        
        # Emit a SOAR action event
        await emitter.emit_soar_action(
            playbook_name="Block High-Risk Domain",
            action_type="block_domain",
            domain="evil.com",
            action_status="executed",
        )
    """
    
    def __init__(
        self,
        loki_client: Optional[LokiClient] = None,
        loki_url: Optional[str] = None,
    ):
        """
        Initialize event emitter.
        
        Args:
            loki_client: Pre-configured LokiClient (optional)
            loki_url: Loki URL if client not provided (defaults to env var or localhost)
        """
        if loki_client:
            self.client = loki_client
            self._owns_client = False
        else:
            url = loki_url or os.getenv("LOKI_URL", "http://localhost:3100")
            self.client = create_loki_client(loki_url=url)
            self._owns_client = True
    
    async def emit(self, event: SecurityEvent) -> None:
        """
        Emit a single SecurityEvent.
        
        Args:
            event: Event to emit
        """
        try:
            await self.client.push_event(event)
            logger.debug(f"Emitted event: {event.summary()}")
        except Exception as e:
            logger.error(f"Failed to emit event: {e}")
    
    async def emit_many(self, events: List[SecurityEvent]) -> None:
        """
        Emit multiple SecurityEvents.
        
        Args:
            events: Events to emit
        """
        try:
            await self.client.push_events(events)
            logger.debug(f"Emitted {len(events)} events")
        except Exception as e:
            logger.error(f"Failed to emit events: {e}")
    
    async def emit_soar_action(
        self,
        playbook_name: str,
        action_type: str,
        action_status: str,
        playbook_id: Optional[str] = None,
        severity: Severity = Severity.INFO,
        domain: Optional[str] = None,
        device_id: Optional[str] = None,
        reasons: Optional[List[str]] = None,
        **kwargs,
    ) -> None:
        """
        Emit a SOAR action event.
        
        Args:
            playbook_name: Name of the playbook
            action_type: Type of action (block_domain, notify, etc.)
            action_status: Status (executed, skipped, dry-run, failed)
            playbook_id: Optional playbook ID
            severity: Event severity
            domain: Domain affected by the action
            device_id: Device affected by the action
            reasons: Human-readable reasons for the action
            **kwargs: Additional fields to set on the event
        """
        event = SecurityEvent(
            timestamp=datetime.utcnow(),
            event_type=EventType.SOAR_ACTION,
            severity=severity,
            playbook_id=playbook_id,
            playbook_name=playbook_name,
            action_type=action_type,
            action_status=action_status,
            domain=domain,
            device_id=device_id,
            reasons=reasons,
            **kwargs,
        )
        await self.emit(event)
    
    async def emit_ai_detection(
        self,
        detection_name: str,
        severity: Severity,
        risk_score: float,
        reasons: Optional[List[str]] = None,
        detection_id: Optional[str] = None,
        domain: Optional[str] = None,
        src_ip: Optional[str] = None,
        dst_ip: Optional[str] = None,
        device_id: Optional[str] = None,
        ti_sources: Optional[List[str]] = None,
        **kwargs,
    ) -> None:
        """
        Emit an AI detection event.
        
        Args:
            detection_name: Name of the detection
            severity: Event severity
            risk_score: Risk score (0.0 to 1.0)
            reasons: Human-readable explanations
            detection_id: Optional detection ID
            domain: Domain associated with detection
            src_ip: Source IP
            dst_ip: Destination IP
            device_id: Device ID
            ti_sources: Threat intel sources that matched
            **kwargs: Additional fields
        """
        event = SecurityEvent(
            timestamp=datetime.utcnow(),
            event_type=EventType.AI_DETECTION,
            severity=severity,
            detection_id=detection_id,
            detection_name=detection_name,
            risk_score=risk_score,
            reasons=reasons,
            domain=domain,
            src_ip=src_ip,
            dst_ip=dst_ip,
            device_id=device_id,
            ti_sources=ti_sources,
            **kwargs,
        )
        await self.emit(event)
    
    async def emit_intel_match(
        self,
        indicator_value: str,
        indicator_type: str,
        ti_sources: List[str],
        severity: Severity,
        confidence: Optional[float] = None,
        domain: Optional[str] = None,
        src_ip: Optional[str] = None,
        dst_ip: Optional[str] = None,
        **kwargs,
    ) -> None:
        """
        Emit a threat intelligence match event.
        
        Args:
            indicator_value: The IOC value (domain, IP, URL, hash)
            indicator_type: Type of indicator
            ti_sources: Threat intel sources that matched
            severity: Event severity
            confidence: Confidence score (0.0 to 1.0)
            domain: Domain if applicable
            src_ip: Source IP
            dst_ip: Destination IP
            **kwargs: Additional fields
        """
        event = SecurityEvent(
            timestamp=datetime.utcnow(),
            event_type=EventType.INTEL_MATCH,
            severity=severity,
            indicator_value=indicator_value,
            indicator_type=indicator_type,
            ti_sources=ti_sources,
            risk_score=confidence,
            domain=domain,
            src_ip=src_ip,
            dst_ip=dst_ip,
            **kwargs,
        )
        await self.emit(event)
    
    async def emit_health_status(
        self,
        component: str,
        health_status: str,
        severity: Severity = Severity.INFO,
        reasons: Optional[List[str]] = None,
        **kwargs,
    ) -> None:
        """
        Emit a health status event.
        
        Args:
            component: Component name (suricata, loki, pihole, etc.)
            health_status: Status (healthy, degraded, down)
            severity: Event severity
            reasons: Reasons for the status
            **kwargs: Additional fields
        """
        event = SecurityEvent(
            timestamp=datetime.utcnow(),
            event_type=EventType.HEALTH_STATUS,
            severity=severity,
            component=component,
            health_status=health_status,
            reasons=reasons,
            **kwargs,
        )
        await self.emit(event)
    
    async def close(self) -> None:
        """Close the Loki client if owned by this emitter."""
        if self._owns_client:
            await self.client.close()
    
    async def __aenter__(self):
        """Context manager entry."""
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit."""
        await self.close()
