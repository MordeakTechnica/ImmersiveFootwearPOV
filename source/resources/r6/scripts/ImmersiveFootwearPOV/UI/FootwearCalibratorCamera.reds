module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - Dedicated Calibrator Inspection Camera
// Temporarily takes active viewport ownership using a transient non-persisted
// simple_free_camera entity while the Calibrator UI is locked, eliminating
// third-party TPP mouse-orbit interference and enabling a true side-profile
// inspection angle of V's legs and footwear.
// =============================================================================

public class FootwearCalibratorCamTick extends DelayCallback {
  public let controller: wref<FootwearCalibratorCamera>;
  public let epoch: Int32;

  public func Call() -> Void {
    if IsDefined(this.controller) {
      this.controller.OnTick(this.epoch);
    };
  }
}

public class FootwearCalibratorCamera extends ScriptableSystem {
  private let m_wanted: Bool;
  private let m_active: Bool;
  private let m_epoch: Int32;
  private let m_waitingForTPP: Bool;
  private let m_waitTicks: Int32;

  private let m_focusBoots: Bool;
  private let m_preservePose: Bool;
  private let m_blendTime: Float;

  private let m_camId: EntityID;
  private let m_camEntity: wref<GameObject>;
  private let m_camComponent: wref<CameraComponent>;

  private let m_hasSavedPose: Bool;
  private let m_savedPos: Vector4;
  private let m_savedDir: Vector4;
  private let m_savedFov: Float;

  private let m_hasPreservedPose: Bool;
  private let m_preservedPos: Vector4;
  private let m_preservedDir: Vector4;
  private let m_preservedFov: Float;

  public static func GetInstance(gi: GameInstance) -> ref<FootwearCalibratorCamera> {
    return GameInstance.GetScriptableSystemsContainer(gi).Get(n"ImmersiveFootwearPOV.FootwearCalibratorCamera") as FootwearCalibratorCamera;
  }

  public static func Engage(gi: GameInstance, focusBoots: Bool, preserveCurrentPose: Bool) -> Void {
    let cam: ref<FootwearCalibratorCamera> = FootwearCalibratorCamera.GetInstance(gi);
    if IsDefined(cam) {
      cam.AcquireLock(focusBoots, preserveCurrentPose);
    };
  }

  public static func SetFocusBoots(gi: GameInstance, focusBoots: Bool) -> Void {
    let cam: ref<FootwearCalibratorCamera> = FootwearCalibratorCamera.GetInstance(gi);
    if IsDefined(cam) {
      cam.UpdateFocusBootsMode(focusBoots);
    };
  }

  public static func Disengage(gi: GameInstance, opt closeSession: Bool) -> Void {
    let cam: ref<FootwearCalibratorCamera> = FootwearCalibratorCamera.GetInstance(gi);
    if IsDefined(cam) {
      cam.ReleaseLock(closeSession);
    };
  }

  private func OnDetach() -> Void {
    this.ReleaseLock(true);
  }

  public func AcquireLock(focusBoots: Bool, preserveCurrentPose: Bool) -> Void {
    let gi: GameInstance = this.GetGameInstance();
    if !ITPController.IsITPPresent(gi) {
      // Without ITP, vanilla FPP look is already frozen cleanly by ModalPopup + NoCameraControl.
      return;
    };

    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(gi).GetLocalPlayerMainGameObject() as PlayerPuppet;
    if !IsDefined(player) {
      return;
    };

    this.m_wanted = true;
    this.m_active = false;
    this.m_epoch += 1;
    this.m_focusBoots = focusBoots;
    this.m_preservePose = preserveCurrentPose;
    this.m_blendTime = (focusBoots && !preserveCurrentPose) ? 0.16 : 0.02;
    this.m_waitTicks = 0;

    // When re-locking from Unlock mode (preserveCurrentPose), player is already in TPP;
    // do not wait on distance hysteresis (which fails when RequestFraming zooms within 1.4m).
    let isAlreadyTpp: Bool = preserveCurrentPose || ITPController.IsTPPActive(player, true);
    this.m_waitingForTPP = !isAlreadyTpp;

    if preserveCurrentPose {
      this.m_hasPreservedPose = this.CaptureActiveCameraPose(gi, player, this.m_preservedPos, this.m_preservedDir, this.m_preservedFov);
    } else {
      this.m_hasPreservedPose = false;
      if isAlreadyTpp && !this.m_hasSavedPose {
        this.m_hasSavedPose = this.CaptureActiveCameraPose(gi, player, this.m_savedPos, this.m_savedDir, this.m_savedFov);
      };
    };

    FootwearRedLogger.Log("CAM", s"AcquireLock: focusBoots=\(focusBoots) preserve=\(preserveCurrentPose) alreadyTpp=\(isAlreadyTpp) preservedOk=\(this.m_hasPreservedPose) reuseEntity=\(IsDefined(this.m_camEntity))");

    if !this.m_waitingForTPP {
      this.StepActivateCamera(gi, player);
    };

    if this.m_wanted && !this.m_active {
      this.ScheduleTick(0.033);
    };
  }

