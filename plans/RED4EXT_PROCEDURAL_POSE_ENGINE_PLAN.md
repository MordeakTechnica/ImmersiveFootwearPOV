# Comprehensive Technical Plan: Native RED4ext Procedural Pose Engine (Derived from APM Core)

**Document Name:** `RED4EXT_PROCEDURAL_POSE_ENGINE_PLAN.md`  
**Target Mod:** Immersive Footwear POV  
**Context:** Cyberpunk 2077 (Patch 2.0+ / Patch 2.31+) / REDengine 4 / RED4ext 1.30+  
**Architecture:** Self-Contained Native RED4ext C++ Plugin with REDscript & CET Presentation Bridges  
**Status:** **Deferred / Research Phase** (Awaiting Sitting Pose & Workspot Research)  

---

## 1. Executive Summary & Vision

This plan details the design and implementation of a self-contained, high-performance **native RED4ext C++ Pose Engine** for *Immersive Footwear POV*. Instead of maintaining an external dependency on `CP77AdvancedPoseMod` (which is hard-gated for Photo Mode and lacks real-time gameplay targeting), we extract and adapt APM's MIT-licensed mathematical core (analytic Two-Bone IK, anatomical joint limits, and terminal animation graph hook) into our own modular C++ plugin.

### Key Objectives:
1. **Real-Time TPP Procedural Posing:** Procedural skeletal adjustments directly in live gameplay (FPP and TPP) without requiring edits to `player_base.animgraph`.
2. **Dynamic Foot Grounding (Sitting & Workspots):** Leg IK (`LeftUpLeg -> LeftLeg -> LeftFoot`) that reads `HeelHeight` and `PlatformHeight` metadata to ground soles cleanly on the floor when seated, eliminating hovering or clipping.
3. **Procedural Hand on Hip:** Body-relative Two-Bone IK on the arms during idle/catwalk stances with natural elbow swivel.
4. **Clothing-Aware Clearance Offsets:** Metadata-driven clearance offsets calculated from equipped garment layers (`Clo_OuterChest`, `Clo_Legs`) to prevent hand/arm clipping into heavy coats, holsters, and belts.
5. **Real-Time Delta-Time Smoothing:** Exponential $\alpha$-weight blending ($w_t = w_{t-1} + (w_{\text{target}} - w_{t-1}) \cdot (1 - e^{-\lambda \Delta t})$) to guarantee zero transform popping or snapping.
6. **Strict Zero-Conflict Coexistence with APM:** Ironclad isolation guarantees ensuring that if a user has both our plugin and APM installed, they coexist seamlessly without hook, RTTI, or thread contention.

---

## 2. Anti-Conflict Architecture (Guaranteeing Zero Conflict with APM)

If a user installs both `AdvancedPoseMod` (for Photo Mode posing) and `ImmersiveFootwearPOV` (for gameplay posing), our plugin guarantees 100% collision-free coexistence through five architectural rules:

```
                         [REDengine Animation Pipeline]
                                       │
                                       ▼
                         animAnimNode_Output::Sample()
                                       │
              ┌────────────────────────┴────────────────────────┐
              ▼                                                 ▼
   [APM's Detour_Sample]                            [IFP's Detour_Sample]
   • Runs ONLY when PhotoMode is ACTIVE             • Runs ONLY during real-time GAMEPLAY
   • If In-Game -> Immediately Yields               • If PhotoMode Active -> Immediately Yields
   • Uses APM_* RTTI namespace                      • Uses IFP_* RTTI namespace
```

| Isolation Layer | Implementation Detail | Guarantee |
| :--- | :--- | :--- |
| **1. Photo Mode Handshake** | `if (IFP::PhotoModeTracker::IsActive()) return;` | When Photo Mode activates, IFP immediately yields. APM has 100% exclusive control. In gameplay, APM is dormant and IFP has 100% control. |
| **2. MinHook Chaining** | Strict execution of `g_origSample(aNode, aContext, a3, aOut)` before evaluating overrides. | Preserves the trampoline chain so any other hooked plugins execute in sequence without collision. |
| **3. RTTI Function Prefix** | All exported native functions use `IFP_*` (e.g. `IFP_SetArmIk`, `IFP_SetSittingOffset`). | Zero symbol collision with APM's `APM_*` registrations in the game's CRTTISystem. |
| **4. C++ Namespace** | All C++ symbols encapsulated in `namespace IFP::PoseEngine`. | Zero One-Definition-Rule (ODR) or linker symbol collisions. |
| **5. Isolated File Structure** | Plugin packaged at `<game>/red4ext/plugins/ImmersiveFootwearPOV/ImmersiveFootwearPOV.dll`. | Separate directory, configuration, and log files. |

---

## 3. Core Engine Mechanics (Derived from APM)

