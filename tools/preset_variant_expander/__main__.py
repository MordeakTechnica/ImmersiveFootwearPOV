"""Entry point for executing preset_variant_expander via python -m tools.preset_variant_expander."""

import sys
from .cli.main import main

if __name__ == "__main__":
    sys.exit(main())
