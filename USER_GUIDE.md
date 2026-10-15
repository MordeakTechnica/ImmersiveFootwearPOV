# Immersive Footwear POV — Player Guide & Height Setup

A comprehensive guide for configuring custom footwear heights and getting accurate measurements using Cyberpunk 2077's native Photo Mode.

---

## 1. How Height Adjustments Work

* **Heel Height (FPP Elevation):** Dynamically elevates V's First-Person Perspective (FPP) camera eye-line and physical skeleton stance during gameplay based on the equipped footwear.
* **Platform Height (Photo Mode Elevation):** Elevates V's 3rd-person character puppet in Photo Mode so thick platform soles and boots do not sink or clip into the ground.

---

## 2. In-Game Settings & Live Shoe Calibrator (100% Native Redscript)

Immersive Footwear POV is 100% native Redscript and no longer requires Cyber Engine Tweaks (CET). All menus and overlays run directly in REDengine:

### 2.1 Native In-Game Settings Menu (RCF)
1. Pause the game and navigate to **Settings** $\rightarrow$ **Mods** $\rightarrow$ **Immersive Footwear POV** (powered by *Redscript Configuration Framework*).
2. Configure your experience across 4 organized tabs:
   * **Stance & Elevation:** Toggle First-Person (FPP) camera lift, adjust camera easing speed (`0.10s` – `1.0s`), toggle Third-Person (ITP) physical elevation, and configure Photo Mode auto-elevation.
   * **Catwalk Locomotion:** Toggle dynamic pelvic hip sway and customize sway intensity multipliers for low (`2–5 cm`), mid (`6–9 cm`), and high (`10+ cm`) heels.
   * **Suppression:** Enable or disable contextual auto-suppression during vehicles, workspots (sitting on chairs/beds), and scripted dialogue scenes.
   * **Management & Storage:** One-click launch buttons for the **Live Diagnostics HUD** and **Live Shoe Calibrator**, toggle verbose debug logs, reload presets from disk, or reset to factory defaults.

### 2.2 Live Shoe Height Calibrator (RedWindows)
To calibrate any custom or untagged mod shoe with instant real-time character preview:
1. Equip your footwear using **Inventory**, **Vanilla Wardrobe (Transmog)**, or **Equipment-EX**.
2. Open the Calibrator via **Pause Menu $\rightarrow$ Mods $\rightarrow$ Immersive Footwear POV $\rightarrow$ Open Live Shoe Height Calibrator** (or click the button in the Diagnostics HUD).
3. Adjust the floating sliders:
   * **Heel Height (cm):** Sets total shoe heel height (`0.0` – `15.0 cm`). Instantly updates V's physical stance and eye-line in real time.
   * **Platform Sole (cm):** Sets front sole / platform lift (`0.0` – `10.0 cm`). Instantly updates V's third-person ground clearance.
4. Click **Save as Permanent Custom Override** to persist your calibration permanently.
5. If a shoe has official TweakDB tags or community presets, click **Revert to Tag/Preset Default** at any time to return to baseline.

### 2.3 Live Diagnostics HUD (RedWindows)
* Open via **Pause Menu $\rightarrow$ Mods $\rightarrow$ Immersive Footwear POV $\rightarrow$ Open Live Diagnostics HUD**.
* Displays real-time telemetry: equipped footwear ItemID and resolution source, heel height (cm), platform thickness (cm), effective Z-lift (cm), active perspective (FPP, ITP, PM), and contextual suppression state (Vehicles, Workspots, Scenes).

### 2.4 Native Storage & Community Presets (RedFunctions)
* All settings and calibrations are saved natively in `<Cyberpunk 2077>\r6\storages\ImmersiveFootwearPOV\`:
  * `config.json`: Mod settings, locomotion multipliers, and suppression toggles.
  * `user_shoe_overrides.json`: Personal shoe height calibrations.
  * `presets.json`: Community preset catalog.
* **Automatic CET Migration:** If you previously had `user_shoe_overrides.json` from the legacy CET version, the mod automatically detects and migrates your calibrations into native `r6/storages/` on first launch—zero manual copying required!
* **Automated Variant Expander Tool:** You can automatically expand a single calibrated shoe across all of its colors, materials, and mod variants using the built-in [Preset Variant Expander](tools/preset_variant_expander/README.md).

---

## 3. How to Measure Exact Shoe Heights in Photo Mode (PM)

To find the precise numbers for any custom modded footwear without guessing:

1. Stand on **flat, level ground** and enter **Photo Mode** (`Space` on keyboard / `N` on controller).
2. Move the free camera down to floor level and look at V's feet from the side.

### Step 1: Find Platform Height (Front Sole Lift)
1. In Photo Mode position settings, move the **V Up/Down** slider **upwards** until the bottom of the front sole (under the ball of the foot/toes) sits perfectly flush on top of the ground surface.
2. The positive distance you raised the puppet is your platform sole height (e.g., `+0.03 m` $\rightarrow$ set **Custom Platform** to **`3.0 cm`**).
   *(For thin-soled stilettos or flat shoes with no front sole thickness, leave at `0.0 cm`).*

### Step 2: Find Heel Height (Total Elevation)
1. Reset the position slider back to neutral (`0.00`).
2. Move the **V Up/Down** slider **downwards** until the back of V's heel (where the foot sits inside the shoe cup) touches the ground level.
3. Note the distance lowered (e.g., `-0.08 m` $\rightarrow$ `8.0 cm`).
4. **Add the Platform Height to this value** to get your full Heel Height:
   $$\text{Full Heel Height} = \text{Lowered Distance} + \text{Platform Height}$$
   *(**Example:** `8.0 cm` lowered $+ 3.0 \text{ cm}$ platform $\rightarrow$ set **Custom Heel** to **`11.0 cm`**).*

---

## 4. Automatic Context Suppression

You don't need to manually turn the mod off during special gameplay moments. The mod automatically suppresses height offsets back to baseline (`0.0 cm`) during:
* **Vehicles:** Mounting, driving, and unmounting cars or motorcycles.
* **Furniture & Workspots:** Sitting on chairs, barstools, sofas, or sleeping in beds.
* **Scripted Scenes:** Story cutscenes and high dialogue tiers.
* **Physical Traversal:** Climbing ladders, swimming, carrying bodies, and takedowns.

Elevation smoothly restores over `0.20s` when returning to normal standing gameplay.
