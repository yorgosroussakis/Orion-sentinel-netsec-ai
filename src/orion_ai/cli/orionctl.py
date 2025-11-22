#!/usr/bin/env python3
"""
orionctl - Orion Sentinel operational CLI

A lightweight CLI for day-2 operations:
- Health checks (orionctl doctor)
- Test event emission (orionctl send-test-event)
- Version info (orionctl version)
"""

import argparse
import asyncio
import os
import sys
from datetime import datetime
from typing import Optional

import httpx

# Import Orion modules
try:
    from orion_ai import __version__
    from orion_ai.events import EventEmitter, EventType, SecurityEvent, Severity
except ImportError:
    # Fallback if running without proper installation
    __version__ = "unknown"
    print("Warning: Could not import orion_ai modules. Some commands may fail.", file=sys.stderr)


class Colors:
    """ANSI color codes for terminal output."""
    
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    RED = "\033[91m"
    BLUE = "\033[94m"
    RESET = "\033[0m"
    BOLD = "\033[1m"


def colorize(text: str, color: str) -> str:
    """Colorize text if stdout is a TTY."""
    if sys.stdout.isatty():
        return f"{color}{text}{Colors.RESET}"
    return text


async def check_loki(loki_url: str, timeout: float = 5.0) -> tuple[str, str]:
    """
    Check if Loki is reachable and healthy.
    
    Returns:
        (status, message) where status is "OK", "WARN", or "ERROR"
    """
    try:
        async with httpx.AsyncClient(timeout=timeout) as client:
            # Try /ready endpoint first (standard Loki health check)
            response = await client.get(f"{loki_url}/ready")
            if response.status_code == 200:
                return "OK", "Loki is ready"
            else:
                return "WARN", f"Loki returned status {response.status_code}"
    except httpx.ConnectError:
        return "ERROR", "Cannot connect to Loki (connection refused)"
    except httpx.TimeoutException:
        return "ERROR", "Loki connection timeout"
    except Exception as e:
        return "ERROR", f"Unexpected error: {e}"


async def check_loki_query(loki_url: str, timeout: float = 10.0) -> tuple[str, str]:
    """
    Test a simple Loki query to verify query API works.
    
    Returns:
        (status, message) where status is "OK", "WARN", or "ERROR"
    """
    try:
        async with httpx.AsyncClient(timeout=timeout) as client:
            # Query for events in the last 5 minutes
            query = '{app="orion-sentinel"}'
            params = {
                "query": query,
                "limit": 1,
                "start": str(int((datetime.now().timestamp() - 300) * 1_000_000_000)),
            }
            response = await client.get(
                f"{loki_url}/loki/api/v1/query_range",
                params=params
            )
            
            if response.status_code == 200:
                data = response.json()
                result_count = len(data.get("data", {}).get("result", []))
                return "OK", f"Query successful ({result_count} stream(s) in last 5m)"
            else:
                return "WARN", f"Query returned status {response.status_code}"
    except Exception as e:
        return "WARN", f"Query test failed: {e}"


async def check_grafana(grafana_url: Optional[str], timeout: float = 5.0) -> tuple[str, str]:
    """
    Check if Grafana is reachable.
    
    Returns:
        (status, message) where status is "OK", "WARN", or "ERROR"
    """
    if not grafana_url:
        return "WARN", "Grafana URL not configured (GRAFANA_URL env var not set)"
    
    try:
        async with httpx.AsyncClient(timeout=timeout) as client:
            response = await client.get(f"{grafana_url}/api/health")
            if response.status_code == 200:
                return "OK", "Grafana is healthy"
            else:
                return "WARN", f"Grafana returned status {response.status_code}"
    except httpx.ConnectError:
        return "ERROR", "Cannot connect to Grafana"
    except httpx.TimeoutException:
        return "ERROR", "Grafana connection timeout"
    except Exception as e:
        return "WARN", f"Could not reach Grafana: {e}"


def format_check_result(name: str, status: str, message: str, width: int = 40) -> str:
    """Format a check result line."""
    padding = " " * max(1, width - len(name))
    
    if status == "OK":
        status_str = colorize("[OK]", Colors.GREEN)
    elif status == "WARN":
        status_str = colorize("[WARN]", Colors.YELLOW)
    else:  # ERROR
        status_str = colorize("[ERROR]", Colors.RED)
    
    return f"{name}:{padding}{status_str} {message}"