  public func UpdateFocusBootsMode(focusBoots: Bool) -> Void {
    this.m_focusBoots = focusBoots;
    this.m_preservePose = false;
    if !this.m_wanted || !this.m_active || !IsDefined(this.m_camEntity) || !IsDefined(this.m_camComponent) {
      return;
    };
    let gi: GameInstance = this.GetGameInstance();
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(gi).GetLocalPlayerMainGameObject() as PlayerPuppet;
    if !IsDefined(player) {
      return;
    };
    this.ApplyDesiredPose(gi, player);
  }

  public func ReleaseLock(opt closeSession: Bool) -> Void {
    let wasActive: Bool = this.m_active || this.m_wanted;
    this.m_wanted = false;
    this.m_active = false;
    this.m_waitingForTPP = false;
    this.m_epoch += 1;
    this.m_hasPreservedPose = false;

    let gi: GameInstance = this.GetGameInstance();
    if IsDefined(this.m_camComponent) {
      this.m_camComponent.Deactivate(0.0, true);
    };

    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(gi).GetLocalPlayerMainGameObject() as PlayerPuppet;
    if IsDefined(player) && wasActive {
      if ITPController.IsITPPresent(gi) {
        let tppCam: ref<CameraComponent> = player.FindComponentByName(n"tppCamera") as CameraComponent;
        if IsDefined(tppCam) {
          tppCam.Activate(0.0, false);
        };
      } else {
        let fppCam: ref<CameraComponent> = player.GetFPPCameraComponent();
        if IsDefined(fppCam) {
          fppCam.Activate(0.0, false);
        };
      };
    };

    if closeSession {
      this.m_hasSavedPose = false;
      if EntityID.IsDefined(this.m_camId) {
        let des: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
        if IsDefined(des) {
          des.DeleteEntity(this.m_camId);
        };
      };
      this.m_camId = new EntityID();
      this.m_camEntity = null;
      this.m_camComponent = null;
    };

    if wasActive {
      FootwearRedLogger.Log("CAM", s"ReleaseLock: closeSession=\(closeSession)");
    };
  }

  public func OnTick(epoch: Int32) -> Void {
    if !this.m_wanted || epoch != this.m_epoch || this.m_active {
      return;
    };

    let gi: GameInstance = this.GetGameInstance();
    if GameInstance.GetSystemRequestsHandler().IsPreGame() || !ITPController.IsITPPresent(gi) {
      this.ReleaseLock(true);
      return;
    };

    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(gi).GetLocalPlayerMainGameObject() as PlayerPuppet;
    if !IsDefined(player) {
      this.ReleaseLock(true);
      return;
    };

    if this.m_waitingForTPP {
      this.m_waitTicks += 1;
      if ITPController.IsTPPActive(player, true) || this.m_waitTicks >= 18 {
        this.m_waitingForTPP = false;
        if !this.m_hasSavedPose {
          this.m_hasSavedPose = this.CaptureActiveCameraPose(gi, player, this.m_savedPos, this.m_savedDir, this.m_savedFov);
        };
      } else {
        this.ScheduleTick(0.033);
        return;
      };
    };

    this.StepActivateCamera(gi, player);

    if this.m_wanted && !this.m_active {
      this.m_waitTicks += 1;
      if this.m_waitTicks < 45 {
        this.ScheduleTick(0.033);
      } else {
        FootwearRedLogger.LogWarn("CAM", "Timed out waiting for calibrator camera entity to resolve.");
        this.ReleaseLock(true);
      };
    };
  }

