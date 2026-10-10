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


def is_game_dir(path: Optional[Path]) -> bool:
    """Checks if a given directory path is a Cyberpunk 2077 game root directory."""
    try:
        if not path or not path.is_dir():
            return False
        # Primary check: bin/x64/Cyberpunk2077.exe exists
        if (path / "bin" / "x64" / "Cyberpunk2077.exe").is_file():
            return True
        # Structural check: r6/tweaks and bin/x64 exist
        if (path / "r6" / "tweaks").is_dir() and (path / "bin" / "x64").is_dir():
            return True
        # Additional game root check: r6, archive, and bin directories exist
        if (path / "r6").is_dir() and (path / "archive").is_dir() and (path / "bin").is_dir():
            return True
        return False
    except (PermissionError, OSError):
        return False


def find_enclosing_game_dir(start_path: Optional[Path] = None) -> Optional[Path]:
    """
    Detects if the tool is being executed from within a Cyberpunk 2077 game directory
    or any subdirectory of one.
    """
    candidates: List[Path] = []
    if start_path is not None:
        candidates.append(Path(start_path))
    else:
        try:
            candidates.append(Path.cwd())
        except Exception:
            pass

        if getattr(sys, "frozen", False):
            try:
                candidates.append(Path(sys.executable).resolve().parent)
            except Exception:
                pass

        try:
            if sys.argv and sys.argv[0]:
                candidates.append(Path(sys.argv[0]).resolve().parent)
        except Exception:
            pass

        try:
            candidates.append(Path(__file__).resolve().parent)
        except Exception:
            pass

    seen = set()
    for c in candidates:
        try:
            curr = c.resolve() if c.is_file() else c
            if curr.is_file():
                curr = curr.parent
            for parent in [curr] + list(curr.parents):
                try:
                    resolved = parent.resolve()
                except Exception:
                    resolved = parent
                norm_str = str(resolved).lower()
                if norm_str in seen:
                    continue
                seen.add(norm_str)
                if is_game_dir(resolved):
                    return resolved
        except Exception:
            continue
    return None


def _find_default_game_dir() -> Optional[Path]:
    enclosing = find_enclosing_game_dir()
    if enclosing:
        return enclosing
    for p in COMMON_GAME_DIRS:
        if is_game_dir(p):
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

    default_game = _find_default_game_dir()
    parser.add_argument(
        "-g", "--game-dir",
        type=Path,
        default=default_game if (default_game and default_game.exists()) else None,
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
        "--clean", "--filter-shoes",
        action="store_true",
        default=True,
        dest="clean",
        help="Sanitize preset pack by removing non-footwear clothing items (bras, dresses, suits, chokers, etc.). Enabled by default."
    )

    parser.add_argument(
        "--no-clean",
        action="store_false",
        dest="clean",
        help="Disable automatic non-footwear clothing sanitization."
    )

    parser.add_argument(
        "--clean-only",
        action="store_true",
        help="Only sanitize input presets without scanning game files or discovering variants."
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
        "-y", "--yes",
        action="store_true",
        help="Automatically answer yes to prompts (e.g. game folder confirmation)."
    )

    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Display detailed per-item match logs and source filenames."
    )

    return parser


def _interactive_wizard(detected_game_dir: Optional[Path] = None) -> Optional[List[str]]:
    """Interactive console wizard when launched without CLI arguments."""
    print("=================================================================", flush=True)
    print("      Immersive Footwear POV — Preset Variant Expander           ", flush=True)
    print("                      Interactive Mode                           ", flush=True)
    print("=================================================================\n", flush=True)

    game_dir = detected_game_dir or _find_default_game_dir()
    if detected_game_dir:
        print(f"[*] Game directory:\n    {game_dir}\n", flush=True)
    elif game_dir:
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
    print("  [3] Specify a custom input presets JSON file to expand")
    print("  [4] Sanitize a presets JSON file (purge non-footwear clothing items)")
    print("  [5] Exit")

    try:
        choice = input("\nChoice [1-5] (default 1): ").strip() or "1"
    except (EOFError, KeyboardInterrupt):
        return None

    if choice == "1":
        if user_overrides.exists():
            return ["-i", str(user_overrides), "-o", str(presets_file), "-g", str(game_dir), "-v", "-y"]
        elif presets_file.exists():
            return ["-i", str(presets_file), "-g", str(game_dir), "-v", "-y"]
        else:
            print("[!] Neither user_shoe_overrides.json nor presets.json found in mod folder.", file=sys.stderr)
            return None
    elif choice == "2":
        if user_overrides.exists():
            return ["-i", str(user_overrides), "-g", str(game_dir), "-v", "-y"]
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
        return ["-i", str(p_in), "-g", str(game_dir), "-v", "-y"]
    elif choice == "4":
        try:
            custom_in = input("Enter input presets JSON path to sanitize: ").strip().strip('"')
        except (EOFError, KeyboardInterrupt):
            return None
        p_in = Path(custom_in)
        if not p_in.exists():
            print(f"[!] File not found: {p_in}", file=sys.stderr)
            return None
        return ["-i", str(p_in), "--clean-only", "-v", "-y"]
    else:
        return None


