# Project Instructions — Immersive Footwear POV

## 1. REDscript Verification & Deployment
- **Always use `tools/pack_and_deploy.ps1` to verify REDscript**:
  - Whenever making changes to `.reds` files, raw assets, or mod resources, deploy and verify compilation by executing:
    ```powershell
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "tools\pack_and_deploy.ps1"
    ```
  - **Never run manual ad-hoc `scc.exe` commands**. `tools/pack_and_deploy.ps1` packages the CR2W animgraph archive, synchronizes scripts, tweaks, storages, and CET modules to the game folder, and runs `scc.exe` against the authoritative game cache with all dependencies properly configured.
  - Step 5 must exit with `[+] REDscript compilation verified successfully!`.

## 2. Release Packaging
- **Demand-Driven Packaging**: NEVER generate, update, or rebuild release `.zip` archives (standard, beta, or experimental) as part of routine bug fixes, refactoring, or deployments.
- Only package `.zip` archives when the user explicitly requests packaging (e.g. "create release zips", "package beta").
- See `.agents/rules/release-packaging.md` for full packaging rules.

## 3. REDscript Coding & Logging Guidelines
- **Logging**: Use native `FTLog`, `FTLogWarning`, and `FTLogError`. Never use `LogChannel(...)` or third-party logger dependencies directly in core modules.
- **Dependency Resilience**: Use `@if(ModuleExists(...))` at the method level for detector checks (`IsPresent()`), and at the import/class level when importing or referencing types from optional mod integrations (`RedWindows`, `RedscriptConfigFramework`, `RedFunctions`, `RedLogger`, `EquipmentEx`, `TrueFirstPerson`, `NegotiableThirdPerson`).
- **SOLID Architecture**: Keep 100% of gameplay, elevation, camera, and locomotion math in REDscript; keep CET strictly as a dormant configuration/calibration fallback.
