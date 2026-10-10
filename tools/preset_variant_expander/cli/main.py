"""
Command-Line Interface for Shoe Preset Variant Expander.
Provides automated variant resolution and preset expansion for Immersive Footwear POV.
"""

import argparse
import sys
from pathlib import Path
from typing import List, Optional

from ..core.models import ExpansionResult
from ..engine.expander import PresetExpansionEngine
from ..providers.archive_provider import ArchiveVariantProvider
from ..providers.composite_provider import CompositeVariantProvider
from ..providers.equipment_ex_provider import EquipmentExVariantProvider
from ..providers.tweak_yaml_provider import TweakYamlVariantProvider
from ..repository.json_preset_repository import JsonPresetRepository

COMMON_GAME_DIRS = [
    Path(r"D:\SteamLibrary\steamapps\common\Cyberpunk 2077"),
    Path(r"C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077"),
    Path(r"C:\SteamLibrary\steamapps\common\Cyberpunk 2077"),
    Path(r"E:\SteamLibrary\steamapps\common\Cyberpunk 2077"),
    Path(r"F:\SteamLibrary\steamapps\common\Cyberpunk 2077"),
    Path(r"C:\GOG Games\Cyberpunk 2077"),
    Path(r"D:\GOG Games\Cyberpunk 2077"),
    Path(r"C:\Program Files\Epic Games\Cyberpunk 2077"),
]


def _find_default_game_dir() -> Optional[Path]:
    for p in COMMON_GAME_DIRS:
        if p.exists() and (p / "r6" / "tweaks").exists():
            return p
    return None


DEFAULT_GAME_DIR = _find_default_game_dir() or Path(r"D:\SteamLibrary\steamapps\common\Cyberpunk 2077")


def create_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="preset_variant_expander",
        description="Automatically expand single-item footwear presets across all mod variants (colors, materials, instances)."
    )

    parser.add_argument(
        "-i", "--input",
        required=True,
        type=Path,
        help="Path to the input shoe presets JSON file (e.g. presets.json, user_shoe_overrides.json, or community submission)."
    )

    parser.add_argument(
        "-o", "--output",
        type=Path,
        default=None,
        help="Path for saving the expanded presets JSON. Defaults to updating the input file in-place."
    )

    parser.add_argument(
        "-g", "--game-dir",
        type=Path,
        default=DEFAULT_GAME_DIR if DEFAULT_GAME_DIR.exists() else None,
        help="Cyberpunk 2077 root directory (used to locate r6/tweaks and archive/pc/mod)."
    )

    parser.add_argument(
        "-t", "--tweaks-dir",
        type=Path,
        default=None,
        help="Custom tweaks directory to scan for TweakXL YAML and Equipment-EX CSV files."
    )

    parser.add_argument(
        "-a", "--archive-dir",
        type=Path,
        default=None,
        help="Custom mod archive directory to scan (archive/pc/mod)."
    )

    parser.add_argument(
        "--scan-archives",
        action="store_true",
        help="Enable deep WolvenKit CLI scanning of .archive files (off by default for speed; TweakXL YAMLs contain 99%% of item registrations)."
    )

    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Overwrite existing preset entries if different calibration values are found."
    )

    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Analyze and display discovered variants without saving any files to disk."
    )

    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Display detailed per-item match logs and source filenames."
    )

    return parser


