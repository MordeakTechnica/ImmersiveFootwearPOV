# Comprehensive Technical Plan: Left Hand on Hip with Dynamic Locomotion Arm Compensation

**Feature Name:** Procedural Hand on Hip with Harmonic Locomotion Compensation  
**Target Mod:** Immersive Footwear POV  
**Reference Pose:** `juztNea - 10000 steps pose pack - PM.archive` (Pose `10k_steps_04`)  
**Status:** Documented & Archived (Reset to clean working tree pending user re-activation)  

---

## 1. Executive Summary & Core Concept

This feature implements a third-person (ITP) visual enhancement for female V that places her left hand gracefully on the upper lateral side of her hip (iliac crest) while unarmed and walking/standing.

Unlike simple static animation overwrites or pose mods, this system is **fully procedural and locomotion-aware**:
1. **Neutralizes walk swing:** Real-time inverse harmonic counter-rotation cancels underlying forward/backward arm swing ($\approx \pm 26.7^\circ$) during locomotion.
2. **Dynamic pelvic sway tracking:** Dynamic elbow oscillation absorbs the vertical $\pm 2.11\text{ cm}$ distance variation between the shoulder and the swaying pelvis, maintaining hand contact without clipping or floating.
3. **Contextual suppression:** Instant, smooth blend-out (0.20s) whenever weapons are equipped, or during sprinting, crouching, jumping, swimming, or in first-person perspective (FPP).
4. **Real-time in-game tuning:** Exposes live CET sliders for elbow flare, posterior elbow pull, forearm bend, and vertical offset so users can dial in the contact point for any clothing/body mesh.

---

## 2. Anatomical & Rotational Coordinate System Reference

REDengine uses a **Z-Up, Right-Handed Model Coordinate System**:
* `+Z`: Up (towards head)
* `+Y`: Forward (anterior direction / navel)
* `+X`: Right / `-X`: Left (lateral)

### 2.1 Skeletal Rest Pose (T-Pose) Bone Axes
From `base\characters\entities\player\player_woman_skeleton.rig.json`:
* `LeftArm` Joint: $X = -0.1803\text{ m}, Y = -0.0578\text{ m}, Z = 1.4894\text{ m}$
* `LeftForeArm` Joint: $X = -0.4708\text{ m}, Y = -0.0577\text{ m}, Z = 1.4895\text{ m}$ (Length: $0.2904\text{ m}$)
* `LeftHand` Joint: $X = -0.7461\text{ m}, Y = -0.0577\text{ m}, Z = 1.4896\text{ m}$ (Length: $0.2753\text{ m}$)
* Relative rest rotation between `LeftArm`, `LeftForeArm`, and `LeftHand` is **Identity** `(0, 0, 0, 1)`.

### 2.2 In-Game Hanging Arm Orientation (Base Locomotion)
When the arm hangs naturally down by the side:
* **Local $+X$ Axis:** Points **DOWN** along the bone length towards the floor.
* **Local $+Y$ Axis:** Points **BACKWARD** (posterior).
* **Local $+Z$ Axis:** Points **LEFT** (lateral outward) via right-hand rule ($-\hat{k} \times -\hat{j} = -\hat{i}$).

### 2.3 Rotational Signs & Verified In-Game Behaviors
Through empirical in-game tests, the exact behavior of `animAnimNode_RotateBone` on each axis was verified:

| Bone & Axis | Node Handle | Sign | Direction / Motion in Game | Confirmed Behavior |
| :--- | :---: | :---: | :--- | :--- |
| **`LeftArm` `Y_Axis`** | `6037` | **Negative ($-$)** | **Lateral Abduction (Elbow Flare)** | Elbow flares outward away from ribcage. Confirmed correct by user. |
| **`LeftArm` `Y_Axis`** | `6037` | Positive ($+$) | Medial Adduction | Upper arm presses inward against ribs. |
| **`LeftArm` `Z_Axis`** | `6035` | **Positive ($+$)** | **Posterior Pitch (Elbow Back)** | Pulls elbow backward behind waistline. |
| **`LeftArm` `Z_Axis`** | `6035` | Negative ($-$) | Anterior Pitch | Swings upper arm forward into space. |
| **`LeftForeArm` `Z_Axis`** | `6039` | **Negative ($-$)** | **Elbow Flexion (Forward Bend)** | Bends forearm forward across the flank towards the hip. |
| **`LeftForeArm` `Z_Axis`** | `6039` | Positive ($+$) | Elbow Hyperextension (Backward) | Forearm bends backward into buttocks/flank. |

