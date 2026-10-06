# Changelog — Immersive Footwear POV

All notable changes to this project are tracked in this file chronologically by Git commit ID.

## [`Unreleased`] — 2026-10-06
### `feat(ui): add manual height inputs with auto-clamping and non-negative validation`
* **Direct Numerical Input:** Added `Manual Heel (cm)` and `Manual Platform (cm)` input fields (`ImGui.InputFloat`) alongside the sliders in the CET overlay (`DrawCustomFootwearControls`), allowing players to type exact decimal values or click `+`/`-` stepper buttons.
* **Auto-Clamping on Exceeding Limits:** When manually entering values exceeding the maximum limits, values are automatically capped to the maximum allowed limit (`40.0 cm` for Heel Height, `30.0 cm` for Platform Height).
* **Non-Negative Value Enforcement:** Negative values are strictly disallowed and automatically clamped to `0.0 cm`.
* **CET Console Shortcuts:** Added `SetFootwearHeight(heelCm, platformCm)` and `SetCustomHeight(heelCm, platformCm)` console commands supporting the same bounds clamping and auto-saving per equipped shoe.

### `feat(height-limits): raise platform to 30cm and heel to 40cm for sway, with strict 25cm IFP cap`
* **Third-Person & Photo Mode Platform (30cm):** Increased maximum platform height limit (`MaxPlatformCm`) from `25cm` to `30cm` across REDscript and CET overlay (`FootwearHeightLimits.MAX_PLATFORM_CM = 30.0`).
* **Third-Person Sway Incline (40cm Heel):** Increased maximum heel height limit (`MaxHeightCm`) to `40cm` (`FootwearHeightLimits.MAX_HEEL_CM = 40.0`), allowing up to +10cm effective heel pitch on 30cm maxed-out platforms to activate 100% max catwalk sway.
* **Strict IFP 25cm Ceiling:** Maintained and enforced that First-Person / IFP camera elevation and effective height offset (`m_effectiveOffset`, `HeightController`, and `FootwearHeightLimits.MAX_IFP_CM`) never exceed `25cm / 0.25m` (`MaxIFPCm`).
* **Platform & Heel Parsing:** Added `ShoeHeightParser.ClampPlatformHeight`, `ClampIFPHeight`, and `ConvertPlatformValueToMeters` supporting up to `30cm` platform and `40cm` heel tags.
* **UI & Documentation:** Updated Custom Heel slider (`0.0 – 40.0 cm`) and Custom Platform slider (`0.0 – 30.0 cm`) in the CET overlay, player guide (`USER_GUIDE.md`), `README.md`, and `PROJECT.md`.

---

