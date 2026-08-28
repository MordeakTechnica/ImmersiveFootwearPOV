# Changelog — Immersive Footwear POV

All notable changes to this project are tracked in this file chronologically by Git commit ID.

---

## [`775eb40`](https://github.com/mordeak/immersive-footwear-pov/commit/775eb40) — 2026-08-28
### `docs(readme, ui): update integration guide for modders and add in-game height guide`
* **Modder Integration Guide:** Updated [`README.md`](file:///c:/Users/cogli/Documents/CyberPunk%20-%20Projects/Immersive%20Footwear%20POV/README.md) with dual-height formula, Blender/Photo Mode measurement steps, supported aliases up to 25 cm, and in-game tag verification instructions.
* **In-Game CET UI:** Added descriptive slider helper subtext and collapsible `Shoe Height Guide & Anatomy` dropdown in the CET overlay.

---

## [`6e91217`](https://github.com/mordeak/immersive-footwear-pov/commit/6e91217) — 2026-08-28
### `docs: add USER_GUIDE.md for custom shoe height setup and Photo Mode measurement`
* Created dedicated player guide [`USER_GUIDE.md`](file:///c:/Users/cogli/Documents/CyberPunk%20-%20Projects/Immersive%20Footwear%20POV/USER_GUIDE.md) explaining FPP Heel vs Photo Mode Platform concepts, CET overlay controls, auto-saving, and step-by-step measurement instructions using Photo Mode's V Up/Down slider.

---

## [`eda70a0`](https://github.com/mordeak/immersive-footwear-pov/commit/eda70a0) — 2026-08-28
### `feat(debug): add optional FPP and Photo Mode transition debug logging via CET console`
* **Photo Mode Transition Telemetry:** Detailed logging of controller validity, active footwear tags, platform sole queuing, frame progression, and Attribute 37 (`upDown`) force status on PM `OnShow`, `OnUpdate`, and `OnHide`.
* **FPP Stance Transition Telemetry:** Detailed logging of mathematical linear/smoothstep blend transitions with start/target heights, elapsed time, and trigger reasons (e.g. suppression, shoe switch, Photo Mode).
* **Console-Only Control Architecture:**
  * **CET Console Methods & Shortcuts:** Added `ToggleIFPDebug()`, `IFPDebug(true/false)`, `IFPStatus()`, `GetMod("ImmersiveFootwearPOV"):SetDebug(bool)`, `ToggleDebug()`, `GetDebug()`, and `DumpState()`.
  * **Persistence:** Debug preference persisted across sessions in `user_shoe_overrides.json` under `__settings.debugLogs`.
* **REDscript Synchronization:** Synchronized debug mode to `ImmersiveFootwearPOVSystem` with dedicated `LogChannel(n"DEBUG", ...)` logging for state suppression changes and shoe resolution.

---

## [`b606a49`](https://github.com/mordeak/immersive-footwear-pov/commit/b606a49cb55877f6b9ce82fe7f000305f6e80b2d) — 2026-08-27
### `feat(photomode): add native attribute 37 platform elevation, stance neutralization, and CET toggle`
* **Locomotion Neutralization:** Automatically eases first-person locomotion height blend to neutral (0.0m) in Photo Mode, restoring smoothly upon exit.
* **Native Attribute 37 Elevation:** Drives native REDengine Photo Mode Attribute 37 (`upDown`) to elevate character root by equipped platform sole thickness.
* **CET Controls:** Added `Auto-Elevate Platform Sole in Photo Mode` toggle in CET overlay (persisted across sessions in `user_shoe_overrides.json`).
* **Standalone Architecture:** Operates on native REDengine APIs with zero dependencies on third-party Photo Mode mods.

---

## [`ffd4d73`](https://github.com/mordeak/immersive-footwear-pov/commit/ffd4d73c7eef78b9ec437c35f2d7a2fa5b7f7fbb) — 2026-08-27
### `refactor(integrations): reorganize IFP integration into dedicated REDscript and CET modules`
* **REDscript Structure:** Created `Integrations/ImmersiveFootwearPOV_IFP.reds` to isolate the `ifp_height_blend` animgraph variable driver in `Integrations/` and removed the old root `ImmersiveFootwearPOV_HeightController.reds`.
* **CET Architecture:** Created `integrations/ifp.lua` encapsulating IFP API polling, additive stance blend math, and window rendering, modularizing `init.lua`.
* **Suppression Fix:** Cleaned up lifecycle hooks to preserve suppression integrity during normal gameplay.

---

## [`1f42193`](https://github.com/mordeak/immersive-footwear-pov/commit/1f42193563914a13e2bb97f7fa2ff82c9e782e4e) — 2026-08-27
### `docs: add CHANGES.md tracking all changes by git commit id`
* Initialized project changelog document tracking all historical git commit IDs, dates, and component changes chronologically.

---

## [`c50ae38`](https://github.com/mordeak/immersive-footwear-pov/commit/c50ae386a75b58111fffe35f289ac2331cf4981e) — 2026-08-27
### `feat(height-limits): centralize 25cm limit in enum and raise custom sliders`
* **REDscript:** Added `FootwearHeightLimit` enum and `FootwearHeightLimits` helper class in `ImmersiveFootwearPOV_TweakReader.reds` defining centralized `MaxHeightCm = 25` and `MaxPlatformCm = 25`.
* **Tag Parser:** Updated `ConvertValueToMeters` and `ClampHeight` to dynamically query `FootwearHeightLimits` to enforce bounds.
* **CET Overlay UI:** Added `FootwearHeightLimits` configuration table at top of `init.lua` and raised custom sliders from `0..15cm` / `0..10cm` to `0.0..25.0cm`.

---

## [`c9d878a`](https://github.com/mordeak/immersive-footwear-pov/commit/c9d878ad9ee5ea6978b79af7cc5b3a546fc45e6d) — 2026-08-27
### `feat(cet): add dynamic IFP detection and graceful standalone fallback`
* **Dynamic Framework Detection:** Added checks for `ImmersiveFirstPerson` and its in-memory height state API.
* **Adaptive CET Overlay UI:** 
  * Seamlessly appends inside IFP's window when IFP is installed.
  * Spawns standalone `"Immersive Footwear POV"` CET window with an informative warning banner when IFP is not installed.
  * Displays a notice if `ImmersiveFirstPersonHeight.archive` is missing from `archive/pc/mod`.
* **Zero-Crash Graceful Degradation:** All footwear resolution, custom override saving/loading, and TweakDB parsing operate cleanly without errors in standalone mode.

---

## [`0257329`](https://github.com/mordeak/immersive-footwear-pov/commit/02573290ace2ccbffb049ebfa9c145a019edf793) — 2026-08-27
### `chore(git): add examples folder to .gitignore`
* Updated `.gitignore` to ignore the `examples/` directory and test files.

---

## [`8df379b`](https://github.com/mordeak/immersive-footwear-pov/commit/8df379b4bf2f1ee991cf68b42997f48ec5b1ce4d) — 2026-08-27
### `fix(equipment-ex): resolve slot items via TransactionSystem.GetItemInSlot`
* **Bug Fix:** Fixed REDscript compilation failure (`method 'GetEquippedItemInSlot' not found on 'EquipmentEx.OutfitSystem'`).
* **Implementation:** Updated `ImmersiveFootwearPOV_EquipmentEx.reds` to query items equipped in Equipment-EX slots using `TransactionSystem.GetItemInSlot(player, slotID)`.

---

## [`dec9b9b`](https://github.com/mordeak/immersive-footwear-pov/commit/dec9b9bc87a0ead10ddf97d8608334a18ae81ae0) — 2026-08-27
### `fix(ui, logs): add dedicated CET mod window and silence all routine console logging`
* **Logging Cleanup:** Silenced all routine `LogChannel(n"DEBUG", ...)` statements in `ImmersiveFootwearPOV_System.reds` and `ImmersiveFootwearPOV_HeightController.reds`.
* **Window Management:** Cleaned up overlay draw registration.

---

## [`c43f616`](https://github.com/mordeak/immersive-footwear-pov/commit/c43f616fd08917496845a3e5b55f39fdb40337fd) — 2026-08-27
### `feat(photomode): add automatic platform height elevation and CET controls for Photo Mode`
* Added Photo Mode lifecycle hooks (`gameuiPhotoModeMenuController.OnShow` and `OnHide`).
* Automatically evaluates and applies `platformCm` (front sole thickness) when entering Photo Mode.
* Added interactive CET toggle to customize or disable auto-application.

---

## [`9791cfb`](https://github.com/mordeak/immersive-footwear-pov/commit/9791cfb4178558b17d37aa80cc208bfac92b197d) — 2026-08-27
### `docs: remove Native Settings UI from project roadmap`
* Updated `PROJECT.md` to remove Native Settings UI from Phase 5 per project scope refinement.

---

## [`128118a`](https://github.com/mordeak/immersive-footwear-pov/commit/128118ad3ad98b43ec516b5f9b6f9efdfbb7f45d) — 2026-08-27
### `Initial commit: Immersive Footwear POV v1.0.0-beta-1`
* Initial project setup and release tagging `v1.0.0-beta-1`.
* Full dual-height TweakDB parser (`HeelHeight_XXX` and `PlatformHeight_XXX`).
* Dynamic CET bridge connecting IFP base height slider + footwear heel height with `smoothstep` transitions.
* Context-aware state suppression for vehicles, workspots (chairs, beds), scenes, and ladders.
* JSON persistence for untagged custom per-shoe overrides.