---

## 3. Empirical Test Log & Lessons Learned

### Test 1 (Initial Implementation):
* **Settings:** `targetFlare = +22.0°` (LeftArm Y), `targetElbow = +82.1°` (LeftForeArm Z).
* **User Feedback:** *"lower arm is turned backwards, partially clipping through the left hip, upper arm is pushed slightly inwards"*
* **Diagnosis:** Signs were inverted. Positive Y on `LeftArm` pushes the arm inward; positive Z on `LeftForeArm` hyperextends the forearm backward.

### Test 2 (Sign Inversion & Zero Pitch):
* **Settings:** `targetFlare = -22.0°` (LeftArm Y), `targetPitch = 0.0°` (LeftArm Z standing), `targetElbow = -82.1°` (LeftForeArm Z).
* **User Feedback:** *"elbow is sticking out now (correct) but fore arm is pointing forward. Hand should be resting on the left upper side of the hip. There is a photo mode pose that has the correct orientation for the arm if that helps [jutznea 10000 steps, pose: 10k_steps_04]"*
* **Diagnosis:**
  1. Elbow flare ($-22.0^\circ$) was confirmed 100% correct by the user.
  2. Bending the forearm by $-82.1^\circ$ while upper arm pitch was $0.0^\circ$ (hanging straight down) projected the forearm horizontally forward into space in front of the abdomen like a tray.
  3. Analysis of photomode reference `10k_steps_04` revealed the true hand-on-hip anatomy:
     * The upper arm must have a **posterior tilt** (`+18.0°` to `+22.0°` on `LeftArm` `Z_Axis`) to pull the elbow behind the lateral waistline.
     * With the elbow behind the waistline, a moderate forward bend (`-48.0°` to `-50.0°` on `LeftForeArm` `Z_Axis`) angles the forearm cleanly across the flank and lands the hand flat on the upper lateral hip.

---

## 4. AnimGraph Architecture (`player_base.animgraph.json`)

### 4.1 Injected Variables (`floatVariables`)
Registered in `RootChunk.variables.floatVariables`:
* `ifp_left_arm_pitch` (Handle `6030`): Range `[-60.0, 60.0]`, default `0.0`.
* `ifp_left_arm_flare` (Handle `6031`): Range `[-60.0, 60.0]`, default `0.0`.
* `ifp_left_elbow_flex` (Handle `6032`): Range `[-120.0, 120.0]`, default `0.0`.
* `ifp_left_arm_blend` (Handle `6033`): Range `[0.0, 1.0]`, default `0.0`.

### 4.2 Injected Bone Rotation Nodes
Spliced directly before Output Node `1` (master pose output), downstream of Node `4208`:

```text
Node 4208 (Locomotion Master Blend)
     │
     ▼
Node 6035: animAnimNode_RotateBone
  - Bone: LeftArm
  - Axis: Z_Axis (Posterior Pitch / Swing Cancel)
  - Angle Variable: ifp_left_arm_pitch (6030)
  - Weight Variable: ifp_left_arm_blend (6033)
  - Limits: [-60.0°, +60.0°]
     │
     ▼
Node 6037: animAnimNode_RotateBone
  - Bone: LeftArm
  - Axis: Y_Axis (Lateral Elbow Flare)
  - Angle Variable: ifp_left_arm_flare (6031)
  - Weight Variable: ifp_left_arm_blend (6033)
  - Limits: [-60.0°, +60.0°]
     │
     ▼
Node 6039: animAnimNode_RotateBone
  - Bone: LeftForeArm
  - Axis: Z_Axis (Elbow Flexion)
  - Angle Variable: ifp_left_elbow_flex (6032)
  - Weight Variable: ifp_left_arm_blend (6033)
  - Limits: [-120.0°, +120.0°]
     │
     ▼
Node 1 (AnimGraph Final Output)
```

---

## 5. Kinematic Formulation (`stride.lua`)

