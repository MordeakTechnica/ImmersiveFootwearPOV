# Immersive Footwear POV — Project Plan

**Mod Name:** Immersive Footwear POV  
**Target Game:** Cyberpunk 2077  
**Frameworks:** REDscript, TweakXL (Optional: ArchiveXL), Cyber Engine Tweaks (CET)  
**Scope:** First-Person Perspective (FPP) Camera Adjustment & Height Stance based on Shoe TweakDB Metadata

---

## 1. Project Overview

This mod dynamically adjusts V's First-Person Perspective (FPP) camera eye height based on the currently equipped footwear. By reading custom TweakDB tags from the equipped footwear's item record, the mod calculates a vertical Z-offset and applies it directly to V's physical skeleton via the REDengine animation graph (`ifp_height_blend`).

### Dual-Height Specification:
1. **Heel Height (`HeelHeight_<VAL>`):** **Primary FPP Height Offset**. Determines the vertical elevation applied to V's character model, root stance, and eye-line in real-time first-person gameplay.
2. **Platform Height (`PlatformHeight_<VAL>`):** **Secondary Sole Offset**. Captures the front sole / platform thickness under the ball of the foot. Stored in memory and reserved for Photo Mode (PM) pose height shifting.

To maintain immersion and prevent visual clipping or misalignment:
- The height offset is **active** while standing, walking, running, or crouching.
- The height offset is **reset to default (0.0)** when entering vehicles, sitting in chairs/couches (Workspots), or triggering scripted cinematic sequences.

---

## 2. Technical Architecture & Data Flow

```
+-------------------------------------------------------------------+
|                     Footwear Equipped / Unequipped                |
+-------------------------------------------------------------------+
                                  |
                                  v
+-------------------------------------------------------------------+
|         Read TweakDB Metadata (Heel & Platform Tags)              |
|   e.g., "HeelHeight_008" -> 0.08m Heel (Active FPP Height)        |
|         "PlatformHeight_003" -> 0.03m Platform (Stored for PM)    |
+-------------------------------------------------------------------+
                                  |
                                  v
+-------------------------------------------------------------------+
|                    Evaluate Active Player State                   |
+-------------------------------------------------------------------+
           |                                             |
           | Standing / Roaming / Combat                 | Seated / In Vehicle
           v                                             v
+------------------------------------+       +------------------------------------+
| Drive Skeleton Animgraph           |       | Reset Height Blend to Base (0.0m)  |
| ifp_height_blend (+Heel Offset)    |       | (Blend = 0.50)                     |
+------------------------------------+       +------------------------------------+
```

---

## 3. TweakDB Specification (TweakXL)

Modders configure shoe heights by adding standardized tags in their item's TweakXL YAML record:

### 1. Primary Heel Tag: `HeelHeight_<VAL>` (Moves V Up/Down in FPP)
* **Tag Formats:** `HeelHeight_<VAL>`, `Heel_<VAL>`, `ShoeHeel_<VAL>`
* **Value Formats Supported:**
  * Centimeters: `HeelHeight_006` (6 cm), `HeelHeight_008` (8 cm), `HeelHeight_010` (10 cm), `Heel_6` (6 cm), `Heel_10` (10 cm)
  * Millimeters: `HeelHeight_60` (60 mm = 0.06m), `Heel_80` (80 mm = 0.08m)
  * Decimal Meters: `HeelHeight_0.06` (0.06m), `Heel_0.08` (0.08m)

### 2. Secondary Platform Tag: `PlatformHeight_<VAL>` (Reserved for Photo Mode Shifting)
* **Tag Formats:** `PlatformHeight_<VAL>`, `Platform_<VAL>`, `ShoePlatform_<VAL>`
* **Value Formats Supported:**
  * Centimeters: `PlatformHeight_003` (3 cm), `Platform_004` (4 cm), `Platform_3` (3 cm)
  * Millimeters: `PlatformHeight_30` (30 mm = 0.03m), `Platform_40` (40 mm = 0.04m)
  * Decimal Meters: `PlatformHeight_0.03` (0.03m), `Platform_0.04` (0.04m)

