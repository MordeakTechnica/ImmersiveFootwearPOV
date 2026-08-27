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

> [!TIP]
> **Backward Compatibility Fallback:**
> If an older footwear mod only defines `PlatformHeight_006` without a `HeelHeight` tag, the parser automatically treats the platform height as the heel height for FPP elevation.

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
- [ ] **Photo Mode Integration (Future PM Height Shifting):**
  - Use `platformHeight` (and `heelHeight`) for Photo Mode pose height shifting so V's character model maintains accurate sole ground contact and elevated stance across all photo poses.

### Phase 5: IFP Coexistence, UI Height Readout & Custom Overrides
- [x] **Direct IFP CET Window Appending (ImGui Extension):**
  - Hooked `onDraw` in `init.lua` using `ImGui.Begin("Immersive First Person")` to render live telemetry into IFP's window.
- [x] **Per-Shoe Custom Height Overrides & Persistence:**
  - Added JSON persistence (`user_shoe_overrides.json`) for untagged shoes.
  - Interactive sliders for Custom Heel Height ($0\text{--}15\,\text{cm}$) and Custom Platform ($0\text{--}10\,\text{cm}$).
  - Live shoe switching: updates immediately as V changes footwear across Equipment-EX, Wardrobe, and Inventory.
- [x] **Official TweakDB Precedence & Auto-Discard:**
  - Official TweakDB tags automatically lock controls to official metadata.
  - Any obsolete custom overrides for an item are automatically purged when official tags are detected.
- [x] **Additive IFP Base Slider Stacking:**
  - Real-time polling of IFP's native base height slider (`Config.inner.heightAdjustmentAmount`).
  - Stacks additively: $\text{Total Height} = \text{IFP Base Height} + \text{Footwear Heel Height}$.
  - Both IFP's slider and footwear elevation work concurrently without overriding each other.

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