def main(args=None) -> int:
    raw_args = sys.argv[1:] if args is None else list(args)
    is_help = any(a in ("-h", "--help") for a in raw_args)

    enclosing_game_dir = find_enclosing_game_dir()
    if enclosing_game_dir and not is_help:
        skip_confirm = any(a in ("-y", "--yes") for a in raw_args)
        print("=================================================================", flush=True)
        print("      Immersive Footwear POV — Preset Variant Expander           ", flush=True)
        print("=================================================================", flush=True)
        print(f"[*] Detected that the tool is running inside the Cyberpunk 2077 game directory:\n    {enclosing_game_dir}\n", flush=True)

        if skip_confirm:
            print("[*] Proceeding (-y specified).\n", flush=True)
        else:
            while True:
                try:
                    choice = input("Do you want to proceed? [Y/n]: ").strip().lower()
                except (EOFError, KeyboardInterrupt):
                    print("\n[*] Operation cancelled.", flush=True)
                    return 0
                if choice in ("", "y", "yes"):
                    print()
                    break
                elif choice in ("n", "no"):
                    print("[*] Operation cancelled by user.", flush=True)
                    return 0
                else:
                    print("Please enter 'y' to proceed or 'n' to cancel.", flush=True)

    is_interactive = False
    if args is None:
        if len(sys.argv) == 2 and sys.argv[1].lower().endswith(".json") and Path(sys.argv[1]).exists():
            # Drag-and-drop mode
            args = ["-i", sys.argv[1], "-v"]
            if enclosing_game_dir:
                args.extend(["-g", str(enclosing_game_dir), "-y"])
            is_interactive = True
        elif len(sys.argv) == 1:
            # Interactive Mode
            is_interactive = True
            args = _interactive_wizard(detected_game_dir=enclosing_game_dir)
            if args is None:
                return 0

    parser = create_parser()
    opts = parser.parse_args(args)

    if not opts.game_dir:
        opts.game_dir = enclosing_game_dir or _find_default_game_dir()

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
    if opts.game_dir:
        print(f"[*] Game dir:      {opts.game_dir}", flush=True)

    # 1. Load Presets
    repo = JsonPresetRepository()
    try:
        presets = repo.load(input_path)
    except Exception as e:
        print(f"[!] Error loading presets: {e}", file=sys.stderr, flush=True)
        return 1

    purged_items: List[str] = []
    if opts.clean:
        presets, purged_items = repo.sanitize(presets)
        if purged_items:
            print(f"[!] Clean Filter: Purged {len(purged_items)} non-footwear clothing item(s) from presets:", flush=True)
            display_purged = purged_items if opts.verbose else purged_items[:10]
            for p in display_purged:
                print(f"      - {p}")
            if not opts.verbose and len(purged_items) > 10:
                print(f"      ... and {len(purged_items) - 10} more. Run with -v to view all.")
            print()

    print(f"[*] Loaded {len(presets)} incoming preset footwear item(s).\n", flush=True)

    if not presets and not purged_items:
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
        if opts.clean:
            # Standalone clean mode without game directory scans
            if not opts.dry_run:
                repo.save(output_path, presets)
                print(f"\n[+] Successfully sanitized and saved {len(presets)} footwear entries to: {output_path}")
            else:
                print(f"\n[!] Dry run completed: {len(presets)} footwear entries would be saved (purged {len(purged_items)} non-shoe items).")
            return 0
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
    result.cleaned_non_footwear = purged_items

    # 5. Display Summary Report
    print("\n---------------------- Expansion Report -------------------------")
    print(f"[*] Initial Items:          {result.initial_items_count}")
    if result.cleaned_non_footwear:
        print(f"[-] Purged Non-Footwear:    {len(result.cleaned_non_footwear)}")
    print(f"[+] Sibling Variants Added: {result.new_variants_added}")
    if result.ignored_non_footwear:
        print(f"[-] Blocked Non-Footwear:   {len(result.ignored_non_footwear)}")
    print(f"[*] Total Expanded Items:   {result.total_items_count}")

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