  private func StepActivateCamera(gi: GameInstance, player: ref<PlayerPuppet>) -> Void {
    let des: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
    if !IsDefined(des) {
      return;
    };

    if !EntityID.IsDefined(this.m_camId) {
      let targetPos: Vector4;
      let targetDir: Vector4;
      let targetFov: Float;
      this.ResolveDesiredPose(gi, player, targetPos, targetDir, targetFov);
      let fullEuler: EulerAngles = this.DirToEuler(targetDir);

      let spec: ref<DynamicEntitySpec> = new DynamicEntitySpec();
      spec.templatePath = r"base\\entities\\cameras\\simple_free_camera.ent";
      spec.position = targetPos;
      spec.orientation = EulerAngles.ToQuat(FootwearCalibratorCamera.MakeEuler(0.0, 0.0, fullEuler.Yaw));
      spec.persistState = false;
      spec.persistSpawn = false;
      spec.alwaysSpawned = true;
      spec.spawnInView = true;
      spec.active = true;
      ArrayPush(spec.tags, n"IFP_CALIBRATOR_CAM");
      this.m_camId = des.CreateEntity(spec);
      return;
    };

    if !IsDefined(this.m_camEntity) {
      this.m_camEntity = des.GetEntity(this.m_camId) as GameObject;
    };
    if !IsDefined(this.m_camEntity) {
      return;
    };

    if !IsDefined(this.m_camComponent) {
      this.m_camComponent = this.m_camEntity.FindComponentByName(n"camera") as CameraComponent;
      if IsDefined(this.m_camComponent) {
        let comps: array<ref<IComponent>> = this.m_camEntity.GetComponents();
        for comp in comps {
          if !IsDefined(comp as CameraComponent) {
            comp.Toggle(false);
          };
        };
      };
    };

    if !IsDefined(this.m_camComponent) {
      return;
    };

    this.ApplyDesiredPose(gi, player);
    this.m_camComponent.Activate(this.m_blendTime, true);
    this.m_active = true;
    FootwearRedLogger.Log("CAM", s"Activated calibrator camera (blend=\(this.m_blendTime), preserve=\(this.m_preservePose), focus=\(this.m_focusBoots))");
  }

  private func ApplyDesiredPose(gi: GameInstance, player: ref<PlayerPuppet>) -> Void {
    if !IsDefined(this.m_camEntity) || !IsDefined(this.m_camComponent) {
      return;
    };
    let targetPos: Vector4;
    let targetDir: Vector4;
    let targetFov: Float;
    this.ResolveDesiredPose(gi, player, targetPos, targetDir, targetFov);

    let fullEuler: EulerAngles = this.DirToEuler(targetDir);
    let teleporter: ref<TeleportationFacility> = GameInstance.GetTeleportationFacility(gi);
    if IsDefined(teleporter) {
      teleporter.Teleport(this.m_camEntity, targetPos, FootwearCalibratorCamera.MakeEuler(0.0, 0.0, fullEuler.Yaw));
    };
    this.m_camComponent.SetLocalOrientation(EulerAngles.ToQuat(FootwearCalibratorCamera.MakeEuler(fullEuler.Pitch, fullEuler.Roll, 0.0)));
    this.m_camComponent.SetFOV(targetFov);
  }

  private func ResolveDesiredPose(gi: GameInstance, player: ref<PlayerPuppet>, out pos: Vector4, out dir: Vector4, out fov: Float) -> Void {
    if this.m_preservePose && this.m_hasPreservedPose {
      pos = this.m_preservedPos;
      dir = this.m_preservedDir;
      fov = this.m_preservedFov;
      return;
    };
    if this.m_focusBoots {
      this.ComputeSideBootPose(gi, player, pos, dir);
      fov = 45.0;
      return;
    };
    if this.m_hasSavedPose {
      pos = this.m_savedPos;
      dir = this.m_savedDir;
      fov = this.m_savedFov;
      return;
    };
    // Fallback if TPP camera wasn't captured beforehand
    if !this.CaptureActiveCameraPose(gi, player, pos, dir, fov) {
      this.ComputeSideBootPose(gi, player, pos, dir);
      fov = 45.0;
    };
  }

  private func CaptureActiveCameraPose(gi: GameInstance, player: ref<PlayerPuppet>, out pos: Vector4, out dir: Vector4, out fov: Float) -> Bool {
    let camSys: ref<CameraSystem> = GameInstance.GetCameraSystem(gi);
    if !IsDefined(camSys) {
      return false;
    };
    let camXf: Transform;
    if !camSys.GetActiveCameraWorldTransform(camXf) {
      return false;
    };
    pos = Transform.GetPosition(camXf);
    dir = camSys.GetActiveCameraForward();
    if Vector4.Length(dir) < 0.01 {
      let fwd: Vector4 = player.GetWorldForward();
      dir = Vector4.Normalize(new Vector4(fwd.X, fwd.Y, -0.1, 0.0));
    } else {
      dir = Vector4.Normalize(dir);
    };
    fov = this.m_focusBoots ? 50.0 : 60.0;
    return true;
  }

