"""
Loki client for pushing SecurityEvents to Loki.

This client provides a simple interface for sending events to Loki's push API.
It handles the Loki-specific format (labels + log lines) and retries.
"""

import logging
from datetime import datetime
from typing import List, Optional

import httpx
from pydantic import BaseModel

from .models import SecurityEvent


logger = logging.getLogger(__name__)


class LokiPushError(Exception):
    """Raised when pushing to Loki fails."""
    pass


class LokiStream(BaseModel):
    """
    A Loki stream (set of labels + log lines).
    
    Loki groups logs by their label set. Each unique set of labels
    creates a separate "stream".
    """
    
    stream: dict[str, str]  # Labels
    values: List[List[str]]  # [[timestamp_ns, log_line], ...]


class LokiPushRequest(BaseModel):
    """Loki push API request format."""
    
    streams: List[LokiStream]


class LokiClient:
    """
    Client for pushing SecurityEvents to Loki.
    
    Usage:
        client = LokiClient(loki_url="http://localhost:3100")
        event = SecurityEvent(
            timestamp=datetime.now(),
            event_type=EventType.AI_DETECTION,
            severity=Severity.HIGH,
            domain="evil.com",
            risk_score=0.95,
        )
        await client.push_event(event)
    """
    
    def __init__(
        self,
        loki_url: str = "http://localhost:3100",
        timeout: float = 10.0,
        max_retries: int = 3,
    ):
        """
        Initialize Loki client.
        
        Args:
            loki_url: Base URL of Loki instance (e.g. "http://localhost:3100")
            timeout: HTTP request timeout in seconds
            max_retries: Number of retries on failure
        """
        self.loki_url = loki_url.rstrip("/")
        self.push_url = f"{self.loki_url}/loki/api/v1/push"
        self.timeout = timeout
        self.max_retries = max_retries
        
        # Create async HTTP client (will be reused)
        self.client = httpx.AsyncClient(timeout=self.timeout)
    
    async def push_event(self, event: SecurityEvent) -> None:
        """
        Push a single SecurityEvent to Loki.
        
        Args:
            event: SecurityEvent to push
            
        Raises:
            LokiPushError: If push fails after retries
        """
        await self.push_events([event])
    
    async def push_events(self, events: List[SecurityEvent]) -> None:
        """
        Push multiple SecurityEvents to Loki.
        
        Events are grouped by their label set (stream) for efficiency.
        
        Args:
            events: List of SecurityEvents to push
            
        Raises:
            LokiPushError: If push fails after retries
        """
        if not events:
            return
        
        # Group events by label set (each unique set of labels = one stream)
        streams_map: dict[str, LokiStream] = {}
        
        for event in events:
            labels = event.to_loki_labels()
            log_line = event.to_loki_log_line()
            timestamp_ns = str(int(event.timestamp.timestamp() * 1_000_000_000))
            
            # Create a hashable key from labels
            labels_key = "_".join(f"{k}={v}" for k, v in sorted(labels.items()))
            
            if labels_key not in streams_map:
                streams_map[labels_key] = LokiStream(
                    stream=labels,
                    values=[]
                )
            
            streams_map[labels_key].values.append([timestamp_ns, log_line])
        
        # Build Loki push request
        push_request = LokiPushRequest(streams=list(streams_map.values()))
        
        # Push to Loki with retries
        for attempt in range(self.max_retries):
            try:
                response = await self.client.post(
                    self.push_url,
                    json=push_request.model_dump(),
                    headers={"Content-Type": "application/json"},
                )
                
                if response.status_code == 204:
                    logger.debug(
                        f"Pushed {len(events)} event(s) to Loki in {len(streams_map)} stream(s)"
                    )
                    return
                else:
                    logger.warning(
                        f"Loki push returned status {response.status_code}: {response.text}"
                    )
                    
            except Exception as e:
                logger.warning(f"Loki push attempt {attempt + 1} failed: {e}")
                
                if attempt == self.max_retries - 1:
                    raise LokiPushError(
                        f"Failed to push events to Loki after {self.max_retries} attempts"
                    ) from e
    
    async def close(self) -> None:
        """Close the HTTP client."""
        await self.client.aclose()
    
    async def __aenter__(self):
        """Context manager entry."""
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit."""
        await self.close()


def create_loki_client(
    loki_url: Optional[str] = None,
    timeout: float = 10.0,
    max_retries: int = 3,
) -> LokiClient:
    """
    Factory function to create a LokiClient.
    
    Args:
        loki_url: Loki URL (defaults to http://localhost:3100)
        timeout: HTTP request timeout
        max_retries: Number of retries
        
    Returns:
        Configured LokiClient instance
    """
    return LokiClient(
        loki_url=loki_url or "http://localhost:3100",
        timeout=timeout,
        max_retries=max_retries,
    )
