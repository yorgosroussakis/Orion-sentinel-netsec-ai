"""
Allow running orionctl as a module: python -m orion_ai.cli.orionctl
"""

import sys
from .orionctl import main

if __name__ == "__main__":
    sys.exit(main())
