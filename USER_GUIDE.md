# Immersive Footwear POV — Player Guide & Height Setup

A comprehensive guide for configuring custom footwear heights and getting accurate measurements using Cyberpunk 2077's native Photo Mode.

---

## 1. How Height Adjustments Work

* **Heel Height (FPP Elevation):** Dynamically elevates V's First-Person Perspective (FPP) camera eye-line and physical skeleton stance during gameplay based on the equipped footwear.
* **Platform Height (Photo Mode Elevation):** Elevates V's 3rd-person character puppet in Photo Mode so thick platform soles and boots do not sink or clip into the ground.

---

## 2. Configuring Custom / Untagged Shoes (CET Overlay)

1. Equip your footwear using **Inventory**, **Vanilla Wardrobe (Transmog)**, or **Equipment-EX**.
2. Open the **Cyber Engine Tweaks (CET) Overlay** (`~`).
3. In the mod window, adjust the sliders:
   * **Custom Heel (cm):** Sets active 1st-person gameplay height elevation (`0.0` – `25.0 cm`).
   * **Custom Platform (cm):** Sets Photo Mode platform sole lift (`0.0` – `25.0 cm`).
4. **Auto-Save:** Settings are automatically saved per shoe model in `user_shoe_overrides.json`.
5. **Official Tag Precedence:** Shoes with official modder TweakDB tags (`HeelHeight_XXX` / `PlatformHeight_XXX`) will automatically detect their values and lock the sliders.

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
