# Axis & Motion Reference Guide — Immersive Footwear POV

A quick, practical reference cheat-sheet for character coordinates, rotation axes, bone movements, and phrasing movement adjustments.

---

## 1. Quick Coordinate Cheat-Sheet

Cyberpunk 2077 / REDengine uses a **Z-Up, Right-Handed Model Coordinate System**:

```text
                  +Z (UP: Towards Head)
                   |
                   |   +Y (FORWARD: Navel / Facing Direction)
                   |  /
                   | /
  -X (RIGHT) ------+------ +X (LEFT)
                  /|
                 / |
                /  |
  -Y (BACKWARD)    -Z (DOWN: Towards Ground)
```

| Axis | Linear Direction | Rotational Name | Everyday Analogy | What it does to the Pelvis / Hips |
| :---: | :---: | :---: | :---: | :---: |
| **Y** | Back $\leftrightarrow$ Front | **ROLL** | **"Rotisserie Skewer" / Teeter-Totter** | **See-Saw Tilt:** Left hip lifts up while right hip drops down (lateral hip sway). |
| **Z** | Down $\leftrightarrow$ Up | **YAW** | **"Carousel" / Swivel Chair** | **Horizontal Swivel:** Left hip rotates forward while right hip pulls backward. |
| **X** | Left $\leftrightarrow$ Right | **PITCH** | **"Foosball Rod" / Bending forward** | **Pelvic Tilt:** Tucking tailbone forward or arching lower back. |

---

## 2. Visual Viewpoints (From Behind V in 3rd-Person)

### View A: Behind View (Looking at V's Back — The Catwalk View)

```text
          [ HEAD ]
             ||
        [ SHOULDERS ]   <-- Spine2 (Counter-Roll absorbs hip tilt)
             ||
             ||
         /--------\
        |   HIPS   |    <-- Hips ROLL (Y-Axis):
         \--------/         Left hip lifts UP (+) as Right hip drops DOWN (-)
          /      \          Produces the classic catwalk teeter-totter!
         /        \
      [THIGH]  [THIGH]  <-- LeftUpLeg / RightUpLeg (Counter-Roll keeps legs
        ||       ||         pointing straight down instead of swinging outward)
        ||       ||
      [FOOT]   [FOOT]   <-- Feet touch down along a straight catwalk line
```

* **Y-Axis Rotation (Roll):** Tilts the pelvis like a see-saw.
  * $+Y^\circ$: Left hip lifts up, right hip drops down.
  * $-Y^\circ$: Right hip lifts up, left hip drops down.
  * *In Mod:* Controlled by `ifp_hip_sway_roll` (`BASE_ROLL_DEG = 4.8°`).

---

### View B: Top-Down View (Looking Down from Above V's Head)

```text
               FRONT (Facing Forward / +Y)
                       ^
                       |
               /===============\
      LEFT    |  LEFT     RIGHT |   RIGHT
      HIP     |   HIP      HIP  |    HIP
              |       (Z)       |   
               \===============/
                       |
                       v
                BACK (Behind / -Y)
```

* **Z-Axis Rotation (Yaw):** Twists the pelvis horizontally around the spine.
  * $+Z^\circ$: Left hip rotates forward, right hip pulls back.
  * $-Z^\circ$: Right hip rotates forward, left hip pulls back.
  * *In Mod:* Controlled by `ifp_hip_sway_yaw` (`BASE_YAW_DEG = 3.0°`). Synchronized so the advancing hip rotates forward with the reaching leg.

---

### View C: Side View (Looking at V from the Right Profile)

```text
           BACK (-Y)           FRONT (+Y)
               \                   /
                \     [HEAD]      /
                       |
                   [SPINE2]
                       |
                    (X-AXIS)  <-- Pitch axle runs Left-to-Right
                   /       \
                  |  HIPS   | <-- Hips PITCH (X-Axis):
                   \       /      Rotates pelvis forward/backward
                     |   |
                   [LEGS]
```

* **X-Axis Rotation (Pitch):** Tilts the pelvis forward or backward.
  * Anterior tilt (arching lower back / butt out).
  * Posterior tilt (tucking pelvis forward / flat back).
  * *In Mod:* Feet pitch is plantarflexion (pointing toes down in high heels).

---

## 3. Body Parts & Injected Animation Nodes

