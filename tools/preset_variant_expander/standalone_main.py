"""
Standalone entrypoint for Preset Variant Expander.
Used by PyInstaller to build a portable Windows executable.
Supports standalone compilation via `--build`.
"""
import os
import shutil
import subprocess
import sys
import zipfile

# Ensure the project root is on sys.path
current_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.dirname(os.path.dirname(current_dir))
if project_root not in sys.path:
    sys.path.insert(0, project_root)

if getattr(sys, "frozen", False):
    # Running inside PyInstaller bundle
    bundle_dir = getattr(sys, "_MEIPASS", os.path.dirname(os.path.abspath(__file__)))
    if bundle_dir not in sys.path:
        sys.path.insert(0, bundle_dir)


def build_standalone() -> int:
    """Builds the standalone single-file Windows executable and distribution zip using PyInstaller."""
    print("=================================================================", flush=True)
    print("  Building PresetVariantExpander Standalone Windows Executable   ", flush=True)
    print("=================================================================", flush=True)

    spec_file = os.path.join(project_root, "PresetVariantExpander.spec")
    dist_dir = os.path.join(project_root, "dist")
    standalone_folder = os.path.join(dist_dir, "PresetVariantExpander-Standalone")
    standalone_zip = os.path.join(dist_dir, "PresetVariantExpander-Standalone.zip")

    cmd = [
        sys.executable,
        "-m",
        "PyInstaller",
        "--clean",
        "--noconfirm",
        spec_file if os.path.exists(spec_file) else os.path.join(current_dir, "standalone_main.py"),
    ]

    print(f"[*] Executing PyInstaller build:\n    {' '.join(cmd)}\n", flush=True)
    result = subprocess.run(cmd, cwd=project_root)
    if result.returncode != 0:
        print("[!] PyInstaller build failed.", file=sys.stderr, flush=True)
        return result.returncode

    exe_path = os.path.join(dist_dir, "PresetVariantExpander.exe")
    if not os.path.exists(exe_path):
        print(f"[!] Expected built executable not found at: {exe_path}", file=sys.stderr, flush=True)
        return 1

    print(f"\n[+] Successfully built: {exe_path} ({os.path.getsize(exe_path):,} bytes)", flush=True)

    # Prepare standalone release directory
    os.makedirs(standalone_folder, exist_ok=True)
    target_exe = os.path.join(standalone_folder, "PresetVariantExpander.exe")
    shutil.copy2(exe_path, target_exe)

    # Ensure README.txt exists in standalone distribution folder
    readme_path = os.path.join(standalone_folder, "README.txt")
    if not os.path.exists(readme_path):
        with open(readme_path, "w", encoding="utf-8") as f:
            f.write(
                "================================================================================\n"
                "   Immersive Footwear POV — Preset Variant Expander (Standalone Edition)        \n"
                "================================================================================\n\n"
                "Double-click PresetVariantExpander.exe to launch the interactive wizard.\n"
            )

    # Pack Standalone zip
    print(f"[*] Packaging distribution archive: {standalone_zip} ...", flush=True)
    with zipfile.ZipFile(standalone_zip, "w", zipfile.ZIP_DEFLATED) as zf:
        for root, _, files in os.walk(standalone_folder):
            for file in files:
                full_path = os.path.join(root, file)
                rel_path = os.path.join("PresetVariantExpander-Standalone", os.path.relpath(full_path, standalone_folder))
                zf.write(full_path, rel_path)

    print(f"[+] Successfully packaged: {standalone_zip} ({os.path.getsize(standalone_zip):,} bytes)", flush=True)
    print("=================================================================\n", flush=True)
    return 0


from tools.preset_variant_expander.cli.main import main

if __name__ == "__main__":
    if "--build" in sys.argv:
        sys.exit(build_standalone())
    else:
        sys.exit(main())
