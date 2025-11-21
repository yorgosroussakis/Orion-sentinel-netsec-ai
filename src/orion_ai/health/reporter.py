"""
Health reporter for Orion Sentinel services.

This module provides a simple interface for services to periodically
report their health status as SecurityEvents to Loki.
"""

import asyncio
import logging
from datetime import datetime
from typing import List, Optional

from orion_ai.events import EventEmitter, Severity


logger = logging.getLogger(__name__)


class HealthReporter:
    """
    Periodic health status reporter for services.
    
    Usage:
        reporter = HealthReporter(
            component="inventory-service",
            loki_url="http://localhost:3100",
            interval_seconds=300  # Report every 5 minutes
        )
        
        # In your service main loop:
        asyncio.create_task(reporter.start())
        
        # When checking health:
        if all_checks_pass:
            reporter.report_healthy(["All systems operational"])
        else:
            reporter.report_degraded(["Database slow", "Cache miss rate high"])
    """
    
    def __init__(
        self,
        component: str,
        loki_url: Optional[str] = None,
        interval_seconds: int = 300,
        emitter: Optional[EventEmitter] = None,
    ):
        """
        Initialize health reporter.
        
        Args:
            component: Component name (e.g., "inventory-service", "soar-service")
            loki_url: Loki URL (if emitter not provided)
            interval_seconds: How often to emit health events (default: 300 = 5 minutes)
            emitter: Pre-configured EventEmitter (optional)
        """
        self.component = component
        self.interval_seconds = interval_seconds
        
        if emitter:
            self.emitter = emitter
            self._owns_emitter = False
        else:
            self.emitter = EventEmitter(loki_url=loki_url)
            self._owns_emitter = True
        
        # Current health state
        self._health_status = "healthy"
        self._reasons: List[str] = []
        self._last_check_time: Optional[datetime] = None
        
        # Control flags
        self._running = False
        self._task: Optional[asyncio.Task] = None
    
    def report_healthy(self, reasons: Optional[List[str]] = None):
        """
        Report that the component is healthy.
        
        Args:
            reasons: Optional list of reasons/details
        """
        self._health_status = "healthy"
        self._reasons = reasons or ["Component operational"]
        self._last_check_time = datetime.utcnow()
    
    def report_degraded(self, reasons: List[str]):
        """
        Report that the component is degraded.
        
        Args:
            reasons: List of reasons why component is degraded
        """
        self._health_status = "degraded"
        self._reasons = reasons
        self._last_check_time = datetime.utcnow()
    
    def report_down(self, reasons: List[str]):
        """
        Report that the component is down.
        
        Args:
            reasons: List of reasons why component is down
        """
        self._health_status = "down"
        self._reasons = reasons
        self._last_check_time = datetime.utcnow()
    
    async def emit_health_event(self):
        """Emit current health status as a SecurityEvent."""
        try:
            # Determine severity based on health status
            severity_map = {
                "healthy": Severity.INFO,
                "degraded": Severity.MEDIUM,
                "down": Severity.CRITICAL,
            }
            severity = severity_map.get(self._health_status, Severity.INFO)
            
            await self.emitter.emit_health_status(
                component=self.component,
                health_status=self._health_status,
                severity=severity,
                reasons=self._reasons,
            )
            
            logger.debug(
                f"Emitted health event for {self.component}: "
                f"{self._health_status} ({len(self._reasons)} reason(s))"
            )
            
        except Exception as e:
            logger.error(f"Failed to emit health event for {self.component}: {e}")
    
    async def _reporting_loop(self):
        """Background loop that periodically emits health events."""
        logger.info(
            f"Health reporter started for {self.component} "
            f"(interval: {self.interval_seconds}s)"
        )
        
        while self._running:
            try:
                await self.emit_health_event()
            except Exception as e:
                logger.error(f"Error in health reporting loop: {e}")
            
            # Wait for next interval
            await asyncio.sleep(self.interval_seconds)
    
    async def start(self):
        """Start the periodic health reporting loop."""
        if self._running:
            logger.warning(f"Health reporter for {self.component} already running")
            return
        
        self._running = True
        self._task = asyncio.create_task(self._reporting_loop())
    
    async def stop(self):
        """Stop the periodic health reporting loop."""
        if not self._running:
            return
        
        self._running = False
        if self._task:
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
        
        if self._owns_emitter:
            await self.emitter.close()
        
        logger.info(f"Health reporter stopped for {self.component}")
    
    async def __aenter__(self):
        """Context manager entry."""
        await self.start()
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit."""
        await self.stop()


# Convenience function for one-off health checks
async def emit_health_check(
    component: str,
    health_status: str,
    reasons: List[str],
    loki_url: Optional[str] = None,
):
    """
    Emit a single health check event (one-off, not periodic).
    
    Args:
        component: Component name
        health_status: "healthy", "degraded", or "down"
        reasons: List of reasons/details
        loki_url: Loki URL (optional, uses env var if not provided)
    """
    severity_map = {
        "healthy": Severity.INFO,
        "degraded": Severity.MEDIUM,
        "down": Severity.CRITICAL,
    }
    severity = severity_map.get(health_status, Severity.INFO)
    
    async with EventEmitter(loki_url=loki_url) as emitter:
        await emitter.emit_health_status(
            component=component,
            health_status=health_status,
            severity=severity,
            reasons=reasons,
        )