  private func ComputeSideBootPose(gi: GameInstance, player: ref<PlayerPuppet>, out camPos: Vector4, out lookDir: Vector4) -> Void {
    let basePos: Vector4 = player.GetWorldPosition();
    let fwd: Vector4 = player.GetWorldForward();
    let right: Vector4 = player.GetWorldRight();
    let up: Vector4 = new Vector4(0.0, 0.0, 1.0, 0.0);

    let flatFwd: Vector4 = Vector4.Normalize(new Vector4(fwd.X, fwd.Y, 0.0, 0.0));
    let flatRight: Vector4 = Vector4.Normalize(new Vector4(right.X, right.Y, 0.0, 0.0));
    if Vector4.Length(flatFwd) < 0.01 {
      flatFwd = new Vector4(0.0, 1.0, 0.0, 0.0);
    };
    if Vector4.Length(flatRight) < 0.01 {
      flatRight = new Vector4(1.0, 0.0, 0.0, 0.0);
    };

    // Slight front-side 3/4 profile (~22 deg ahead of pure side) so heel arch, platform,
    // floor contact, and both shoes remain visible without one boot fully occluding the other.
    let rightSideDir: Vector4 = Vector4.Normalize((flatRight * 0.927) + (flatFwd * 0.375));
    let leftSideDir: Vector4 = Vector4.Normalize((flatRight * -0.927) + (flatFwd * 0.375));

    let desiredDist: Float = 1.25;
    let ankleOrigin: Vector4 = new Vector4(basePos.X, basePos.Y, basePos.Z + 0.32, 1.0);

    let rightDist: Float = this.CheckClearDistance(gi, ankleOrigin, rightSideDir, desiredDist);
    let chosenDir: Vector4 = rightSideDir;
    let chosenDist: Float = rightDist;

    if rightDist < 0.85 {
      let leftDist: Float = this.CheckClearDistance(gi, ankleOrigin, leftSideDir, desiredDist);
      if leftDist > rightDist + 0.15 {
        chosenDir = leftSideDir;
        chosenDist = leftDist;
      };
    };

    chosenDist = ClampF(chosenDist, 0.55, desiredDist);
    camPos = new Vector4(
      basePos.X + chosenDir.X * chosenDist,
      basePos.Y + chosenDir.Y * chosenDist,
      basePos.Z + 0.30,
      1.0
    );

    let rawToFeet: Vector4 = new Vector4(
      basePos.X - camPos.X,
      basePos.Y - camPos.Y,
      (basePos.Z + 0.24) - camPos.Z,
      0.0
    );
    let baseDir: Vector4 = Vector4.Normalize(rawToFeet);

    // Aim slightly left of V so V sits centered in the open viewport right of the left calibrator panel.
    let camLeft: Vector4 = Vector4.Normalize(Vector4.Cross(up, baseDir));
    let shiftLeft: Float = 0.24 * (chosenDist / desiredDist);
    let focusPos: Vector4 = new Vector4(
      basePos.X + camLeft.X * shiftLeft,
      basePos.Y + camLeft.Y * shiftLeft,
      basePos.Z + 0.24,
      1.0
    );

    lookDir = Vector4.Normalize(focusPos - camPos);
  }

  private func CheckClearDistance(gi: GameInstance, origin: Vector4, dir: Vector4, maxDist: Float) -> Float {
    let sqs: ref<SpatialQueriesSystem> = GameInstance.GetSpatialQueriesSystem(gi);
    if !IsDefined(sqs) {
      return maxDist;
    };
    let probeEnd: Vector4 = new Vector4(
      origin.X + dir.X * (maxDist + 0.20),
      origin.Y + dir.Y * (maxDist + 0.20),
      origin.Z,
      1.0
    );
    let traceResult: TraceResult;
    let hasHit: Bool = sqs.SyncRaycastByCollisionGroup(origin, probeEnd, n"Static", traceResult, true, false);
    if !hasHit {
      hasHit = sqs.SyncRaycastByCollisionGroup(origin, probeEnd, n"PlayerBlocker", traceResult, true, false);
    };
    if hasHit && TraceResult.IsValid(traceResult) {
      let hitPos: Vector4 = Cast<Vector4>(traceResult.position);
      let hitDist: Float = Vector4.Length(hitPos - origin);
      return MaxF(hitDist - 0.22, 0.45);
    };
    return maxDist;
  }

  private func DirToEuler(dir: Vector4) -> EulerAngles {
    let q: Quaternion = Quaternion.BuildFromDirectionVector(Vector4.Normalize(dir), new Vector4(0.0, 0.0, 1.0, 0.0));
    return Quaternion.ToEulerAngles(q);
  }

  private static func MakeEuler(pitch: Float, roll: Float, yaw: Float) -> EulerAngles {
    let e: EulerAngles;
    e.Pitch = pitch;
    e.Roll = roll;
    e.Yaw = yaw;
    return e;
  }

  private func ScheduleTick(delaySec: Float) -> Void {
    let cb: ref<FootwearCalibratorCamTick> = new FootwearCalibratorCamTick();
    cb.controller = this;
    cb.epoch = this.m_epoch;
    GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(cb, delaySec, false);
  }
}