From our reverse-engineering analysis of APM (`src/Game/AnimGraphHook.cpp` and `src/Pose/TwoBoneIk.hpp`):

### 3.1 Terminal Output Hook (`animAnimNode_Output::Sample`)
* `animAnimNode_Output` is the final node of every animation graph in REDengine.
* In Cyberpunk 2.31+, vtable slot `0x128` holds `void Sample(Node* this, Context* ctx, void* a3, SampleOutput* out)`.
* `SampleOutput->pose` points directly to the local-space bone buffer:
  * `+0x24`: `uint32 boneCount`
  * `+0x30`: `QsTransform* bones` (local-space transforms, stride `0x30`)
* **Entity Resolution:** The animated component being sampled is located via context offsets: `ctx + 0x48 -> +0x118` (`entAnimatedComponent*`).
* Matching against `GetPlayer(GetGame())` verifies that we only modify V's main skeleton (`"root"` component, 71 bones).

### 3.2 Analytic Two-Bone IK Solver
APM uses Daniel Holden's analytic two-joint IK algorithm:
* **Inputs:** Joint positions $\vec{A}$ (upper arm / thigh), $\vec{B}$ (forearm / shin), $\vec{C}$ (hand / foot), target $\vec{T}$, swivel angle $\theta$, and pole vector hint $\vec{P}_{\text{hint}}$.
* **Step 1 (Bend):** Calculates the required bend angle at joint $B$ using the Law of Cosines:
  $$\cos(\beta) = \frac{|\vec{A}\vec{T}|^2 - |\vec{A}\vec{B}|^2 - |\vec{B}\vec{C}|^2}{-2 |\vec{A}\vec{B}| |\vec{B}\vec{C}|}$$
* **Step 2 (Swing):** Computes the quaternion swing rotating $\vec{A}\vec{C} \to \vec{A}\vec{T}$.
* **Step 3 (Swivel):** Rotates the chain around the $\vec{A}\vec{T}$ axis by angle $\theta$ (flaring the elbow or directing the knee).
* **Step 4 (Joint Limits):** Clamps local rotations using anatomical boundary ellipsoids (`JointLimits.cpp`) to prevent backwards knees or broken elbows.

---

## 4. TPP Features & Mathematical Specifications

### 4.1 Feature A: Foot Grounding & Sitting Workspots
When V enters a sitting workspot (chair, bench, barstool, sofa, car seat):
1. **The Issue:** Authored workspot animations assume default flat shoes. Equipped high heels or thick platform soles cause the mesh to sink through the floor or hover unrealistically.
2. **The Solution:**
   * Leg IK Chain: `{"LeftUpLeg", "LeftLeg", "LeftFoot"}` & `{"RightUpLeg", "RightLeg", "RightFoot"}`.
   * Target calculation:
     $$\Delta Z_{\text{foot}} = \text{HeelHeight} + \text{PlatformHeight}$$
     $$\vec{T}_{\text{foot}} = \vec{P}_{\text{original}} + \begin{pmatrix} 0 \\ 0 \\ \Delta Z_{\text{foot}} \end{pmatrix}$$
   * Pitch Compensation: Rotates `LeftFoot` / `RightFoot` local X/Y to plant the sole cleanly along the floor plane.
   * Pelvic Offset: Subtle $Z$-translation applied to `Hips` to adjust cushion compression.

### 4.2 Feature B: Procedural Hand on Hip
During peaceful TPP exploration (idle, catwalk locomotion):
1. **Chain Definition:** `{"LeftArm", "LeftForeArm", "LeftHand"}`.
2. **Target Calculation (Body-Relative):**
   Pinned to `Hips` bone frame so the hand tracks pelvic roll/pitch/yaw automatically:
   $$\vec{T}_{\text{hand}} = \vec{P}_{\text{Hips}} + \mathbf{R}_{\text{Hips}} \cdot \begin{pmatrix} -(0.18 + \text{Clearance}_{\text{torso}} + \text{Clearance}_{\text{legs}}) \\ -0.02 \\ 0.05 \end{pmatrix}$$
3. **Elbow Swivel:** $\theta = -45.0^\circ$ (flares elbow outward away from the ribcage).

### 4.3 Feature C: Metadata-Driven Clothing Clearance
Real-time 3D cloth collision in an animation hook is computationally infeasible. Instead, we use deterministic garment volume metadata:

| Garment Class | Examples | Hip Clearance Offset ($\Delta X$) | Thigh Adduction Offset ($\Delta \theta_{\text{knee}}$) |
| :--- | :--- | :---: | :---: |
| **Skin-Tight / Naked** | Bodysuits, swimwear, shorts | $+0.0\text{ cm}$ | $0^\circ$ |
| **Standard** | T-shirts, slim jeans | $+1.0\text{ cm}$ | $0^\circ$ |
| **Structured / Leather** | Biker jackets, cargo pants | $+2.2\text{ cm}$ | $+2.5^\circ$ |
| **Bulky / Heavy Outerwear** | Trench coats, winter parkas, vests | $+3.8\text{ cm}$ | $+5.0^\circ$ |
| **Tight Skirt / Dress** | Pencil skirts, mini dresses | $+0.5\text{ cm}$ | $-8.0^\circ$ (keeps knees together) |