def _interactive_wizard() -> Optional[List[str]]:
    """Interactive console wizard when launched without CLI arguments."""
    print("=================================================================", flush=True)
    print("      Immersive Footwear POV — Preset Variant Expander           ", flush=True)
    print("                      Interactive Mode                           ", flush=True)
    print("=================================================================\n", flush=True)

    game_dir = _find_default_game_dir()
    if game_dir:
        print(f"[*] Detected Cyberpunk 2077 at:\n    {game_dir}\n", flush=True)
        try:
            custom_game = input("Use this game directory? [Y/n] (or enter custom path): ").strip()
        except (EOFError, KeyboardInterrupt):
            return None
        if custom_game and custom_game.lower() not in ("y", "yes"):
            custom_path = Path(custom_game.strip('"'))
            if custom_path.exists():
                game_dir = custom_path
            else:
                print(f"[!] Path not found: {custom_path}", file=sys.stderr)
                return None
    else:
        try:
            custom_game = input("Enter path to Cyberpunk 2077 root directory: ").strip().strip('"')
        except (EOFError, KeyboardInterrupt):
            return None
        custom_path = Path(custom_game)
        if custom_path.exists():
            game_dir = custom_path
        else:
            print(f"[!] Path not found: {custom_path}", file=sys.stderr)
            return None

    mod_dir = game_dir / "bin" / "x64" / "plugins" / "cyber_engine_tweaks" / "mods" / "ImmersiveFootwearPOV"
    user_overrides = mod_dir / "user_shoe_overrides.json"
    presets_file = mod_dir / "presets.json"

    print("\nSelect an action:", flush=True)
    if user_overrides.exists():
        print("  [1] Read user_shoe_overrides.json and export expanded pack to presets.json (Recommended)")
        print("  [2] Update user_shoe_overrides.json in-place with all variants")
    else:
        print("  [1] Expand presets.json in game folder")
    print("  [3] Specify a custom input presets JSON file")
    print("  [4] Exit")

    try:
        choice = input("\nChoice [1-4] (default 1): ").strip() or "1"
    except (EOFError, KeyboardInterrupt):
        return None

    if choice == "1":
        if user_overrides.exists():
            return ["-i", str(user_overrides), "-o", str(presets_file), "-g", str(game_dir), "-v"]
        elif presets_file.exists():
            return ["-i", str(presets_file), "-g", str(game_dir), "-v"]
        else:
            print("[!] Neither user_shoe_overrides.json nor presets.json found in mod folder.", file=sys.stderr)
            return None
    elif choice == "2":
        if user_overrides.exists():
            return ["-i", str(user_overrides), "-g", str(game_dir), "-v"]
        else:
            print("[!] user_shoe_overrides.json not found in mod folder.", file=sys.stderr)
            return None
    elif choice == "3":
        try:
            custom_in = input("Enter input JSON path: ").strip().strip('"')
        except (EOFError, KeyboardInterrupt):
            return None
        p_in = Path(custom_in)
        if not p_in.exists():
            print(f"[!] File not found: {p_in}", file=sys.stderr)
            return None
        return ["-i", str(p_in), "-g", str(game_dir), "-v"]
    else:
        return None


