# Immersive Footwear POV — Modder's Integration Guide

Make your custom footwear dynamically adjust V's height in first-person gameplay and automatically elevate character poses in Photo Mode in Cyberpunk 2077!

When a player equips your shoes or boots, **Immersive Footwear POV** reads tags in your item's TweakDB record and physically elevates V's skeleton and camera stance in real time.

---

## ⚡ Quick Start: How to Add Support

Adding support takes less than a minute. Simply add **1 or 2 tags** to your footwear item's TweakXL `.yaml` file:

```yaml
Items.Your_Custom_Shoe_Item:
  $base: Items.GenericFootClothing
  tags: !append-once
    - "HeelHeight_008"       # Total heel elevation: +8 cm (elevates V in First-Person)
    - "PlatformHeight_003"   # Front platform thickness: 3 cm (elevates puppet in Photo Mode)
```

---

## 🏷️ The Two Height Tags

| Tag | What It Represents | Required? | What It Does |
| :--- | :--- | :---: | :--- |
| **`HeelHeight_<VALUE>`** | **Total Heel Elevation** | **Yes** | Sets the total vertical elevation from the ground to where V's heel rests. Elevates V's 1st-person camera and skeleton stance in gameplay. |
| **`PlatformHeight_<VALUE>`** | **Front Platform Sole** | *Optional* | The thickness of the front sole under the ball/toes. Automatically elevates V's 3rd-person character model in Photo Mode (via native Attribute 37) so thick platform soles do not sink into the ground. |

> [!TIP]
> **Heel Height Formula:**  
> $\text{HeelHeight} = \text{Anatomical Heel Slope} + \text{Front Platform Thickness}$  
> *(If your boot has a 4 cm front platform sole and an 8 cm slope up to the heel, set `HeelHeight_012` and `PlatformHeight_004`).*

---

## 📋 Copy-Paste YAML Examples

### 1. High Heels / Classic Stilettos (No Front Platform)
*For pumps, stilettos, or sandals where the ball of the foot touches the floor:*

```yaml
Items.My_Classic_Stilettos:
  $base: Items.GenericFootClothing
  tags: !append-once
    - "HeelHeight_009"  # 9 cm total heel elevation (0 cm platform)
```

---

### 2. Platform Boots & High Wedges (Heel + Front Platform Sole)
*For platform heels, wedges, or goth boots with both an elevated heel and a thick front platform:*

```yaml
Items.My_Goth_Platform_Boots:
  $base: Items.GenericFootClothing
  tags: !append-once
    - "HeelHeight_012"       # 12 cm total heel elevation (moves V up in FPP)
    - "PlatformHeight_004"   # 4 cm front sole platform (lifts puppet in Photo Mode)
```

---

### 3. Flat Platform Sneakers / Creepers (Continuous Uniform Sole)
*For platform sneakers, chunky sandals, or creepers where the sole is flat across the entire foot:*

```yaml
Items.My_Chunky_Platform_Sneakers:
  $base: Items.GenericFootClothing
  tags: !append-once
    - "HeelHeight_006"       # 6 cm total elevation
    - "PlatformHeight_006"   # 6 cm sole thickness
```

---

### 4. Low Heels & Cowboy Boots (Modest Lift)
*For cowboy boots, cuban heels, combat boots, or low dress shoes:*

```yaml
Items.My_Cowboy_Boots:
  $base: Items.GenericFootClothing
  tags: !append-once
    - "HeelHeight_004"  # 4 cm heel lift
```

---

## 📐 How to Measure Your Shoes

You can measure your shoe dimensions directly in your 3D modeling software (Blender) or in-game using Photo Mode:

### Method A: In Blender / 3D Software
* **`PlatformHeight`:** Measure the vertical $Z$-thickness from the bottom of the front outsole to the footbed under the ball of the foot.
* **`HeelHeight`:** Measure the vertical $Z$-distance from the floor contact plane to the footbed where V's heel rests inside the shoe.

### Method B: In-Game via Photo Mode (PM)
1. Equip your shoe and enter **Photo Mode** (`Space` / `N`).
2. **Find Platform:** In position settings, move the **V Up/Down** slider **upwards** until the front sole sits flush on the ground $\rightarrow$ the distance raised is your `PlatformHeight` (e.g., `+0.03 m` = `PlatformHeight_003`).
3. **Find Heel:** Move the slider **downwards** until the back of V's heel touches the ground level $\rightarrow$ add the platform thickness to this distance to get your total `HeelHeight` (e.g., `0.08 m` drop $+ 0.03 \text{ m}$ platform = `HeelHeight_011`).

---

## 🔢 Supported Number Formats & Tag Aliases

You can write tag values in any of the following standard formats (up to **25 cm / 0.25 m**):

* **Centimeters (Recommended):**  
  `HeelHeight_003` (3 cm), `HeelHeight_006` (6 cm), `HeelHeight_008` (8 cm), `HeelHeight_010` (10 cm), `HeelHeight_6` (6 cm), `HeelHeight_12` (12 cm)
* **Millimeters:**  
  `HeelHeight_30` (30 mm), `HeelHeight_60` (60 mm), `HeelHeight_80` (80 mm), `HeelHeight_120` (120 mm)
* **Decimal Meters:**  
  `HeelHeight_0.03` (0.03 m), `HeelHeight_0.06` (0.06 m), `HeelHeight_0.08` (0.08 m), `HeelHeight_0.12` (0.12 m)

### Supported Tag Aliases
* **Heel Tag Formats:** `HeelHeight_XXX`, `Heel_XXX`, `ShoeHeel_XXX`, `ShoeHeight_XXX`, `FootwearHeight_XXX`
* **Platform Tag Formats:** `PlatformHeight_XXX`, `Platform_XXX`, `ShoePlatform_XXX`

---

## 🔍 How to Test & Verify in Game

1. Install your mod alongside **Immersive Footwear POV** and **Cyber Engine Tweaks (CET)**.
2. Equip your footwear in-game (supports Gameplay Equipment slots, Vanilla Wardrobe / Transmog, and Equipment-EX).
3. **Check the CET Overlay (`~`):**
   * The mod overlay will immediately display `Tags: Official TweakDB Metadata (Locked)` in green, showing your parsed Heel and Platform values.
4. **CET Console Verification:**
   * Open the CET console and run `GetMod("ImmersiveFootwearPOV"):DumpState()` to view an instant diagnostics dump of your item's resolved metadata, parsed meters, and stance math.