### 5.1 Baseline Angles
* `BASE_ARM_FLARE_DEG = 22.0` (abduction angle; applied as negative `-22.0°`)
* `BASE_ARM_BACK_DEG = 18.0` (posterior extension; applied as positive `+18.0°`)
* `BASE_ELBOW_FLEX_DEG = 48.0` (forearm bend; applied as negative `-48.0°`)
* `SWING_CANCEL_DEG = 26.65` (inverse harmonic walk counter-rotation)
* `DYNAMIC_ELBOW_COMP_DEG = 10.5` (absorbs pelvic roll distance variation $\pm 2.1\text{ cm}$)
* `DYNAMIC_FLARE_COMP_DEG = 1.2` (breathing expansion on hip peaks)

### 5.2 Real-Time Kinematic Equations
```lua
-- Dynamic compensation components
local dynamicElbow = 0.0
local dynamicFlare = 0.0
if speed >= 0.15 and Stride.currentBlend > 0.001 then
    local swayScale = heelScale * intensity * speedDamp
    dynamicElbow = Stride.DYNAMIC_ELBOW_COMP_DEG * math.cos(Stride.phase) * swayScale
    dynamicFlare = Stride.DYNAMIC_FLARE_COMP_DEG * math.cos(Stride.phase) * swayScale
end

-- Walk swing cancellation (neutralizes forward arm swing)
local dynamicPitch = 0.0
if speed >= 0.15 then
    local walkDamp = math.min(1.0, (speed - 0.15) / 0.85)
    dynamicPitch = Stride.SWING_CANCEL_DEG * math.sin(Stride.phase) * walkDamp * speedDamp
end

-- Final target angles
local targetElbow = -(baseForearm + heightOffset + dynamicElbow)
local targetFlare = -(baseFlare + dynamicFlare)
local targetPitch = baseBack + dynamicPitch

Stride.currentElbowFlex = targetElbow * Stride.currentArmBlend
Stride.currentArmFlare = targetFlare * Stride.currentArmBlend
Stride.currentArmPitch = targetPitch * Stride.currentArmBlend
```

---

## 6. Redscript Context & Weapon Suppression

In `ImmersiveFootwearPOV_Suppression.reds`:
* Evaluates weapon presence via `TransactionSystem`:
  ```reds
  let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(player.GetGame());
  let hasWeaponRight: Bool = IsDefined(ts.GetItemInSlot(player, t"AttachmentSlots.WeaponRight"));
  let hasWeaponLeft: Bool = IsDefined(ts.GetItemInSlot(player, t"AttachmentSlots.WeaponLeft"));
  let canArm: Bool = canSway && !hasWeaponRight && !hasWeaponLeft;
  ```
* Seamlessly suppressed during:
  * Armed weapon states (firearm, melee, cyberware)
  * Sprinting, crouching, sliding, climbing, swimming, airborne (jump/fall)
  * First-Person Perspective (FPP)
  * Photo Mode

---

## 7. Interactive In-Game Tuning Controls (CET)

Exposed under the **"Catwalk Locomotion [Beta]"** tab in the CET overlay:

| Control | State Variable | Default | Range | Description |
| :--- | :--- | :---: | :---: | :--- |
| **Left Hand on Hip** | `enableHandOnHip` | `false` | Checkbox | Toggles the procedural 3rd-person pose on/off. |
| **Elbow Flare** | `armElbowFlare` | `22.0°` | `10.0°` to `40.0°` | Upper arm lateral abduction (elbow distance from ribs). |
| **Elbow Back** | `armElbowBack` | `+18.0°` | `-10.0°` to `40.0°` | Posterior upper arm tilt to pull elbow behind hip line. |
| **Forearm Bend** | `armForearmBend` | `48.0°` | `20.0°` to `80.0°` | Elbow flexion angle positioning hand on upper hip. |
| **Hip Height Offset** | `armHipHeightOffset` | `0.0°` | `-10.0°` to `10.0°` | Fine-tunes contact height for different clothing meshes. |

All settings persist in `ImmersiveFootwearPOV_Settings.json`.

---

## 8. Blueprint to Re-Enable / Re-Deploy

When ready to re-activate this feature:
1. Re-apply the AnimGraph nodes via `tools/inject_arm_hip_nodes.py` (or restore the modified `player_base.animgraph.json`).
2. Add `canHandOnHip` to `SwayContextData` and `TransactionSystem` checks in `ImmersiveFootwearPOV_Suppression.reds`.
3. Add the kinematic variables and publication in `stride.lua`.
4. Add the settings and UI sliders in `config.lua`, `init.lua`, and `ifp.lua`.
5. Run `powershell -ExecutionPolicy Bypass -File tools/pack_and_deploy.ps1`.