def main(args=None) -> int:
    is_interactive = False
    if args is None:
        if len(sys.argv) == 2 and sys.argv[1].lower().endswith(".json") and Path(sys.argv[1]).exists():
            # Drag-and-drop mode
            args = ["-i", sys.argv[1], "-v"]
            is_interactive = True
        elif len(sys.argv) == 1:
            # Interactive Mode
            is_interactive = True
            args = _interactive_wizard()
            if args is None:
                return 0

    parser = create_parser()
    opts = parser.parse_args(args)

    input_path: Path = opts.input
    output_path: Path = opts.output or input_path

    if not input_path.exists():
        print(f"[!] Error: Input presets file not found: {input_path}", file=sys.stderr)
        return 1

    print("=================================================================", flush=True)
    print("      Immersive Footwear POV — Preset Variant Expander           ", flush=True)
    print("=================================================================", flush=True)
    print(f"[*] Input file:    {input_path}", flush=True)
    print(f"[*] Output target: {output_path} {'[DRY RUN]' if opts.dry_run else ''}", flush=True)

    # 1. Load Presets
    repo = JsonPresetRepository()
    try:
        presets = repo.load(input_path)
    except Exception as e:
        print(f"[!] Error loading presets: {e}", file=sys.stderr, flush=True)
        return 1

    print(f"[*] Loaded {len(presets)} incoming preset footwear item(s).\n", flush=True)

    if not presets:
        print("[!] No shoe presets found to expand.", flush=True)
        return 0

    # 2. Build Composite Provider
    composite = CompositeVariantProvider()
    yaml_provider = TweakYamlVariantProvider()
    eq_provider = EquipmentExVariantProvider()
    composite.add_provider(yaml_provider)
    composite.add_provider(eq_provider)

    if opts.scan_archives or opts.archive_dir:
        composite.add_provider(ArchiveVariantProvider())

    # 3. Resolve Scan Directories
    scan_dirs = []
    if opts.tweaks_dir and opts.tweaks_dir.exists():
        scan_dirs.append(opts.tweaks_dir)
    elif opts.game_dir and (opts.game_dir / "r6" / "tweaks").exists():
        scan_dirs.append(opts.game_dir / "r6" / "tweaks")

    if (opts.scan_archives and opts.game_dir and (opts.game_dir / "archive" / "pc" / "mod").exists()) or (opts.archive_dir and opts.archive_dir.exists()):
        archive_path = opts.archive_dir or (opts.game_dir / "archive" / "pc" / "mod")
        scan_dirs.append(archive_path)

    if not scan_dirs:
        print("[!] Warning: No valid scan directories found. Please specify --game-dir or --tweaks-dir.", flush=True)
        return 1

    # Real-time progress callback
    def on_progress(filename: str, current: int, total: int, variants_found: int):
        percent = int((current / total) * 100) if total > 0 else 100
        short_name = filename if len(filename) <= 36 else filename[:33] + "..."
        sys.stdout.write(f"\r[*] Indexing [{current:>4}/{total:<4} {percent:>3}%] {short_name:<36} (Variants: {variants_found})")
        sys.stdout.flush()

    print("[*] Indexing mod files for variant relationships:", flush=True)
    for d in scan_dirs:
        print(f"    Scanning: {d} ...", flush=True)
        indexed = composite.index_directory(d, progress_callback=on_progress)
        sys.stdout.write(f"\r[+] Indexed {d.name}: {indexed} variant relationships mapped.{' ' * 30}\n\n")
        sys.stdout.flush()

    # 4. Execute Expansion Engine
    engine = PresetExpansionEngine(composite)
    expanded, result = engine.expand(presets, overwrite_existing=opts.overwrite)

    # 5. Display Summary Report
    print("\n---------------------- Expansion Report -------------------------")
    print(f"[*] Initial Items:        {result.initial_items_count}")
    print(f"[+] Sibling Variants Added: {result.new_variants_added}")
    print(f"[*] Total Expanded Items: {result.total_items_count}")

    if result.added_variants:
        print("\n[+] Discovered Variant Expansions:")
        for parent, siblings in result.added_variants.items():
            print(f"  * {parent} ({len(siblings)} siblings):")
            for sib in siblings:
                if opts.verbose and sib in result.variant_details:
                    match_info = result.variant_details[sib]
                    src_name = Path(match_info.source_file).name if match_info.source_file else "unknown"
                    print(f"      + {sib:<52} [{match_info.matched_via}] (Source: {src_name})")
                else:
                    print(f"      + {sib}")

    if result.unresolved_items:
        print(f"\n[-] Standalone / Unresolved Items ({len(result.unresolved_items)}):")
        display_unres = result.unresolved_items if opts.verbose else result.unresolved_items[:10]
        for unres in display_unres:
            print(f"    - {unres} (No sibling records or $instances found)")
        if not opts.verbose and len(result.unresolved_items) > 10:
            print(f"    ... and {len(result.unresolved_items) - 10} more. Run with -v for full list.")

    # 6. Save Expanded Presets
    if not opts.dry_run:
        if result.has_changes or output_path != input_path:
            repo.save(output_path, expanded)
            print(f"\n[+] Successfully saved {len(expanded)} entries to: {output_path}")
        else:
            print("\n[*] No new variants found. Existing file left unchanged.")
    else:
        print("\n[!] Dry run completed: no changes written to disk.")

    print("=================================================================\n")

    if is_interactive and sys.stdin and sys.stdin.isatty():
        try:
            input("Press Enter to exit...")
        except (EOFError, KeyboardInterrupt):
            pass

    return 0


if __name__ == "__main__":
    sys.exit(main())
