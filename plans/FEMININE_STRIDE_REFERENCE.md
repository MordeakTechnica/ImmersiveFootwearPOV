# Feminine Stride & Procedural Hip Sway — Technical Reference & Architecture

**Document Version:** 1.0.0  
**Target Mod:** Immersive Footwear POV (`feat/feminine-stride`)  
**Game Engine:** Cyberpunk 2077 / REDengine 4  
**Last Updated:** 2026-09-28  

---

## 1. REDengine Character Coordinate System Reference

Cyberpunk 2077 / REDengine uses a **Z-Up, Right-Handed Coordinate System** for character model space (`inModelSpace: 1`):

| Axis | Direction | Vector | Rotation Name | Physical Motion on Pelvis / Hips |
| :--- | :--- | :--- | :--- | :--- |
| **X_Axis** | Lateral (Left ↔ Right) | `(1, 0, 0)` | **Pitch** | **Pelvic tilt forward/backward** (tucking tailbone in / arching back like a foosball rod) |
| **Y_Axis** | Longitudinal (Back ↔ Front) | `(0, 1, 0)` | **Roll** | **Teeter-Totter / See-Saw** (left hip lifts up while right hip drops down, and vice versa) |
| **Z_Axis** | Vertical (Feet ↔ Head) | `(0, 0, 1)` | **Yaw** | **Transverse Swivel** (left hip swings forward while right hip pulls backward) |

### Key Intuitions:
* **The "Skewer" Analogy for Roll (Y-Axis):** An axle running through the lower back to the navel. Rotating this axle tilts the left and right hip up and down in opposition.
* **Why Z-Axis Yaw Created "Back-to-Front" Motion:** Rotating around the vertical Z-axis turns the pelvis horizontally like a carousel. When set too high (e.g. 5.5°), the outer hip joints sweep forward and backward in a prominent arc, masking the vertical see-saw.

---

## 2. Injected Custom Animgraph Nodes (`player_base.animgraph`)

The custom nodes are injected into `source/raw/base/gameplay/anim_graphs/player_base.animgraph.json` upstream of elevation and Foot IK:

### Pelvic Motion Nodes (Hips)
| HandleId | Node Type | Bone | Axis | inModelSpace | Variable Name | Purpose |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **6010** | `animAnimNode_RotateBone` | `Hips` | `Y_Axis` | `1` | `ifp_hip_sway_roll` | Frontal plane lateral see-saw tilt (teeter-totter) |
| **6011** | `animAnimNode_FloatVariable` | — | — | — | `ifp_hip_sway_roll` | Float link for Handle 6010 |
| **6012** | `animAnimNode_RotateBone` | `Hips` | `Z_Axis` | `1` | `ifp_hip_sway_yaw` | Transverse plane forward leg reaching (swivel) |
| **6013** | `animAnimNode_FloatVariable` | — | — | — | `ifp_hip_sway_yaw` | Float link for Handle 6012 |

### Thoracic Counter-Rotation Nodes (Spine2)
| HandleId | Node Type | Bone | Axis | inModelSpace | Variable Name | Purpose |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **6016** | `animAnimNode_RotateBone` | `Spine2` | `Z_Axis` | `1` | `ifp_spine_counter_yaw` | Absorbs pelvic yaw; stabilizes shoulders & natural arm swing |
| **6017** | `animAnimNode_FloatVariable` | — | — | — | `ifp_spine_counter_yaw` | Float link for Handle 6016 |
| **6018** | `animAnimNode_RotateBone` | `Spine2` | `Y_Axis` | `1` | `ifp_spine_counter_roll` | Absorbs pelvic roll; keeps shoulders and head horizon level |
| **6019** | `animAnimNode_FloatVariable` | — | — | — | `ifp_spine_counter_roll` | Float link for Handle 6018 |

### Femoral Counter-Rotation Nodes (Thighs / LeftUpLeg & RightUpLeg)
Stabilizes leg trajectories directly beneath pelvis, eliminating gait circumduction (wide circular swinging of legs) and bowlegged stiffness:
| HandleId | Node Type | Bone | Axis | inModelSpace | Variable Name | Purpose |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **6023** | `animAnimNode_FloatVariable` | — | — | — | `ifp_leg_counter_roll` | Float link for Handle 6024 |
| **6024** | `animAnimNode_RotateBone` | `LeftUpLeg` | `Y_Axis` | `1` | `ifp_leg_counter_roll` | Counters pelvic roll tilt on left thigh; guides swing leg straight forward |
| **6025** | `animAnimNode_FloatVariable` | — | — | — | `ifp_leg_counter_roll` | Float link for Handle 6026 |
| **6026** | `animAnimNode_RotateBone` | `RightUpLeg` | `Y_Axis` | `1` | `ifp_leg_counter_roll` | Counters pelvic roll tilt on right thigh; guides swing leg straight forward |

