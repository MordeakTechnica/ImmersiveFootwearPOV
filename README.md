# Immersive Footwear POV — Modder's Integration Guide

Make your custom footwear dynamically adjust V's height and first-person perspective in Cyberpunk 2077!

When a player equips your shoes or boots, **Immersive Footwear POV** reads tags in your item's TweakDB record and physically elevates V's stance to match your shoe's elevation.

---

## ⚡ Quick Start: How to Add Support

Adding support takes less than a minute. Simply add **1 or 2 tags** to your shoe item's TweakXL `.yaml` file:

```yaml
Items.Your_Custom_Shoe_Item:
  $base: Items.GenericFootClothing
  tags: !append-once
    - "HeelHeight_008"       # Heel height: elevates V by +8 cm in First-Person
    - "PlatformHeight_003"   # Front platform thickness: 3 cm (used for Photo Mode)
```

---

## 🏷️ The Two Height Tags

| Tag | What It Represents | Required? | What It Does |
| :--- | :--- | :---: | :--- |
| **`HeelHeight_<VALUE>`** | **Heel Elevation** | **Yes** | Sets how much V's character and FPP eye-line move up. |
| **`PlatformHeight_<VALUE>`** | **Front Platform Thickness** | *Optional* | The thickness of the sole under the ball of the foot. Reserved for future Photo Mode pose shifting. |

---

## 📋 Copy-Paste Examples

### 1. High Heels / Stilettos (No Front Platform)
*For pumps, stilettos, or open-toe heels where only the heel is raised:*

```yaml
Items.My_Classic_Stilettos:
  $base: Items.GenericFootClothing
  tags: !append-once
    - "HeelHeight_009"  # 9 cm heel elevation
```

---

### 2. Platform Boots & Wedges (Heel + Front Platform)
*For boots, wedges, or goth stompers that have both an elevated heel and a thick front platform:*

```yaml
Items.My_Goth_Platform_Boots:
  $base: Items.GenericFootClothing
  tags: !append-once
    - "HeelHeight_010"       # 10 cm heel elevation (moves V up in FPP)
    - "PlatformHeight_004"   # 4 cm front sole platform (stored for Photo Mode)
```

---

### 3. Flat Platform Sneakers / Creepers (Uniform Sole)
*For platform sneakers, chunky sandals, or creepers where the sole is flat across the whole foot:*

```yaml
Items.My_Chunky_Platform_Sneakers:
  $base: Items.GenericFootClothing
  tags: !append-once
    - "HeelHeight_006"       # 6 cm total elevation
    - "PlatformHeight_006"   # 6 cm sole thickness
```

---

### 4. Low Heels & Cowboy Boots (Modest Lift)
*For cowboy boots, cuban heels, or low dress shoes:*

```yaml
Items.My_Cowboy_Boots:
  $base: Items.GenericFootClothing
  tags: !append-once
    - "HeelHeight_004"  # 4 cm heel lift
```

---

## 🔢 Supported Number Formats

You can write the height numbers in any of these common formats:

* **Centimeters (Recommended):**  
  `HeelHeight_003` (3 cm), `HeelHeight_006` (6 cm), `HeelHeight_008` (8 cm), `HeelHeight_010` (10 cm), `HeelHeight_6` (6 cm), `HeelHeight_10` (10 cm)
* **Millimeters:**  
  `HeelHeight_30` (30 mm), `HeelHeight_60` (60 mm), `HeelHeight_80` (80 mm), `HeelHeight_100` (100 mm)
* **Decimal Meters:**  
  `HeelHeight_0.03` (0.03 m), `HeelHeight_0.06` (0.06 m), `HeelHeight_0.08` (0.08 m), `HeelHeight_0.10` (0.10 m)

*Alternative tag name aliases also supported: `Heel_008`, `ShoeHeel_008`, `Platform_004`, `ShoePlatform_004`.*

---

## 🔍 How to Test in Game

1. Install your mod alongside **Immersive Footwear POV** and **Cyber Engine Tweaks (CET)**.
2. Equip your footwear in-game (works with standard inventory, Wardrobe transmog, or Equipment-EX).
3. Look down in First-Person: V will stand taller and your character's height relative to NPCs and the environment will naturally reflect your shoe's heel height!
4. *(Optional)* Open the CET console or check the CET overlay window to verify your shoe tags were detected.