### Examples for Modders:

```yaml
# Example 1: Classic High Heels (8cm heel, 0cm platform sole)
# -> V elevates +8cm in FPP; PM platform offset is 0.0m
Items.Custom_Classic_Stilettos_01:
  $base: Items.GenericFootClothing
  tags: !append-once 
    - "HeelHeight_008"

# Example 2: Platform High Boots (10cm heel with a 4cm front platform)
# -> V elevates +10cm in FPP; PM platform offset is 0.04m
Items.Custom_Platform_Boots_01:
  $base: Items.GenericFootClothing
  tags: !append-once 
    - "HeelHeight_010"
    - "PlatformHeight_004"

# Example 3: Chunky Flat Platform Sneakers (6cm continuous platform sole)
# -> V elevates +6cm in FPP; PM platform offset is 0.06m
Items.Custom_Chunky_Platforms_01:
  $base: Items.GenericFootClothing
  tags: !append-once 
    - "HeelHeight_006"
    - "PlatformHeight_006"
```

---

## 4. REDscript & CET Implementation Design

### Core Components

1. **`ShoeHeightParser` & `ShoeHeightData` ([`ImmersiveFootwearPOV_TweakReader.reds`](file:///c:/Users/cogli/Documents/CyberPunk%20-%20Projects/Immersive%20Footwear%20POV/source/resources/r6/scripts/ImmersiveFootwearPOV/ImmersiveFootwearPOV_TweakReader.reds))**
   - Parses both `HeelHeight` and `PlatformHeight` from item tags.
   - Supplies `heelHeight` for active FPP skeletal elevation and `platformHeight` for future Photo Mode shifting.

2. **`ImmersiveFootwearPOVSystem` ([`ImmersiveFootwearPOV_System.reds`](file:///c:/Users/cogli/Documents/CyberPunk%20-%20Projects/Immersive%20Footwear%20POV/source/resources/r6/scripts/ImmersiveFootwearPOV/ImmersiveFootwearPOV_System.reds))**
   - Tracks current `m_currentHeelHeight` and `m_currentPlatformHeight`.
   - Listens for equipment and wardrobe changes.
   - Evaluates context suppression (`isInVehicle`, `isInWorkspot`).
   - Computes effective elevation offset:  
     `EffectiveOffset = (isInVehicle || isInWorkspot) ? 0.0 : m_currentHeelHeight`

3. **Equipment & Outfit Resolver ([`FootwearResolver.reds`](file:///c:/Users/cogli/Documents/CyberPunk%20-%20Projects/Immersive%20Footwear%20POV/source/resources/r6/scripts/ImmersiveFootwearPOV/ImmersiveFootwearPOV_FootwearResolver.reds))**
   - Resolves active footwear with strict priority: Equipment-EX -> Vanilla Wardrobe / Transmog -> Gameplay Equipment Slot.

4. **Physical Animation Graph Height Controller ([`HeightController.reds`](file:///c:/Users/cogli/Documents/CyberPunk%20-%20Projects/Immersive%20Footwear%20POV/source/resources/r6/scripts/ImmersiveFootwearPOV/ImmersiveFootwearPOV_HeightController.reds))**
   - Directly drives the player skeleton two-branch blend (`ifp_height_blend`) on `AnimationControllerComponent`.
   - Zero modification of `FPPCameraComponent` (camera naturally follows V's elevated head).

5. **Continuous Dynamic Frame Bridge ([`init.lua`](file:///c:/Users/cogli/Documents/CyberPunk%20-%20Projects/Immersive%20Footwear%20POV/source/resources/bin/x64/plugins/cyber_engine_tweaks/mods/ImmersiveFootwearPOV/init.lua))**
   - CET background worker continuously publishes the dynamic footwear height blend to the animation graph.
   - Implements direct Dear ImGui window appending to IFP's existing CET window.

---

## 5. Development Roadmap

### Phase 1: TweakDB Tag Parser & Footwear Resolution
- [x] Set up project structure (`r6/scripts/ImmersiveFootwearPOV/` & `plugins/cyber_engine_tweaks/`).
- [x] Create `ImmersiveFootwearPOVSystem` to manage global mod state, debug logging, and lifecycle hooks.
- [x] Implement `FootwearResolver` with Equipment-EX priority hierarchy.
- [x] Implement string/tag parsing logic (`ShoeHeightParser`) with dual-height support (`HeelHeight` primary + `PlatformHeight` secondary).

### Phase 2: Physical Skeleton & Animgraph Integration
- [x] Map REDengine two-branch blend input (`ifp_height_blend`) on `AnimationControllerComponent`.
- [x] Implement mathematical linear blend formula mapping $[-0.50\text{m}, +0.50\text{m}]$ to $[0.0, 1.0]$.
- [x] Remove all synthetic camera modifications to ensure 100% natural, pitch-distortion-free FPP body views.
- [x] Implement continuous frame-fed publishing in CET `init.lua`.

### Phase 3: Outfit Swapping & Save Game Persistence
- [x] Hook `EquipmentSystemPlayerData` and `OutfitSystem` for instant outfit swapping.
- [x] Auto-poll in `onUpdate` to catch all wardrobe/hotkey outfit changes.
- [x] Implement `OnRestored` and `OnPlayerAttach` for seamless save-game loading and fast travel.
- [x] Add manual toggle keybind for side-by-side comparison.

### Phase 4: Context & State Suppression (Vehicles, Workspots, Quest Scenes)
- [x] **Vehicles (Mount / Drive / Unmount):**
  - Detect vehicle mount state (`VehicleComponent`, `GetMountedVehicle`, mounting requests) and smoothly drop height blend to baseline ($0.0\text{m}$) over $0.20\text{s}$ to prevent head clipping through vehicle roofs.
  - Automatically and smoothly restore footwear elevation upon unmounting.
- [x] **Workspots & Furniture (Sitting, Lounging, Beds):**
  - Hooked `OnWorkspotStartedEvent` / `OnWorkspotFinishedEvent` and `WorkspotSystem` to zero out elevation when seated on chairs, barstools, sofas, benches, and beds so sitting hip alignment matches furniture collision.
  - Re-apply footwear height smoothly upon standing up.
- [x] **Scripted Quest Scenes & Dialogue Tiers:**
  - Detect high Scene Tiers (Tier 3/4 cutscenes, interactive dialogues, scripted story animations) and temporarily suppress platform offsets to ensure cinematic head-tracking and mocap alignment remain 100% faithful.
- [x] **Traversal & Physical Interaction States:**
  - Suppress elevation during special traversal/action states:
    * Climbing ladders (Locomotion 10..13)
    * Vaulting / mantling high ledges (Locomotion 8..9)
    * Swimming (`HighLevel == 6` / `Swimming > 0`)
    * Carrying / dumping bodies (`BodyCarrying > 0`)
    * Executing stealth takedowns and finishers (`Takedown > 0`)
- [x] **Photo Mode Integration (Native Attribute 37 Platform Elevation):**
  - Smoothly eases 1st-person locomotion blend to neutral ($0.0\,\text{m}$) when opening Photo Mode to prevent pose distortion.
  - Automatically elevates V's 3rd-person puppet via REDengine native Attribute 37 (`V Up/Down`) by equipped platform sole thickness ($+Z$ meters).
  - Added interactive `Auto-Elevate Platform Sole in Photo Mode` toggle in CET overlay (saved in `user_shoe_overrides.json`).
  - Smoothly restores 1st-person stance height upon exiting Photo Mode over $0.20\,\text{s}$.

### Phase 5: IFP Coexistence, UI Height Readout & Custom Overrides
- [x] **Direct IFP CET Window Appending (ImGui Extension):**
  - Hooked `onDraw` in `init.lua` using `ImGui.Begin("Immersive First Person")` to render live telemetry into IFP's window.
- [x] **Per-Shoe Custom Height Overrides & Persistence:**
  - Added JSON persistence (`user_shoe_overrides.json`) for untagged shoes.
  - Interactive sliders for Custom Heel Height ($0.0\text{--}25.0\,\text{cm}$) and Custom Platform ($0.0\text{--}25.0\,\text{cm}$).
  - Live shoe switching: updates immediately as V changes footwear across Equipment-EX, Wardrobe, and Inventory.
- [x] **Official TweakDB Precedence & Auto-Discard:**
  - Official TweakDB tags automatically lock controls to official metadata.
  - Any obsolete custom overrides for an item are automatically purged when official tags are detected.
- [x] **Additive IFP Base Slider Stacking:**
  - Real-time polling of IFP's native base height slider (`Config.inner.heightAdjustmentAmount`).
  - Stacks additively: $\text{Total Height} = \text{IFP Base Height} + \text{Footwear Heel Height}$.
  - Both IFP's slider and footwear elevation work concurrently without overriding each other.
- [x] **Modular Architecture Refactoring:**
  - Reorganized integrations into dedicated modular files (`Integrations/ImmersiveFootwearPOV_IFP.reds`, `integrations/ifp.lua`, `integrations/pm.lua`).
- [x] **Transition Telemetry & Diagnostics Console API:**
  - Added optional debug logging covering FPP stance easing and Photo Mode (PM) lifecycle, frame progression, and Attribute 37 (`upDown`) force status.
  - Added multi-channel controls: CET console methods (`ToggleDebug`, `SetDebug`, `DumpState`), global shortcuts (`ToggleIFPDebug()`, `IFPDebug(bool)`, `IFPStatus()`), and Dear ImGui UI checkbox (persisted in `user_shoe_overrides.json`).

### Phase 6: True First Person (TFP) Integration & Multi-Framework Support
> [!NOTE]
> **Design Principle for TFP Users:** Players choose True First Person specifically to avoid Lua/CET scripting overhead. When integrating with TFP, the mod operates in a **100% native REDscript architecture**—we do not inject CET UI controls or force Lua windows when TFP is active. All configuration is handled directly in TFP's native in-game menu.

- [x] **Step 6.1: Graceful Framework Detection & Fallback Baseline**
  - Verified and tested mod behavior across all installation matrix states (neither, either, or both IFP/TFP/Equipment-EX installed).
  - Implemented modular `FrameworkDetector` and `EquipmentExDetector` REDscript helpers with `@if(ModuleExists)` / `@if(!ModuleExists)` conditional compilation.
  - Implemented `IFP.IsInstalled()` guard in CET to prevent phantom overlay windows in standalone / TFP-only modes.
  - Enhanced `DumpState()` and `onInit` diagnostics reporting real-time status of all active 1st-person and outfit frameworks.
- [x] **Step 6.2: Isolated TFP REDscript Integration Module**
  - Created `source/resources/r6/scripts/ImmersiveFootwearPOV/Integrations/ImmersiveFootwearPOV_TFP.reds`.
  - Guarded with `@if(ModuleExists("TrueFirstPerson"))` and provided `@if(!ModuleExists("TrueFirstPerson"))` clean fallback stubs so it compiles seamlessly in all configurations.
- [x] **Step 6.3: Observational Telemetry & State Polling**
  - Hooked TFP camera update lifecycle events (`InitPosition`, `ResetForWeapon`, `ResetCameraVehicle`, `HandleCamera`) purely for non-invasive observational telemetry.
  - Implemented transition-gated logging to monitor active footwear name, effective shoe lift (+cm), TFP base Z, active camera Z, and suppression state.
- [x] **Step 6.4: Additive Camera Z Offset Injection (`TFPHelper.ApplyFootwearHeight`)**
  - Implemented additive camera elevation in `ImmersiveFootwearPOV_TFP.reds` synchronizing `config.cameraZ = baseZ + effectiveOffset` across `IFPCamera.InitPosition` and `IFPWeapon.RefreshCurrentWeapon`.
  - Context-aware suppression (sitting, ladders, swimming, crouching, vehicle entry) automatically zeroes out the offset ($0.0\,\text{m}$) via `ImmersiveFootwearPOVSystem.RecalculateEffectiveOffset()`.
  - Verified 100% native REDscript compilation with 0 errors via `compile_redscripts.py`.
- [x] **Step 6.5: Weapon Offset & ADS Alignment Verification (Option A Implementation)**
  - Implemented dynamic weapon height synchronization (`TFPHelper.SyncWeaponForCurrentFootwear`).
  - Additively applies footwear lift (`+effectiveOffset`) to TFP's weapon tuning Z (`tune.z`), ensuring that physical viewmodels and ADS iron-sights rise naturally with footwear lift while maintaining perfect center-screen optic alignment.
  - Hooked weapon actions and equip cycles (`NotifyWeaponAction`, `ApplyFootwearHeight`) to keep all weapons synchronized on footwear and suppression changes.
- [ ] **Step 6.6: Vehicle Entry Suppression & Exit Restoration**
  - Test vehicle transitions: verify that entering cars drops elevation to `0.0 m` (preventing roof clipping) and stepping out immediately restores footwear height via `IFPCamera`.
- [ ] **Step 6.7: Silent CET Behavior under TFP**
  - Ensure CET mod detects when TFP is active and remains completely passive/dormant, avoiding redundant Lua windows or conflicting overlays.
- [x] **Step 6.8: Universal CET Configuration Window (Standalone & Multi-Framework)**
  - Enhanced [`integrations/ifp.lua`](file:///c:/Users/cogli/Documents/CyberPunk%20-%20Projects/Immersive%20Footwear%20POV/source/resources/bin/x64/plugins/cyber_engine_tweaks/mods/ImmersiveFootwearPOV/integrations/ifp.lua) with mutually exclusive hybrid window rendering:
    - When IFP is enabled (and TFP is not active): seamlessly and exclusively attaches to IFP's native in-game window (`"Immersive First Person"`). No separate Footwear window is opened.
    - When either no 3rd-party POV mod or TFP is installed (or IFP is disabled): adds a dedicated `"Immersive Footwear POV"` CET overlay window.
  - Exposes interactive Heel Height & Platform Height sliders, Photo Mode auto-elevation toggles, real-time stance diagnostics, and custom height reset buttons across all installation matrix states without depending on external Redscript config providers.

### Phase 7: Immersive Third Person (ITP) Dynamic Elevation Integration
- [x] **Step 7.1: Dedicated REDscript Integration Module (`ImmersiveFootwearPOV_ITP.reds`)**
  - Created [`ImmersiveFootwearPOV_ITP.reds`](file:///c:/Users/cogli/Documents/CyberPunk%20-%20Projects/Immersive%20Footwear%20POV/source/resources/r6/scripts/ImmersiveFootwearPOV/Integrations/ImmersiveFootwearPOV_ITP.reds) implementing `ITPController`.
  - Interfaces natively with REDengine's `AnimationControllerComponent.SetInputFloat(player, n"foot_elevation_offset", clampedOffset)` to dynamically elevate V's third-person character model.
  - Implemented runtime detection (`ITPController.IsITPPresent`) targeting `TPPCameraVisibleRenderBridge`.
- [x] **Step 7.2: Framework Detection & Diagnostics Integration**
  - Added `ITPDetector` helper in [`ImmersiveFootwearPOV_Framework.reds`](file:///c:/Users/cogli/Documents/CyberPunk%20-%20Projects/Immersive%20Footwear%20POV/source/resources/r6/scripts/ImmersiveFootwearPOV/Integrations/ImmersiveFootwearPOV_Framework.reds).
  - Added `IsITPPresent()` system query on `ImmersiveFootwearPOVSystem`.
- [x] **Step 7.3: Core Recalculation & Dynamic Height Feeding**
  - Updated `ImmersiveFootwearPOVSystem.RecalculateEffectiveOffset(player)` to dynamically dispatch `ITPController.ApplyHeightOffset(player, this.m_effectiveOffset)` on all shoe changes, wardrobe swaps, and suppression updates.
  - Automatically suppresses 3rd-person elevation during vehicles, workspots (chairs/couches/beds), swimming, ladders, and story cutscenes.
- [x] **Step 7.4: CET Continuous Frame Driver & Telemetry Readouts**
  - In [`init.lua`](file:///c:/Users/cogli/Documents/CyberPunk%20-%20Projects/Immersive%20Footwear%20POV/source/resources/bin/x64/plugins/cyber_engine_tweaks/mods/ImmersiveFootwearPOV/init.lua), continuously feeds `foot_elevation_offset` across both FPP and TPP perspectives to guarantee persistence against animation graph resets.
  - Enhanced CET overlay window ([`integrations/ifp.lua`](file:///c:/Users/cogli/Documents/CyberPunk%20-%20Projects/Immersive%20Footwear%20POV/source/resources/bin/x64/plugins/cyber_engine_tweaks/mods/ImmersiveFootwearPOV/integrations/ifp.lua)) with live ITP engine detection and 3rd-person stance lift telemetry.
- [x] **Step 7.5: Native REDscript Compilation Verification**
  - Compiled and verified against live game cache via `scc.exe` with 0 errors and 0 warnings.

---

## 6. Dependencies & Publishing Requirements

### 6.1 Required Core Dependencies (Nexus Requirements)
These framework mods must be installed for **Immersive Footwear POV** to function in-game:

| Mod / Framework | Minimum Version | Nexus Mod Link / ID | Purpose in This Mod |
| :--- | :--- | :--- | :--- |
| **Cyber Engine Tweaks (CET)** | `v1.30+` | [CET (Nexus: 107)](https://www.nexusmods.com/cyberpunk2077/mods/107) | Drives the per-frame animgraph blend publisher, hotkey, and IFP window extension. |
| **REDscript** | `v0.5.25+` | [REDscript (Nexus: 1511)](https://www.nexusmods.com/cyberpunk2077/mods/1511) | Compiles the mod's core state system, TweakDB reader, and outfit hooks. |
| **RED4ext** | `v1.20+` | [RED4ext (Nexus: 2380)](https://www.nexusmods.com/cyberpunk2077/mods/2380) | Prerequisite framework for REDscript and script compilation. |
| **Immersive First Person (IFP)** | `v2.0+` | [IFP (Nexus: 2675)](https://www.nexusmods.com/cyberpunk2077/mods/2675) | Provides the modified `player_base.animgraph` with the `ifp_height_blend` skeletal height node. |

---

### 6.2 Footwear Creator & Modder Dependencies
Footwear authors creating or updating shoes for this mod require:

| Tool / Framework | Purpose |
| :--- | :--- |
| **TweakXL** | Loads shoe TweakDB `.yaml` configs containing `HeelHeight_XXX` and `PlatformHeight_XXX` tags. |
| **ArchiveXL** *(Optional)* | Used by custom shoe mods to load custom meshes, textures, and foot rigs. |

---

### 6.3 Optional Integrations & Supported Frameworks
The mod natively detects and supports these mods automatically when present:

| Mod / Integration | Compatibility / Function |
| :--- | :--- |
| **Equipment-EX** | Priority 1 outfit resolution. Footwear in custom Equipment-EX slots is automatically detected and prioritized over vanilla transmog/equipment. |
| **Native Settings UI** | Displays real-time footwear and total stance height readouts directly inside the in-game *Mod Settings* menu. |

---

### 6.4 Compatibility Notes
* **Zero Camera Pitch Distortion:** Because height is injected into the skeletal animation graph rather than `FPPCameraComponent`, downward viewing angles and pitch mechanics remain 100% natural.
* **Additive IFP Stacking:** Coexists seamlessly with IFP's base height slider ($\text{Total Height} = \text{Base} + \text{Heel}$).
* **Dynamic Wardrobe Swapping:** Automatically detects instant outfit swaps across vanilla wardrobe hotkeys, inventory swaps, and Equipment-EX presets.