Our mod controls specific bones in the skeleton using dedicated anim nodes:

| Body Part | Skeleton Bone | Axis | Rotation Name | Variable Name | Role in Catwalk Locomotion |
| :--- | :--- | :---: | :---: | :--- | :--- |
| **Pelvis / Hips** | `Hips` | **Y** | **Roll** | `ifp_hip_sway_roll` | Primary catwalk see-saw tilt ($4.8^\circ$ base). |
| **Pelvis / Hips** | `Hips` | **Z** | **Yaw** | `ifp_hip_sway_yaw` | Forward hip reach / swivel ($3.0^\circ$ base, matches forward leg). |
| **Pelvis / Hips** | `Hips` | **Z (Pos)** | **Elevation** | `ifp_height_blend` | Vertical lift for high heels & platform soles. |
| **Shoulders / Torso** | `Spine2` | **Y** | **Counter-Roll** | `ifp_spine_counter_roll` | Absorbs hip tilt ($-1.25\times$) so shoulders & head stay level. |
| **Shoulders / Torso** | `Spine2` | **Z** | **Counter-Yaw** | `ifp_spine_counter_yaw` | Counters hip twist ($-0.55\times$) to stabilize arm swing. |
| **Left Thigh** | `LeftUpLeg` | **Y** | **Counter-Roll** | `ifp_leg_counter_roll` | Cancels $75\%$ of hip tilt so the left leg tracks straight. |
| **Right Thigh** | `RightUpLeg`| **Y** | **Counter-Roll** | `ifp_leg_counter_roll` | Cancels $75\%$ of hip tilt so the right leg tracks straight. |

---

## 4. Heel Height & Sway Scaling Tiers

Sway is governed by **Effective Heel Rise** ($\text{Heel Height} - \text{Platform Sole}$):

| Tier | Heel Rise | Sway Scale | Visual Effect |
| :--- | :--- | :---: | :--- |
| **Flat / Platform** | $< 2.0\text{ cm}$ ($< 0.8"$) | **0%** | Neutral standard walk. Zero hip sway. |
| **Low / Kitten Heel** | $\sim 2.5\text{ cm}$ ($1.0"$) | **35%** | Subtle, graceful feminine hip roll. |
| **Mid Heel** | $\sim 5.0\text{ cm}$ ($2.0"$) | **70%** | Moderate, distinct catwalk stride. |
| **High Heel / Stiletto** | $\ge 7.5\text{ cm}$ ($3.0"+$) | **100% Max** | Full runway catwalk locomotion. |

---

## 5. How to Phrase Changes When Asking Questions

Use these quick templates whenever you want to adjust or experiment with movement:

| What you are seeing or feeling | Technical Meaning | What to tell me |
| :--- | :--- | :--- |
| *"The hips don't tilt up and down enough sideways"* | Needs more **Y-Axis Roll** | `"Increase hip roll"` or `"More Y-axis see-saw"` |
| *"The hips are tilting too aggressively sideways"* | Needs less **Y-Axis Roll** | `"Decrease hip roll"` or `"Less Y-axis roll"` |
| *"The hips are twisting / swiveling forward & back too much"* | Needs less **Z-Axis Yaw** | `"Reduce hip yaw"` or `"Less horizontal swivel"` |
| *"The stepping leg isn't reaching forward enough"* | Needs more **Z-Axis Yaw** | `"Increase hip yaw slightly"` |
| *"The shoulders are dipping / wobbling too much with the hips"* | Needs more **Spine2 Counter-Roll** | `"Increase shoulder counter-roll"` |
| *"The torso looks too stiff / shoulders don't react to hips"* | Needs less **Spine2 Counter-Roll** | `"Loosen up shoulder counter-roll"` |
| *"The legs are flaring out wide like a cowboy (circumduction)"* | Needs more **Thigh Counter-Roll** | `"Increase leg counter-roll ratio"` |
| *"The legs look glued together / crossing over too tightly"* | Needs less **Thigh Counter-Roll** | `"Reduce leg counter-roll ratio"` |
| *"The hips are swaying too fast / frantic at normal walk"* | Stride frequency is too high | `"Slow down the sway frequency at low walk speeds"` |
| *"Low heels have too much sway"* | Adjust the 1-inch tier scale | `"Reduce the sway scale on 1-inch heels"` |