### Elevation Nodes (Pre-existing ITP Elevation)
| HandleId | Node Type | Bone | Purpose |
| :--- | :--- | :--- | :--- |
| **6003** | `animAnimNode_TranslateBone` | `Hips` | Negative elevation limit (`-0.50m` Z-vector) |
| **6005** | `animAnimNode_TranslateBone` | `Hips` | Positive elevation limit (`+0.50m` Z-vector) |
| **6006** | `animAnimNode_Blend2` | — | Interpolates between -0.50m and +0.50m using `ifp_height_blend` |

### Custom Float Variables Registered in Graph Root
| HandleId | Variable CName | Default | Min | Max |
| :--- | :--- | :--- | :--- | :--- |
| **6014** | `ifp_hip_sway_roll` | `0.0` | `-45.0` | `45.0` |
| **6015** | `ifp_hip_sway_yaw` | `0.0` | `-45.0` | `45.0` |
| **6020** | `ifp_spine_counter_yaw` | `0.0` | `-45.0` | `45.0` |
| **6021** | `ifp_spine_counter_roll` | `0.0` | `-45.0` | `45.0` |
| **6022** | `ifp_leg_counter_roll` | `0.0` | `-45.0` | `45.0` |
| **6007** | `ifp_hip_sway_blend` | `0.0` | `0.0` | `1.0` |

---

## 3. Female NPC & Catwalk Benchmark Data

Extracted from `basegame_4_animation.archive` (`evelyn_purse_locomotion.anims`, `fa_purse_crowd_locomotion.anims`):
* **Pelvic Roll Obliquity (Y_Axis):** $10.0^\circ - 14.0^\circ$ peak-to-peak during stance phase.
* **Pelvic Yaw Swivel (Z_Axis):** $4.0^\circ - 6.0^\circ$ peak-to-peak.
* **Thoracic Spine Counter-Roll Ratio:** $\approx -0.58$ (absorbs 58% of hip tilt to prevent shoulder lurching).
* **Thoracic Spine Counter-Yaw Ratio:** $\approx -0.52$ (stabilizes forward arm posture).
* **Femoral Adduction / Plumb-Line Compensation:** The thighs must counter-tilt relative to the tilted pelvis so each foot steps along a tightrope line directly beneath the body's center of gravity.

---

## 4. Runtime Math & Module Constants (`modules/stride.lua`)

```lua
-- Kinematic oscillator equations:
phase = phase + (2.0 * math.pi * frequency * deltaTime)

-- Roll peaks at mid-stance (cosine), Yaw peaks at heel strike (sine):
currentRoll = BASE_ROLL_DEG * math.cos(phase) * masterScale
currentYaw  = BASE_YAW_DEG  * math.sin(phase) * masterScale

-- Counter-rotations applied to Spine2:
currentSpineCounterRoll = currentRoll * COUNTER_ROLL_RATIO
currentSpineCounterYaw  = currentYaw  * COUNTER_YAW_RATIO

-- Counter-rotations applied to LeftUpLeg & RightUpLeg (Thighs):
currentLegCounterRoll = currentRoll * COUNTER_LEG_ROLL_RATIO
```

* `BASE_ROLL_DEG`: $4.8^\circ$ (Y_Axis lateral teeter-totter tilt, provides ~3cm see-saw difference)
* `BASE_YAW_DEG`: $2.0^\circ$ (Z_Axis forward reach, guides legs straight forward along catwalk line)
* `COUNTER_ROLL_RATIO`: $-1.25$ (absorbs 100% hip roll + 25% opposite shoulder counter-tilt; keeps head centered)
* `COUNTER_YAW_RATIO`: $-0.52$ (Spine2 counter-yaw, stabilizes shoulders & arm swing)
* `COUNTER_LEG_ROLL_RATIO`: $-0.75$ (Thigh counter-roll, cancels 75% of hip tilt on thighs so legs track straight forward under pelvis)
* `frequency`: Scales dynamically with movement velocity: $f = \text{clamp}(0.6, 2.2, 0.55 + 0.32 \times \text{speed})$
* `heelScale`: Non-linear threshold:
  $$\text{norm} = \min(1.5, \frac{\text{heelCm} - 2.0}{6.5})$$
  $$\text{heelScale} = \max(0.40, \min(1.20, 0.45 + 0.60 \times \sqrt{\text{norm}}))$$

---

## 5. Recompilation & Deployment Pipeline

1. **JSON to CR2W:** WolvenKit CLI `unserialize` converts `player_base.animgraph.json` to `.animgraph`.
2. **Pack Archive:** WolvenKit CLI `pack` compresses `source/resources` to `##_ITP_Immersive_Footwear_POV.archive`.
3. **Deploy:** `powershell -ExecutionPolicy Bypass -File .\tools\pack_and_deploy.ps1`.
   Deploys to `D:\SteamLibrary\steamapps\common\Cyberpunk 2077`.