Clearance is queried via TweakDB item tags on `Clo_OuterChest` and `Clo_Legs` and added to the lateral IK target vector.

---

## 5. Future Research: Sitting Poses & Workspot Inventory

> [!NOTE]
> **Implementation Deferred:** Before writing the C++ and REDscript posture code, a comprehensive study of Cyberpunk's sitting workspots must be conducted to establish target poses and edge cases.

### Key Research Questions to Investigate:
1. **Workspot Variety & Categorization:**
   * **Standard Chairs / Benches:** 90° knee angle, flat feet.
   * **Barstools / High Seats:** Extended legs, feet resting on footrests or dangling.
   * **Couches / Low Lounges:** Deep recline, relaxed torso, legs extended forward.
   * **Vehicle Seats:** Steering wheel proximity, pedal placement, bucket seat bolsters.
2. **Vanilla Workspot Tree Structure:**
   * Trace `workWorkspotTree` and `workWorkspotInstance` in REDscript to determine how the engine signals entry, idle loop, and exit.
   * Identify which sitting animations use IK vs baked keyframes.
3. **Hand Placement Variations:**
   * Open hands on knees/thighs vs hands clasped vs hands on armrests.
   * Does V play conversational gestures while seated that should override our procedural hand IK?
4. **Leg Crossing & Skirt Physics:**
   * How do crossed-leg sitting poses interact with footwear height offsets?
   * Does leg counter-rotation interfere with dangling skirt rigs (e.g. `dangle` components)?

---

## 6. Implementation Phases (Roadmap for When Ready)

```
Phase 1: Plugin Scaffolding (CMake, RED4ext.SDK, MSVC build pipeline)
   │
   ▼
Phase 2: Core Math & Output Hook (TwoBoneIk, JointLimits, animAnimNode_Output hook)
   │
   ▼
Phase 3: Real-Time Blending & Target Registration (V's player puppet tracking, alpha decay)
   │
   ▼
Phase 4: REDscript & TweakDB Integration (IFP_* natives, Clothing Clearance resolver)
   │
   ▼
Phase 5: Feature Drivers (Sitting Foot Grounding, Lap Hands, Hand on Hip)
   │
   ▼
Phase 6: Automated Packaging & Verification (pack_and_deploy.ps1 integration, scc validation)
```

### Proposed Directory Layout:
```
Immersive Footwear POV/
├── source/
│   ├── red4ext/                                             # [C++ RED4ext Plugin]
│   │   ├── CMakeLists.txt                                   # CMake configuration fetching RED4ext.SDK
│   │   └── src/
│   │       ├── Main.cpp                                     # Entry point & plugin descriptor
│   │       ├── Core/                                        # Runtime & memory utilities
│   │       ├── Math/                                        # Quat, Vec3, Transform math
│   │       ├── Pose/                                        # TwoBoneIk, JointLimits, PoseProcessor
│   │       └── Scripting/                                   # RTTI bindings (IFP_* functions)
│   └── resources/
│       ├── red4ext/plugins/ImmersiveFootwearPOV/             # Staged binary (.dll)
│       └── r6/scripts/ImmersiveFootwearPOV/
│           ├── Integrations/
│           │   └── ImmersiveFootwearPOV_PoseEngine.reds     # Native declarations & safety bridge
│           └── Systems/
│               ├── ImmersiveFootwearPOV_ClothingClearance.reds # Garment thickness resolver
│               └── ImmersiveFootwearPOV_PostureController.reds # Workspot & Sitting coordinator
└── tools/
    ├── build_plugin.ps1                                     # Automated compilation script
    └── pack_and_deploy.ps1                                  # Integrated build & deployment pipeline
```

---

## 7. Validation & Acceptance Criteria

1. **Clean Compilation:** `build_plugin.ps1` builds `ImmersiveFootwearPOV.dll` under MSVC 2022 with 0 errors / 0 warnings (`/W4`).
2. **Zero APM Collision:** Coexists with `AdvancedPoseMod` in `red4ext/plugins/` without hook crashes or RTTI duplicate registration errors.
3. **Smooth Blending:** All transitions into and out of procedural postures take at least $0.25\text{s}$ with zero skeletal popping.
4. **Foot Grounding Accuracy:** Seated V wearing high heels maintains sole contact with the floor plane with $< 2\text{ mm}$ error.
5. **Garment Clearance:** Thick coats push hand-on-hip target laterally, completely preventing jacket mesh clipping.
