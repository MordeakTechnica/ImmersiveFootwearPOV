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

## 2. Directory Structure & Workspace Layout

The repository is organized into distinct functional layers, with **[`source/`](file:///c:/Users/cogli/Documents/CyberPunk%20-%20Projects/Immersive%20Footwear%20POV/source)** designated as the **main mod folder** containing all active game assets, scripts, CET modules, and archive inputs.

```
Immersive Footwear POV/
├── source/                        # [MAIN FOLDER] Core game assets, scripts, and runtime resources
│   ├── archive/                   # Staged CR2W assets ready for packaging
│   │   └── base/gameplay/anim_graphs/player_base.animgraph
│   ├── raw/                       # Raw WolvenKit source files (JSON format)
│   │   └── base/gameplay/anim_graphs/player_base.animgraph.json
│   └── resources/                 # Ready-to-deploy game resources (mirrors game installation layout)
│       ├── archive/pc/mod/        # Packed archive package (##_ITP_Immersive_Footwear_POV.archive)
│       ├── bin/x64/plugins/cyber_engine_tweaks/mods/ImmersiveFootwearPOV/  # CET mod files
│       │   ├── init.lua           # CET core lifecycle & overlay orchestrator
│       │   ├── shoe_presets.example.json  # Reference shoe calibration configuration
│       │   ├── integrations/      # 3rd-party bridge modules (ifp.lua, pm.lua)
│       │   └── modules/           # Modular CET subsystems (config, ui, state, stride, etc.)
│       └── r6/                    # Engine scripts and metadata definitions
│           ├── scripts/ImmersiveFootwearPOV/  # Authoritative REDscript codebase
│           │   ├── ImmersiveFootwearPOV_FootwearResolver.reds
│           │   ├── ImmersiveFootwearPOV_Hooks.reds
│           │   ├── ImmersiveFootwearPOV_TweakReader.reds
│           │   ├── Integrations/  # Mod integrations (ITP, IFP, TFP, Equipment-EX, PM)
│           │   └── Systems/       # Authoritative ScriptableSystems (System, Stride, Suppression)
│           └── tweaks/ImmersiveFootwearPOV/   # TweakXL YAML metadata examples
│
├── tools/                         # Automated build, deployment, animgraph, and packaging tooling
│   ├── pack_and_deploy.ps1        # Master packaging, deployment, and validation pipeline
│   ├── create_release_zips.ps1    # Automated release archive packager
│   ├── animgraph_toolkit/         # Python framework for animgraph inspection and transformation
│   ├── preset_variant_expander/   # Python utility for generating shoe variant presets
│   ├── diagnostics_archive/       # Reverse-engineering inspection & validation test suite
│   ├── inject_itp_elevation.py    # Injects 3rd-person vertical puppet elevation into animgraph
│   ├── inject_sway_nodes.py       # Injects catwalk pelvic oscillation nodes into animgraph
│   ├── inject_arm_hip_nodes.py    # Injects thoracic counter-rotation & shoulder stabilization
│   ├── inject_leg_counter_rotation.py  # Injects femoral & thigh counter-rotation nodes
│   └── apply_hand_on_hip_recipe.py     # Applies feline hand-on-hip pose offsets
│
├── packed/                        # Distribution archives generated during build
├── docs/                          # Architecture diagrams, specifications, and reference notes
├── CHANGES.md                     # Comprehensive chronological changelog
├── PROJECT.md                     # Technical architecture & project roadmap
└── USER_GUIDE.md                  # Player installation, configuration, and troubleshooting guide
```

### 2.1 The `source/` Directory (Main Folder)
The [`source/`](file:///c:/Users/cogli/Documents/CyberPunk%20-%20Projects/Immersive%20Footwear%20POV/source) directory is the primary workspace root containing all source code and assets required to build and run the mod:
* **[`source/raw/`](file:///c:/Users/cogli/Documents/CyberPunk%20-%20Projects/Immersive%20Footwear%20POV/source/raw):** Contains uncompressed, human-readable WolvenKit JSON files, primarily `player_base.animgraph.json`. All procedural node injections and animgraph modifications operate on this file before compilation.
* **[`source/archive/`](file:///c:/Users/cogli/Documents/CyberPunk%20-%20Projects/Immersive%20Footwear%20POV/source/archive):** Contains the staged binary CR2W file `player_base.animgraph` generated via WolvenKit CLI `wkit convert d`.
* **[`source/resources/`](file:///c:/Users/cogli/Documents/CyberPunk%20-%20Projects/Immersive%20Footwear%20POV/source/resources):** Mirrors the game's root directory structure for seamless one-to-one staging and deployment:
  * **`archive/pc/mod/`:** Houses [`##_ITP_Immersive_Footwear_POV.archive`](file:///c:/Users/cogli/Documents/CyberPunk%20-%20Projects/Immersive%20Footwear%20POV/source/resources/archive/pc/mod/##_ITP_Immersive_Footwear_POV.archive). The `##_` prefix guarantees early ASCII load order over third-person camera mods.
  * **`r6/scripts/ImmersiveFootwearPOV/`:** The authoritative REDscript codebase, organized into core resolvers, lifecycle hooks, systems, and integrations.
  * **`r6/tweaks/ImmersiveFootwearPOV/`:** YAML definitions for TweakXL tag schemas and modder reference examples.
  * **`bin/x64/plugins/cyber_engine_tweaks/mods/ImmersiveFootwearPOV/`:** The presentation, configuration, and ImGui overlay layer implemented in Cyber Engine Tweaks (Lua).

### 2.2 The `tools/` Directory (Tooling & Available Tools)
The [`tools/`](file:///c:/Users/cogli/Documents/CyberPunk%20-%20Projects/Immersive%20Footwear%20POV/tools) directory provides a dedicated automation and engineering suite for building, testing, injecting animation graphs, and packaging releases:

#### 1. Deployment & Release Automation
* **[`pack_and_deploy.ps1`](file:///c:/Users/cogli/Documents/CyberPunk%20-%20Projects/Immersive%20Footwear%20POV/tools/pack_and_deploy.ps1):** The master build and deployment pipeline script. Converts raw animgraph JSON to CR2W via WolvenKit CLI, packs the `.archive`, copies files into `source/resources/`, synchronizes all game files (archive, REDscripts, CET modules, Tweaks) to the local game directory (`D:\SteamLibrary\steamapps\common\Cyberpunk 2077`), and validates compilation via `scc.exe`.
* **[`create_release_zips.ps1`](file:///c:/Users/cogli/Documents/CyberPunk%20-%20Projects/Immersive%20Footwear%20POV/tools/create_release_zips.ps1):** Automates the packaging of clean, distributable ZIP archives for GitHub releases and Nexus Mods, ensuring unnecessary build artifacts are excluded.

#### 2. Animation Graph Engineering Tooling
* **[`animgraph_toolkit/`](file:///c:/Users/cogli/Documents/CyberPunk%20-%20Projects/Immersive%20Footwear%20POV/tools/animgraph_toolkit):** High-level modular Python framework for programmatically parsing, modifying, and transforming Cyberpunk 2077 animation graphs. Includes graph models, node factories, connection builders, CLI inspection tools, and automated regression tests.
* **[`inject_itp_elevation.py`](file:///c:/Users/cogli/Documents/CyberPunk%20-%20Projects/Immersive%20Footwear%20POV/tools/inject_itp_elevation.py):** Injects the dynamic `foot_elevation_offset` float input variable and skeletal elevation blend logic into `player_base.animgraph` for 3rd-person character elevation.
* **[`inject_sway_nodes.py`](file:///c:/Users/cogli/Documents/CyberPunk%20-%20Projects/Immersive%20Footwear%20POV/tools/inject_sway_nodes.py):** Injects pelvic roll and yaw oscillation blend nodes into the player locomotion animgraph.
* **[`inject_arm_hip_nodes.py`](file:///c:/Users/cogli/Documents/CyberPunk%20-%20Projects/Immersive%20Footwear%20POV/tools/inject_arm_hip_nodes.py):** Injects thoracic spine counter-rotation and shoulder stabilization nodes (`Spine2`).
* **[`inject_leg_counter_rotation.py`](file:///c:/Users/cogli/Documents/CyberPunk%20-%20Projects/Immersive%20Footwear%20POV/tools/inject_leg_counter_rotation.py):** Injects femoral and thigh counter-rotation nodes (`LeftUpLeg` / `RightUpLeg`) to keep legs tracking straight during catwalk hip sway.
* **[`apply_hand_on_hip_recipe.py`](file:///c:/Users/cogli/Documents/CyberPunk%20-%20Projects/Immersive%20Footwear%20POV/tools/apply_hand_on_hip_recipe.py):** Applies hand-on-hip pose offsets during feline stance idle cycles.

#### 3. Preset & Data Expansion Tools
* **[`preset_variant_expander/`](file:///c:/Users/cogli/Documents/CyberPunk%20-%20Projects/Immersive%20Footwear%20POV/tools/preset_variant_expander):** Python CLI utility that parses footwear records and automatically expands variant keys across colorways, suffixes, and naming schemes for multi-preset authoring.

#### 4. Reverse-Engineering & Diagnostics
* **[`diagnostics_archive/`](file:///c:/Users/cogli/Documents/CyberPunk%20-%20Projects/Immersive%20Footwear%20POV/tools/diagnostics_archive):** Comprehensive collection of 39 specialized Python inspection scripts used during reverse engineering to trace inverse kinematics (IK) chains, bone hierarchies, float links, and locomotion blend trees in vanilla `player_base.animgraph`.

---

## 3. Technical Architecture & Data Flow

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

## 4. TweakDB Specification (TweakXL)

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

## 5. REDscript & CET Implementation Design

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

## 6. Development Roadmap

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
  - Interactive sliders for Custom Heel Height ($0.0\text{--}40.0\,\text{cm}$) and Custom Platform ($0.0\text{--}30.0\,\text{cm}$).
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
  - Enhanced [`modules/ui.lua`](file:///c:/Users/cogli/Documents/CyberPunk%20-%20Projects/Immersive%20Footwear%20POV/source/resources/bin/x64/plugins/cyber_engine_tweaks/mods/ImmersiveFootwearPOV/modules/ui.lua) with a dedicated standalone configuration window:
    - Always renders the standalone `"Immersive Footwear POV"` CET overlay window, eliminating confusion when IFP and ITP run together.
    - Clearly displays active POV engines: standalone, Photo Mode, IFP (1st Person), ITP (3rd Person), or IFP + ITP hybrid.
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
- [x] **Step 7.6: Perspective-Aware Dual Height Dispatch (FPP Heel Lift & TPP Platform Lift)**
- [x] **Step 7.7: Manual Height Input with Auto-Clamping & Non-Negative Validation**
  - Added dedicated manual numerical entry fields (`ImGui.InputFloat`) alongside sliders in CET overlay UI (`DrawCustomFootwearControls` in `integrations/ifp.lua`).
  - Implemented automatic boundary clamping:
    - Custom Heel Height automatically clamps to `40.0 cm` max (`FootwearHeightLimits.MAX_HEEL_CM`).
    - Custom Platform Height automatically clamps to `30.0 cm` max (`FootwearHeightLimits.MAX_PLATFORM_CM`).
    - Negative values are strictly disallowed and automatically set to `0.0 cm` minimum.
  - Added CET console shortcuts `SetFootwearHeight(heelCm, platformCm)` and `SetCustomHeight(heelCm, platformCm)` in `init.lua` with identical auto-clamping and non-negative enforcement.

### Phase 8: Lua-to-REDscript Core Refactor (Architecture & Performance)
- [x] **Event-Driven Custom Overrides in REDscript:**
  - Added `m_customOverrideKeys`, `m_customOverrideHeels`, and `m_customOverridePlatforms` native mapping to `ImmersiveFootwearPOVSystem`.
  - `UpdateEquippedFootwear` directly resolves untagged shoes against registered custom overrides immediately upon equip, eliminating equip-to-elevation latency.
  - Presets and user overrides are synced to REDscript on mod startup and UI calibration changes.
- [x] **Elimination of Legacy 0.40s Polling Loop:**
  - Completely removed the 0.40s polling timer from `init.lua`, saving 10–14 FFI calls every poll.
  - State synchronization in CET is now event-driven, checking only if the equipped shoe key changed.
- [x] **Native Photo Mode ink UI Integration ([`ImmersiveFootwearPOV_PM.reds`](file:///c:/Users/cogli/Documents/CyberPunk%20-%20Projects/Immersive%20Footwear%20POV/source/resources/r6/scripts/ImmersiveFootwearPOV/Integrations/ImmersiveFootwearPOV_PM.reds)):**
  - Hooked `gameuiPhotoModeMenuController.OnShow`, `OnHide`, and `OnEquipWardrobeSet` directly in REDscript.
  - Native execution handles Photo Mode Attribute 37 (V Up/Down) platform elevation directly without CET frame delay queues.
- [x] **Native Stride Kinematics Execution ([`ImmersiveFootwearPOV_Stride.reds`](file:///c:/Users/cogli/Documents/CyberPunk%20-%20Projects/Immersive%20Footwear%20POV/source/resources/r6/scripts/ImmersiveFootwearPOV/Systems/ImmersiveFootwearPOV_Stride.reds)):**
  - Moved catwalk roll, yaw, spine counter-yaw, spine counter-roll, and leg counter-roll math to native REDscript `StrideController`.
  - Reduced per-frame locomotion updates from 6–7 separate Lua-to-C++ FFI calls to a single native tick call (`sys:UpdateStride`).
- [x] **Authoritative Perspective Delegation:**
  - CET's `Perspective.IsTPPActive` and `Perspective.IsITPInstalled` directly query REDscript singletons with zero unnecessary component scans.
- [x] **Workspot Elevation Restoration & Suppression Self-Healing:**
  - Exiting workspots (chairs, beds, furniture) automatically restores 3rd-person platform elevation without requiring CET overlay toggles.
  - Eliminated stale Lua `mod.currentShoeState.isSuppressed` latch by dynamically checking suppression per frame and synchronizing REDscript state changes.
  - Added self-healing reconciliation in REDscript (`ClearWorkspotState` / `ClearVehicleState`) against `WorkspotSystem` and `VehicleComponent`.

---

## 7. Dependencies & Publishing Requirements

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