async def cmd_doctor(args) -> int:
    """
    Run system health checks and print a summary.
    
    Returns:
        Exit code (0 on success, non-zero on critical failure)
    """
    print(colorize("\nOrion Sentinel Doctor", Colors.BOLD))
    print(colorize("=" * 60, Colors.BOLD))
    print()
    
    # Get configuration from environment
    loki_url = os.getenv("LOKI_URL", os.getenv("ORION_LOKI_URL", "http://localhost:3100"))
    grafana_url = os.getenv("GRAFANA_URL")
    
    all_ok = True
    
    # Check Loki connectivity
    status, message = await check_loki(loki_url, timeout=args.timeout)
    print(format_check_result(f"Loki ({loki_url})", status, message))
    if status == "ERROR":
        all_ok = False
    
    # Check Loki query API
    if status == "OK":
        status, message = await check_loki_query(loki_url, timeout=args.timeout)
        print(format_check_result("Loki query test", status, message))
    
    # Check Grafana
    status, message = await check_grafana(grafana_url, timeout=args.timeout)
    print(format_check_result(f"Grafana ({grafana_url or 'not set'})", status, message))
    
    # Placeholder for future checks
    print(format_check_result("Suricata", "UNKNOWN", "not checked in this version"))
    print(format_check_result("AI services", "UNKNOWN", "not checked in this version"))
    
    print()
    
    if all_ok:
        print(colorize("✓ All critical checks passed", Colors.GREEN))
        return 0
    else:
        print(colorize("✗ One or more critical checks failed", Colors.RED))
        return 1


async def cmd_send_test_event(args) -> int:
    """
    Send a test SecurityEvent to Loki.
    
    Returns:
        Exit code (0 on success, non-zero on failure)
    """
    loki_url = os.getenv("LOKI_URL", os.getenv("ORION_LOKI_URL", "http://localhost:3100"))
    
    print(f"Sending test event to Loki at {loki_url}...")
    
    try:
        # Create event emitter
        async with EventEmitter(loki_url=loki_url) as emitter:
            # Send health status event
            await emitter.emit_health_status(
                component="orionctl",
                health_status="healthy",
                severity=Severity.INFO,
                reasons=["Manual test event from orionctl send-test-event"],
            )
        
        timestamp = datetime.utcnow().isoformat()
        print(colorize(f"✓ Test event sent successfully at {timestamp}", Colors.GREEN))
        print(f"\nYou can view it in Grafana or query Loki:")
        print(f'  {{app="orion-sentinel", event_type="health_status", component="orionctl"}}')
        
        return 0
        
    except Exception as e:
        print(colorize(f"✗ Failed to send test event: {e}", Colors.RED), file=sys.stderr)
        return 1


def cmd_version(args) -> int:
    """
    Print version information.
    
    Returns:
        Exit code (always 0)
    """
    print(f"orionctl version {__version__}")
    print(f"Orion Sentinel - AI-assisted SOC-in-a-box for home labs & small offices")
    return 0


def create_parser() -> argparse.ArgumentParser:
    """Create the argument parser for orionctl."""
    parser = argparse.ArgumentParser(
        description="Orion Sentinel operational CLI",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  orionctl doctor                    # Run health checks
  orionctl send-test-event           # Send a test event to Loki
  orionctl version                   # Show version information

Environment variables:
  LOKI_URL or ORION_LOKI_URL        # Loki URL (default: http://localhost:3100)
  GRAFANA_URL                        # Grafana URL (optional)
        """
    )
    
    subparsers = parser.add_subparsers(dest="command", help="Command to run")
    
    # doctor command
    doctor_parser = subparsers.add_parser(
        "doctor",
        help="Run health checks and diagnostics"
    )
    doctor_parser.add_argument(
        "--timeout",
        type=float,
        default=10.0,
        help="Timeout for HTTP requests in seconds (default: 10.0)"
    )
    
    # send-test-event command
    test_parser = subparsers.add_parser(
        "send-test-event",
        help="Send a test SecurityEvent to Loki"
    )
    
    # version command
    version_parser = subparsers.add_parser(
        "version",
        help="Show version information"
    )
    
    return parser


def main(argv=None):
    """Main entry point for orionctl CLI."""
    parser = create_parser()
    args = parser.parse_args(argv)
    
    if not args.command:
        parser.print_help()
        return 0
    
    # Dispatch to command handlers
    if args.command == "doctor":
        return asyncio.run(cmd_doctor(args))
    elif args.command == "send-test-event":
        return asyncio.run(cmd_send_test_event(args))
    elif args.command == "version":
        return cmd_version(args)
    else:
        print(f"Unknown command: {args.command}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