## [**`v2.1.0`**](https://github.com/mordeak/immersive-footwear-pov/releases/tag/v2.1.0) — 2026-09-29
### `feat(stride): add per-heel sway multipliers and clean catwalk tab`
* **Independent Heel Category Multipliers:** Added dedicated sliders for **Low Heel** (1.0" – 2.0" / ~2.0 – 5.0 cm), **Mid Heel** (2.0" – 3.0" / ~5.0 – 7.5 cm), and **High Heel** (3.0"+ / ~7.5+ cm) allowing players to fine-tune sway intensity independently per heel height (0.00x – 1.50x).
* **Removed Global Multiplier:** Removed the legacy global sway intensity slider in favor of the per-heel multipliers, with automatic backwards compatibility for existing user configuration files.
* **Simplified Hip Sway UI:** Renamed the second settings tab to "Hip Sway" and removed raw live diagnostic telemetry (stride status and live joint angles), cleanly displaying the master toggle, per-heel multipliers, and active shoe sway context.

### `refactor(core): remove dead getter aliases and duplicate logic`
* **REDscript Cleanup:** Removed obsolete unreferenced getters `GetCurrentShoeHeight` and `GetBodyOffset` from `ImmersiveFootwearPOV_System.reds`, consolidated `ReadShoeHeight` to forward to canonical `ReadHeelHeight` in `ImmersiveFootwearPOV_TweakReader.reds`, and standardized `EquipmentEx` integration.
* **CET Optimization:** Removed redundant duplicate console shortcut declarations in `init.lua`.

### `feat(stride): synchronize pelvic z-axis yaw rotation with stepping leg`
* **Advancing Leg Synchronization:** Inverted kinematic yaw phase so that positive Z-axis rotation aligns with the forward-reaching left leg and negative with the right leg, ensuring the pelvis naturally rotates forward with the reaching foot and back with the trailing foot.
* **Calibrated Yaw Amplitude & Counter-Balance:** Adjusted baseline yaw to $3.0^\circ$ and increased thoracic counter-yaw ratio on `Spine2` to $-0.55\times$, preserving stable shoulders and natural arm swing.
* **Reference Documentation:** Updated `AXIS_REFERENCE.md` with the synchronized forward-reach descriptions and new baseline values.

---

## [`152db69`](https://github.com/mordeak/immersive-footwear-pov/commit/152db69) — 2026-09-29
### `feat(stride): add variable catwalk sway scaling based on effective heel pitch`
* **Effective Heel Pitch (Plantarflexion) Calculation:** Evaluated effective heel rise ($\max(0, \text{heelCm} - \text{platformCm})$) in native REDscript `SwayEvaluator`. Barefoot, flat shoes, and pure platforms (where platform sole matches or exceeds heel height) produce 0% sway, ensuring flatforms remain in a natural neutral stride.
* **Biomechanical Inch Benchmarks:** Scaled catwalk pelvic roll and yaw according to empirical gait and ankle plantarflexion benchmarks:
  * `< 2.0 cm` (`< 0.8"`): Flat / Barefoot / Pure Platform (0% sway — neutral baseline).
  * `1.0"` (`~2.54 cm`): Low / Kitten Heel (~35% sway — subtle feminine hip roll).
  * `2.0"` (`~5.08 cm`): Mid Heel (~70% sway — moderate catwalk stride).
  * `>= 3.0"` (`7.50 cm` and above): High Heel / Stiletto (100% max sway — full runway catwalk locomotion).
* **CET Overlay Biomechanical Breakdown:** Added a live footwear incline card in the "Catwalk Locomotion [Beta]" tab displaying effective heel rise in centimeters and inches, current sway tier, and scale percentage.

---

## [`b793d63`](https://github.com/mordeak/immersive-footwear-pov/commit/b793d63) — 2026-09-28
### `tune(stride): cap hip sway intensity slider maximum to 1.50x`
* **Slider Range:** Capped maximum user intensity multiplier on catwalk locomotion from `2.50x` to `1.50x`.

---

## [`daf338f`](https://github.com/mordeak/immersive-footwear-pov/commit/daf338f) — 2026-09-28
### `refactor(stride): delegate sway evaluation to REDscript and add tabbed UI in CET`
* **REDscript Locomotion & Sway Evaluator:** Created `SwayContextData` and `SwayEvaluator` in `ImmersiveFootwearPOV_Suppression.reds` to authoritatively evaluate locomotion states, velocity thresholds, general suppression (vehicles, workspots, scenes, ladders, photo mode), PSM blackboards (crouch, sprint, jump, slide, dodge, climb, ADS), and non-linear heel-height scaling in native game code.
* **Strict ITP Requirement & FPP Removal:** Enforced that catwalk locomotion strictly requires `Immersive Third Person (ITP)` installed and active (`IsITPPresent` and `IsTPPActive`). Dropped all FPP camera bobbing and headbob decoupling logic until future camera matrix revisions.
* **Optimized CET Stride Loop:** Refactored `stride.lua` to remove redundant blackboard polling, querying `sys:GetSwayContext(player)` once per tick while preserving the high-frequency kinematic oscillator integration and animation variable publishing.
* **Tabbed Dear ImGui Overlay:** Updated CET settings window to introduce a clean tabbed layout:
  * **Tab 1: Footwear & Stance:** Houses active footwear diagnostics, height calibration slider, height guide accordion, and photo mode controls.
  * **Tab 2: Catwalk Locomotion [Beta]:** Houses the 3rd-person catwalk sway master toggle, intensity slider, real-time diagnostic angles, and an ITP dependency validation card.

---

## [`0846e33`](https://github.com/mordeak/immersive-footwear-pov/commit/0846e337e6f80da1d8a4369e96e73bb93f0b2f56) — 2026-09-28 · [**`v2.0.3`**](https://github.com/mordeak/immersive-footwear-pov/releases/tag/v2.0.3)
### `fix(redlogger): use native FTLog in FootwearRedLogger fallback when RedLogger is not installed`
* **Native REDengine Logging Compatibility:** Fixed compilation error (`function 'Log' not found`) occurring on players' systems where `RedLogger` is not installed.
* **Vanilla Engine Functions:** Updated `FootwearRedLogger` fallback to use REDengine's universal native built-in logging functions (`FTLog`, `FTLogWarning`, and `FTLogError`), which are defined in base game `final.redscripts` and require zero third-party dependencies or external function declarations.

---

## [`ce7d088`](https://github.com/mordeak/immersive-footwear-pov/commit/ce7d0882e3c04be66e4aef9b26e109d73d2ff936) — 2026-09-27 · [**`v2.0.2`**](https://github.com/mordeak/immersive-footwear-pov/releases/tag/v2.0.2)
### `fix(equipment-ex): resolve unresolved GetEquippedItemInSlot method for official Equipment-EX`
* **Official Equipment-EX Compatibility:** Resolved unresolved method compiler error (`method 'GetEquippedItemInSlot' not found on 'EquipmentEx.OutfitSystem'`).
* **Universal Footwear Resolution:** Updated `EquipmentExHelper.GetFootwearFromOutfit` to delegate directly to `EquipmentExHelper.GetActiveFootwear(player)` when the outfit is equipped, utilizing REDengine's native `TransactionSystem.GetItemInSlot` and standard Equipment-EX slot APIs supported across all official releases (v1.0 - v1.2.9+).
* **Photo Mode Delayed Inspection Fallback:** Preserved `pm.lua` delayed puppet inspection fallback so that any asynchronous mesh attachment or unequipped outfit preview gracefully settles to accurate elevation without errors.

---

## [`a880177`](https://github.com/mordeak/immersive-footwear-pov/commit/a88017700f7e903ee624c2c2031769f7284f1c62) — 2026-09-27 · [**`v2.0.1`**](https://github.com/mordeak/immersive-footwear-pov/releases/tag/v2.0.1)
### `fix(equipment-ex): resolve REDscript compilation error on official Equipment-EX`
* **Official Equipment-EX Compatibility:** Removed call to `outfitSys.GetOutfitParts(outfitName)`, which does not exist in official releases of Equipment-EX.
* **Safe Footwear Resolution:** Updated `EquipmentExHelper.GetFootwearFromOutfit` to query currently equipped items via `outfitSys.IsEquipped`.
* **Photo Mode Delayed Inspection Fallback:** Updated `pm.lua` so that when switching outfits in Photo Mode, any footwear not immediately resolvable by name gracefully defers to the existing 8-frame delayed mesh inspection on the puppet, guaranteeing accurate elevation for all shoes, platforms, and flat/barefoot outfits without errors.

---

## [`5805e15`](https://github.com/mordeak/immersive-footwear-pov/commit/5805e15ee388b98cd763ddfcaedf9c2965186dad) — 2026-09-26 · [**`v2.0.0`**](https://github.com/mordeak/immersive-footwear-pov/releases/tag/v2.0.0)
### `feat(logging): integrate RedLogger with centralized logging, dynamic mod tagging, and photo mode fix`
* **RedLogger Centralized Logging:** Integrated [RedLogger](https://www.nexusmods.com/cyberpunk2077/mods/31920) via soft-dependency guards (`@if(ModuleExists("RedLogger"))`), channeling all REDscript and CET log statements into a single file at `r6\logs\mods\ImmersiveFootwearPOV__<timestamp>.log`.
* **Dynamic Mod Tagging:** Automatically tag log lines based on the active/installed camera framework (`[ITP]`, `[IFP]`, `[TFP]`, or `[PM]` fallback).
* **Photo Mode Detection Fix:** Eliminated premature Photo Mode flag caused by an ink UI controller `OnInitialize` hook running at game launch. Replaced with real-time native `PhotoModeSystem.IsPhotoModeActive()` query.
* **Instant CET ITP Detection:** Added direct `GetMod("immersive_third_person")` lookup to ensure ITP registration occurs at engine startup before player entity instantiation.

---

## [`cebe255`](https://github.com/mordeak/immersive-footwear-pov/commit/cebe25559079608beaaf104ec066a4cf1ff08b74) — 2026-09-26
### `refactor(redscript): decouple event hooks, enforce logging standards, and unify animgraph blend calculation`
* **Hooks Decoupling:** Removed direct `TFPHelper` integration calls (`LogState`, `LogEvent`, `SyncWeaponForCurrentFootwear`) from `FootwearHooksHelper` in `ImmersiveFootwearPOV_Hooks.reds`. All events now route strictly through `ImmersiveFootwearPOVSystem`.
* **Logging Compliance:** Eliminated forbidden `LogChannel(n"DEBUG", ...)` calls in `ImmersiveFootwearPOV_TFP.reds` in adherence with `redscript-logging.md`, standardizing on native `Log(...)` guarded by `sys.IsDebugLogging()`.
* **Animgraph Blend Math Unification:** Added `FootwearAnimgraphHelper.CalculateHeightBlend` in `ImmersiveFootwearPOV_Framework.reds` to centralize the `-0.50m..+0.50m` animgraph blend calculation across both IFP and ITP integrations.
* **ITP Elevation Reset Fix:** Fixed `ITPController.ResetHeightOffset` to reset `ifp_height_blend` back to neutral baseline (`0.50`) alongside `foot_elevation_offset = 0.0`.
* **Action Filter Simplification:** Replaced repetitive chained boolean checks in `OnAction` with `FootwearHooksHelper.IsWeaponAction`.

---

## [`58f346f`](https://github.com/mordeak/immersive-footwear-pov/commit/58f346fcd9d32eb61085eaa96ff4c82e7e84b463) — 2026-09-26
### `fix(hooks): correct PlayerPuppet.OnGameAttached return type to Bool to avoid breaking other wrapped mods`
* Corrected `PlayerPuppet.OnGameAttached` wrapMethod in `ImmersiveFootwearPOV_Hooks.reds` to return `Bool` and return `wrappedMethod()` result, preventing compilation errors and breakage with other wrapped mods on Cyberpunk 2077 Patch 2.1+.

---

## [`6399862`](https://github.com/mordeak/immersive-footwear-pov/commit/63998627e5f97cf69d6a5a4b11bc9a6540087c52) — 2026-09-26
### `fix(ifp): restore first-person heel height elevation across all perspective states`
* Fixed first-person camera height calculation in `init.lua` ensuring FPP heel height elevation is smoothly driven and restored across perspective state transitions.
* Guarded against improper suppression state overrides during perspective switching.

---

## [`c8d6751`](https://github.com/mordeak/immersive-footwear-pov/commit/c8d675115c5ead95314b4211802fb327ed3fa3c3) — 2026-09-26
### `feat(elevation): implement 3rd-person model height elevation with FPP reset`
* **Animgraph Elevation Node:** Injected root elevation blend node into `player_base.animgraph` driven by `ifp_height_blend` and `foot_elevation_offset`.
* **Priority Archive Packaging:** Named priority archive `##_ITP_Immersive_Footwear_POV.archive` to ensure precedence over third-person mods in ASCII load order.
* **Camera Detection:** Implemented `CameraSystem`-based active camera world transform detection in CET and REDscript (`ITPController.IsTPPActive`).
* **Perspective Neutralization:** Automatically resets character model height to neutral baseline (`0.0m`) when returning to first-person view.
* Untracked development scripts and updated `.gitignore`.

---

## [`471f173`](https://github.com/mordeak/immersive-footwear-pov/commit/471f173491a966a1aabc895f0386ba3a9561cc92) — 2026-09-24
### `feat(archive): add zz_Immersive_Footwear_POV.archive to release resources`
* Added precompiled release archive `zz_Immersive_Footwear_POV.archive` containing the base gameplay elevation animgraph.

---

## [`20debc7`](https://github.com/mordeak/immersive-footwear-pov/commit/20debc77de759072179bf6e9565e97b227c1414d) — 2026-09-24
### `fix(itp): switch third-person elevation to platform height and normalize animgraph blend formula`
* Switched third-person elevation driver in `ITPController` to use `GetEffectivePlatformOffset()` instead of heel height.
* Normalized animgraph blend formula mapping `-0.50m..+0.50m` range to `0.0..1.0` blend values.

---

## [`ac07ca2`](https://github.com/mordeak/immersive-footwear-pov/commit/ac07ca21cf83dde69f2440fdbe1db8b1ff0a68c9) — 2026-09-24
### `feat(deploy): add tweaks deployment step to automated pack and deploy tool`
* Enhanced `tools/pack_and_deploy.ps1` to automatically deploy TweakXL and resource files alongside compiled archives to the game installation directory.

---

## [`8199cac`](https://github.com/mordeak/immersive-footwear-pov/commit/8199cac5002771d473e73dabe2e6988febea79a2) — 2026-09-24
### `fix(packaging): enforce single zz_Immersive_Footwear_POV.archive filename across all targets`
* Standardized release archive name to `zz_Immersive_Footwear_POV.archive` across build scripts and deployment targets to eliminate packaging collisions.

---

## [`8940793`](https://github.com/mordeak/immersive-footwear-pov/commit/8940793f84c1bc2975657009c4b178aa93f9507b) — 2026-09-24
### `feat(tools): add automated packaging and deployment pipeline for ITP elevated archive`
* Created PowerShell automated build pipeline `tools/pack_and_deploy.ps1` utilizing WolvenKit CLI to convert raw animgraph JSON to CR2W, stage assets, pack `.archive` files, and deploy directly to test installations.

---

## [`798868e`](https://github.com/mordeak/immersive-footwear-pov/commit/798868ed4c470489c3e05e830e690a14115eabd5) — 2026-09-24
### `feat(itp): add automated animgraph injection script for ITP elevation`
* Developed Python automation utility `tools/inject_itp_elevation.py` to parse WolvenKit animgraph JSON and inject custom elevation blend nodes into `player_base.animgraph.json`.

---

## [`1fdf8cd`](https://github.com/mordeak/immersive-footwear-pov/commit/1fdf8cd6fe2b1f844dcb187c171a9b1bb2b0ebaf) — 2026-09-24
### `feat(itp): implement Immersive Third Person dynamic elevation integration and UI telemetry`
* Created `Integrations/ImmersiveFootwearPOV_ITP.reds` driving character model elevation via `AnimationControllerComponent.SetInputFloat` using custom variables `foot_elevation_offset` and `ifp_height_blend`.
* Added runtime ITP bridge detection and CET overlay telemetry indicating active TPP state and elevation metrics.

---

## [`9948164`](https://github.com/mordeak/immersive-footwear-pov/commit/99481648f90142565d0ad3a627a7ff38ecbbacb6) — 2026-09-24
### `fix(hooks): correct OnGameAttached return type to Void in PlayerPuppet wrapMethod`
* Fixed signature mismatch for `PlayerPuppet.OnGameAttached` wrapMethod in `ImmersiveFootwearPOV_Hooks.reds`.

---

## [`d09312d`](https://github.com/mordeak/immersive-footwear-pov/commit/d09312daaf536c3837cfb4cdded2298c054ce956) — 2026-09-03
### `refactor(cet): modularize orchestrator into config, logger, state, and transition modules`
* **Modular CET Architecture:**
  * Extracted JSON configuration and user override persistence into `modules/config.lua`.
  * Extracted debug logging, rate limiting, and console output into `modules/logger.lua`.
  * Extracted footwear state management and REDscript bridge syncing into `modules/state.lua`.
  * Extracted smoothstep transition interpolation and stance blend easing into `modules/transition.lua`.
* Streamlined `init.lua` to serve as a high-level lifecycle orchestrator.

---

## [`c654c62`](https://github.com/mordeak/immersive-footwear-pov/commit/c654c621fd3fc56cbad7ae80713d044dded8559d) — 2026-09-03
### `fix(ui): ensure mutually exclusive CET window attachment when IFP is enabled`
* Added native `IFP.IsEnabled()` verification before attaching CET controls to the IFP settings window.
* Enforced strict mutual exclusion to suppress redundant standalone window rendering when IFP is active.

---

## [`8aa311a`](https://github.com/mordeak/immersive-footwear-pov/commit/8aa311a2c958fbe7906564c8d87770a580aa9a5a) — 2026-09-01
### `feat(ui): universal CET configuration window for standalone, TFP, IFP, and Photo Mode`
* Implemented universal CET configuration window displaying contextual elevation metrics, active frameworks (IFP, TFP, Equipment-EX), Photo Mode settings, and debug toggles.

---

## [`de9b197`](https://github.com/mordeak/immersive-footwear-pov/commit/de9b19737995d3638510102266223fb4eb2e8431) — 2026-09-01
### `fix(tfp): ensure robust compilation with fully qualified imports and complete fallbacks`
* Added fully qualified module imports for `TrueFirstPerson` (`IFPSystem`, `IFPCamera`, `IFPConfig`, `IFPWeapon`).
* Provided complete, robust fallback implementations for all helper methods when `TrueFirstPerson` is not installed.

---

## [`f228aa2`](https://github.com/mordeak/immersive-footwear-pov/commit/f228aa2a5507ebecb0d2180519e82286c91667ce) — 2026-09-01
### `fix(tfp): add missing fallback stub for SyncWeaponForCurrentFootwear when TFP is not installed`
* Added missing fallback method stub `SyncWeaponForCurrentFootwear` to the `@if(!ModuleExists("TrueFirstPerson"))` class declaration in `ImmersiveFootwearPOV_TFP.reds`.

---

## [`80685ec`](https://github.com/mordeak/immersive-footwear-pov/commit/80685ec96d4f0c3fb25da2f3b598118e6dda06b0) — 2026-09-01
### `feat(rcf): implement in-game settings menu for testing and fix SetVehicleState syntax`
* Cleaned up syntax in vehicle state callback and verified experimental in-game configuration integration.

---

## [`98752f9`](https://github.com/mordeak/immersive-footwear-pov/commit/98752f9bea8cae5e394b82a48385162ac8ed4529) — 2026-09-01
### `feat(rcf): implement native in-game settings menu for heel & platform height adjustment`
* Added experimental in-game native menu interface for adjusting footwear heel and platform height offsets.

---

## [`eae50ae`](https://github.com/mordeak/immersive-footwear-pov/commit/eae50ae5c5509efd49f25ff2207e6ebffdb9d9b3) — 2026-09-01
### `fix(tfp): let TFP native cameraZ drive ADS sight alignment without mutating weapon configs`
* Refactored weapon ADS alignment to rely directly on TFP's native `cameraZ` elevation parameter via `weapon.RefreshCurrentWeapon(config.cameraZ, config)`, preventing weapon config mutation and sight drift.

---

## [`2d22c6f`](https://github.com/mordeak/immersive-footwear-pov/commit/2d22c6f6b3431bba397c504828ce00d00b607e5d) — 2026-09-01
### `feat(tfp): implement clean weapon baseline restoration on weapon switch and footwear change`
* Added weapon slot change hooks (`OnItemAddedToSlot` and `OnItemRemovedFromSlot`) in `ImmersiveFootwearPOV_Hooks.reds`.
* Guaranteed clean restoration of baseline weapon transforms upon switching weapons or unequipping footwear.

---

## [`4e0a6bb`](https://github.com/mordeak/immersive-footwear-pov/commit/4e0a6bb42365e83c5a3de3b9502c38e2a5a4b9a2) — 2026-09-01
### `feat(tfp): hook footwear lift into TFP per-weapon tuning pipeline`
* Integrated footwear elevation offset directly into TFP's per-weapon tuning pipeline to synchronize ADS reticle positions.

---

## [`952ba83`](https://github.com/mordeak/immersive-footwear-pov/commit/952ba83cb255a0cfea939f57feeacbd518e95747) — 2026-09-01
### `fix(tfp): resolve weapon flicker by replacing slot poke with native TFP weapon refresh`
* Resolved visual weapon jitter and transform flickering by replacing raw slot transform manipulation with native TFP weapon refresh mechanisms.

---

## [`1221aaa`](https://github.com/mordeak/immersive-footwear-pov/commit/1221aaa68553f2bd05f61fe21166cd0717adafc0) — 2026-09-01
### `fix(tfp): add save-load lifecycle readiness guards and preserve PokeSlotTransform`
* Added game instance and system readiness checks (`inkISystemRequestsHandler.IsPreGame()`, `player.IsAttached()`) to prevent null reference errors on game save loading.

---

## [`557744d`](https://github.com/mordeak/immersive-footwear-pov/commit/557744d83808ac1facb95709e3d19a2bb342a1e9) — 2026-09-01
### `feat(tfp): use TFPCNative.PokeSlotTransform for real-time physical weapon elevation`
* Implemented real-time physical weapon elevation synchronization using TFP native transform poking.

---

## [`1b3aecd`](https://github.com/mordeak/immersive-footwear-pov/commit/1b3aecd9910f8605cff673969c6c04cf71eb4dd1) — 2026-09-01
### `refactor(architecture): split ImmersiveFootwearPOV_System into modular Systems/ folder`
* **Architectural Decoupling:**
  * Extracted state suppression logic into `Systems/ImmersiveFootwearPOV_Suppression.reds`.
  * Extracted telemetry logging into `Systems/ImmersiveFootwearPOV_Telemetry.reds`.
  * Retained core ScriptableSystem state coordination in `Systems/ImmersiveFootwearPOV_System.reds`.

---

## [`57a431a`](https://github.com/mordeak/immersive-footwear-pov/commit/57a431a1fa0e72073cf63174ee92418c1dde962d) — 2026-09-01
### `refactor(system): flatten nested suppression logic in EvaluateSuppressionState`
* Simplified and flattened deeply nested conditional branches in `EvaluateSuppressionState` using early returns.

---

## [`cefa52c`](https://github.com/mordeak/immersive-footwear-pov/commit/cefa52c0d63e70483acc2dbab1d3cb9008ce2af8) — 2026-09-01
### `feat(tfp): implement Option A dynamic weapon height elevation with footwear lift`
* Added dynamic weapon viewmodel elevation aligned with footwear lift in True First Person mode.

---

## [`a033ec6`](https://github.com/mordeak/immersive-footwear-pov/commit/a033ec6cd11d22ef23ff4f1dd9183556aae78d3b) — 2026-09-01
### `feat(tfp): implement additive camera Z elevation, jitter fix, and save-load safety guards for True First Person`
* Added additive `cameraZ` elevation integration in `TFPHelper.ApplyFootwearHeight`.
* Fixed camera jitter and added lifecycle safety checks preventing execution during pre-game or unattached states.

---

## [`618c04a`](https://github.com/mordeak/immersive-footwear-pov/commit/618c04ad59734d6f7e27a091d3f64cd70f931e9e) — 2026-08-30
### `refactor(logging): replace LogChannel with native Log function and add .agents to gitignore`
* Replaced debug `LogChannel` calls with native REDscript `Log` statements in `ImmersiveFootwearPOV_System.reds`.
* Added `.agents` directory to `.gitignore`.

---

## [`f1870a2`](https://github.com/mordeak/immersive-footwear-pov/commit/f1870a286f9044c5964a544248e15f86efa84cb0) — 2026-08-30
### `feat(tfp): implement Phase 6 Steps 2 and 3 TFP isolation and observational telemetry`
* Implemented discrete event and continuous polling telemetry for TFP camera transitions.
* Added lifecycle event logging for workspots, vehicles, and weapon actions.

---

## [`4203e29`](https://github.com/mordeak/immersive-footwear-pov/commit/4203e29598a35902976d66383b7bfa8086dc6316) — 2026-08-30
### `feat(tfp): implement Phase 6 Step 1 graceful framework detection and diagnostics`
* Created `Integrations/ImmersiveFootwearPOV_Framework.reds` providing compile-time `@if(ModuleExists("..."))` detection for `TrueFirstPerson` and `EquipmentEx`.
* Added framework presence indicators in CET diagnostics.

---

## [`b3dab5e`](https://github.com/mordeak/immersive-footwear-pov/commit/b3dab5e8df6bd6db8d131cfe90394e740dc7f4e5) — 2026-08-30
### `feat(pm,equipment-ex): direct outfit memory query for instant photo mode platform elevation`
* Added `EquipmentExHelper.GetFootwearFromOutfit` allowing instant querying of footwear items from active Equipment-EX outfits in memory during Photo Mode pose changes.

---

## [`6be0306`](https://github.com/mordeak/immersive-footwear-pov/commit/6be0306464af95adc9bb7cbaee7e76cc342f54dd) — 2026-08-30
### `refactor(pm,init): streamline Photo Mode integration and clean up global console aliases`
* Refactored Photo Mode elevation logic in `integrations/pm.lua`.
* Cleaned up global CET console commands and standardized diagnostics output.

---

## [`a6d56a3`](https://github.com/mordeak/immersive-footwear-pov/commit/a6d56a3e7e67aeb193fb2659ec09baf999631007) — 2026-08-30
### `feat(pm): add dynamic photo mode outfit switching platform sole elevation and expose ShoeHeightParser proxy`
* Added dynamic Photo Mode outfit switching support with automatic character elevation based on newly equipped footwear platform soles.
* Exposed `ShoeHeightParser` methods directly on `ImmersiveFootwearPOVSystem` for CET Lua consumption.

---

## [`f74ff53`](https://github.com/mordeak/immersive-footwear-pov/commit/f74ff53) — 2026-08-29
### `refactor(logging): remove dead REDscript LogChannel/FTLog routines in favor of CET Lua telemetry`
* **REDscript Logging Cleanup:** Completely removed inert `LogChannel` / `FTLog` calls and unused debug printer methods from `ImmersiveFootwearPOV_System.reds` and `Integrations/ImmersiveFootwearPOV_IFP.reds`.
* **Zero Overhead:** Streamlined REDscript execution to pure game logic and animgraph state blending without redundant debug branching.
* **Diagnostics Retention:** All real-time telemetry (stance blend easing, suppression events, Photo Mode transitions, shoe diagnostics) remains accessible via CET console commands (`IFPStatus()`, `DumpState()`, `IFPDebug(true)`).

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
